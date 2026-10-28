(in-package #:cl-cc/javascript/statements)

;;; ─── Switch Statement ────────────────────────────────────────────────────────
(defun %js-parse-switch-body (stream break-tag)
  "Parse switch case/default sections.
  Returns (values cases default-body rest) where cases is a list of
  (case-expr . body-stmts) conses and default-body is a list of stmts or NIL."
  (let ((current (%js-consume-expected :T-LBRACE stream))
        (cases nil)
        (default-body nil))
    (loop
      (setf current (js-skip-semis current))
      (when (or (js-at-eof-p current)
                (eq (js-peek-type current) :T-RBRACE))
        (return))
      (cond
        ;; case expr:
        ((eq (js-peek-type current) :T-CASE)
         (setf current (cdr current))
         (multiple-value-bind (case-expr rest) (js-call-parser-handler :expression current)
           (setf current (%js-consume-expected :T-COLON rest))
           (let ((body nil))
             (loop
               (setf current (js-skip-semis current))
               (when (or (js-at-eof-p current)
                         (eq (js-peek-type current) :T-RBRACE)
                         (eq (js-peek-type current) :T-CASE)
                         (eq (js-peek-type current) :T-DEFAULT))
                 (return))
               (let ((*js-loop-break-target* break-tag))
                 (multiple-value-bind (stmt rest2) (js-parse-stmt current)
                   (when stmt (push stmt body))
                   (setf current rest2))))
             (push (cons case-expr (nreverse body)) cases))))
        ;; default:
        ((eq (js-peek-type current) :T-DEFAULT)
         (setf current (cdr current))
         (setf current (%js-consume-expected :T-COLON current))
         (let ((body nil))
           (loop
             (setf current (js-skip-semis current))
             (when (or (js-at-eof-p current)
                       (eq (js-peek-type current) :T-RBRACE)
                       (eq (js-peek-type current) :T-CASE))
               (return))
             (let ((*js-loop-break-target* break-tag))
               (multiple-value-bind (stmt rest2) (js-parse-stmt current)
                 (when stmt (push stmt body))
                 (setf current rest2))))
           (setf default-body (nreverse body))))
        (t
         ;; Skip unexpected token
         (setf current (cdr current)))))
    (values (nreverse cases) default-body
            (%js-consume-expected :T-RBRACE current))))

(defun %js-lower-switch (switch-expr cases default-body break-tag)
  "Lower switch(expr){case x:...; default:...} to a let/tagbody dispatch form."
  (let* ((value-sym (gensym "SWITCH-VAL-"))
         (default-tag
          (when default-body
            (gensym "SWITCH-DEFAULT-")))
         (case-labels
          (loop repeat (length cases)
                collect (gensym "SWITCH-CASE-")))
         (dispatch-forms
          (append
           (loop for case in cases
                 for label in case-labels
                 collect (make-ast-if :cond
                                      (make-ast-call :func
                                                     (make-ast-var :name '%js-strict-eq)
                                                     :args
                                                     (list (make-ast-var :name value-sym)
                                                           (car case)))
                                      :then
                                      (make-ast-go :tag label)
                                      :else
                                      (make-ast-quote :value nil)))
           (list (make-ast-go :tag (or default-tag break-tag)))))
         (case-forms
          (loop for case in cases
                for label in case-labels
                append (cons label (cdr case))))
         (default-forms
          (when default-body
            (cons default-tag default-body))))
    (make-ast-let :bindings
                  (list (cons value-sym switch-expr))
                  :body
                  (list
                   (make-ast-block :name
                                   nil
                                   :body
                                   (list
                                    (%js-make-tagbody
                                     (append dispatch-forms
                                             case-forms
                                             default-forms
                                             (list break-tag)))))))))

(defun js-parse-switch-stmt (stream)
  "Parse switch(expr){case x:...; default:...}.
  Lowers to ast-let + ast-if chain via %js-lower-switch.
  Returns (values ast rest)."
  (let ((rest (%js-consume-expected :T-LPAREN stream)))
    (multiple-value-bind (switch-expr rest2) (js-call-parser-handler :expression rest)
      (setf rest2 (%js-consume-expected :T-RPAREN rest2))
      (let* ((break-tag (gensym "SWITCH-END-"))
             (*js-gdi-lexical-scope-depth* (1+ *js-gdi-lexical-scope-depth*))
             (*js-loop-break-target* break-tag)
             (*js-break-targets* (cons break-tag *js-break-targets*)))
        (multiple-value-bind (cases default-body rest3)
            (if cl-cc/javascript/syntax:*js-gdi-global-reference-mode*
                (multiple-value-bind (raw-cases raw-default-body raw-rest)
                    (let ((cl-cc/javascript/syntax:*js-gdi-global-reference-mode* nil)
                          (cl-cc/javascript/syntax:*js-gdi-global-lexical-names* nil)
                          (cl-cc/javascript/syntax:*js-gdi-global-var-names* nil))
                      (%js-parse-switch-body rest2 break-tag))
                  (declare (ignore raw-rest))
                  (let* ((switch-lexical-names
                          (remove-duplicates
                           (append
                            (%js-gdi-block-lexical-names
                             (loop for case in raw-cases
                                   append (cdr case)))
                            (%js-gdi-block-lexical-names raw-default-body))
                           :test
                           (function eq)))
                         (cl-cc/javascript/syntax:*js-gdi-shadowed-names*
                          (append switch-lexical-names
                                  cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
                    (%js-parse-switch-body rest2 break-tag)))
                (%js-parse-switch-body rest2 break-tag))
          (values (%js-lower-switch switch-expr cases default-body break-tag) rest3))))))
