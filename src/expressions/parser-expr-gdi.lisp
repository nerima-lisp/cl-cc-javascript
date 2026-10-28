(in-package #:cl-cc/javascript/expressions)

(defun %js-gdi-global-name-p (name)
  (and
   (or cl-cc/javascript/syntax:*js-gdi-global-reference-mode*
       (member name cl-cc/javascript/syntax:*js-gdi-global-lexical-names* :test (function eq))
       (member name cl-cc/javascript/syntax:*js-gdi-global-var-names* :test (function eq)))
   (not (member name cl-cc/javascript/syntax:*js-gdi-shadowed-names* :test (function eq)))))

(defun %js-gdi-reference-ast (name)
  (if (%js-gdi-global-name-p name)
      (js-call-parser-handler :gdi-global-read-ast name)
      (make-ast-var :name name)))

(defun %js-gdi-reference-name (ast)
  (when
      (and (ast-call-p ast)
           (ast-var-p (ast-call-func ast))
           (string= "%JS-GDI-GLOBAL-READ" (symbol-name (ast-var-name (ast-call-func ast)))))
    (let ((argument (first (ast-call-args ast))))
      (when (cl-cc/ast:ast-quote-p argument)
        (cl-cc/ast:ast-quote-value argument)))))

(defun %js-gdi-global-write-ast (name value)
  (js-call-parser-handler :gdi-global-write-ast name value))

(defun %js-gdi-lower-global-logical-assign (op name read-ast rhs)
  (let* ((kind (%js-logical-assign-short-circuit-p op))
         (temporary (gensym "JS-GDI-LOGICAL-"))
         (current (make-ast-var :name temporary))
         (test
          (if (eq kind :non-null)
              (%js-call (quote %js-not-nullish) current)
              (%js-call (quote %js-truthy) current)))
         (assign (%js-gdi-global-write-ast name rhs))
         (result
          (ecase kind
            (:truthy (make-ast-if :cond test :then assign :else current))
            (:falsy (make-ast-if :cond test :then current :else assign))
            (:non-null (make-ast-if :cond test :then current :else assign)))))
    (make-ast-let :bindings (list (cons temporary read-ast)) :body (list result))))

(defun %js-gdi-function-var-names (forms)
  (let ((names nil))
    (labels ((visit (node)
               (cond
                 ((or (cl-cc/ast:ast-defun-p node)
                      (cl-cc/ast:ast-defclass-p node)
                      (cl-cc/ast:ast-lambda-p node)) nil)
                 ((and (cl-cc/ast:ast-call-p node)
                       (cl-cc/ast:ast-var-p (cl-cc/ast:ast-call-func node))
                       (string= "%JS-TRY-CATCH-FINALLY"
                                (symbol-name
                                 (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func node)))))
                  (dolist (arg (cl-cc/ast:ast-call-args node))
                    (if (cl-cc/ast:ast-lambda-p arg)
                        (dolist (form (cl-cc/ast:ast-lambda-body arg))
                          (visit form))
                        (visit arg))))
                 (t
                   (when
                       (and (cl-cc/ast:ast-let-p node)
                            (member :var (cl-cc/ast:ast-let-declarations node)))
                     (dolist (binding (cl-cc/ast:ast-let-bindings node))
                       (let ((name (car binding)))
                         (when
                             (and (symbolp name)
                                  (eq (symbol-package name) (find-package :cl-cc/javascript)))
                           (push name names)))))
                   (dolist (child (cl-cc/ast:ast-children node))
                     (visit child))))))
      (dolist (form forms)
        (visit form)))
    (nreverse names)))

(defun %js-gdi-function-lexical-names (forms)
  (let ((names nil))
    (labels ((visit-direct (items)
               (dolist (node items)
                 (cond
                   ((cl-cc/ast:ast-defun-p node) (push (cl-cc/ast:ast-defun-name node) names))
                   ((cl-cc/ast:ast-defclass-p node) (push (cl-cc/ast:ast-defclass-name node) names))
                   ((cl-cc/ast:ast-let-p node)
                     (when
                         (intersection (cl-cc/ast:ast-let-declarations node)
                                       '(:let :const)
                                       :test
                                       #'eq)
                       (dolist (binding (cl-cc/ast:ast-let-bindings node))
                         (let ((name (car binding)))
                           (when
                               (and (symbolp name)
                                    (eq (symbol-package name) (find-package :cl-cc/javascript)))
                             (push name names)))))
                     (when
                         (intersection (cl-cc/ast:ast-let-declarations node)
                                       '(:var :let :const)
                                       :test
                                       #'eq)
                       (visit-direct (cl-cc/ast:ast-let-body node))))))))
      (visit-direct forms)
      (nreverse names))))

(defun js-parse-function-body (stream)
  "Parse statements inside a function body after its opening brace."
  (if cl-cc/javascript/syntax:*js-gdi-global-reference-mode*
      (multiple-value-bind (raw-forms raw-rest)
          (let ((cl-cc/javascript/syntax:*js-gdi-global-reference-mode* nil))
            (js-call-parser-handler :function-body-statement-list stream))
        (declare (ignore raw-rest))
        (let* ((local-names
                (append (%js-gdi-function-var-names raw-forms)
                        (%js-gdi-function-lexical-names raw-forms)))
               (cl-cc/javascript/syntax:*js-gdi-shadowed-names*
                (append local-names cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
          (js-call-parser-handler :function-body-statement-list stream)))
      (js-call-parser-handler :function-body-statement-list stream)))
(defun js-parse-function-expr (stream &key async-p generator-p name)
  "Parse a JavaScript function expression."
  (let ((current stream)
        (is-generator generator-p)
        (named-expression-p nil))
    (when (js-at-op-p current "*")
      (%js-consume-then (rest (js-consume current))
                        (setf is-generator t
                              current rest)))
    (when (and (null name) (eq (js-peek-type current) :T-IDENT))
      (multiple-value-bind (name-token rest) (js-consume current)
        (setf name (js-ident-sym (js-tok-value name-token))
              named-expression-p t
              current rest)))
    (let* ((name-shadow
            (when named-expression-p
              (list name)))
           (first-pass
            (multiple-value-list
             (let ((cl-cc/javascript/syntax:*js-gdi-shadowed-names*
                    (append name-shadow cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
               (js-call-parser-handler :function-params current))))
           (all-params (first first-pass)))
      (multiple-value-bind (params optionals rest-sym rest2)
          (let ((cl-cc/javascript/syntax:*js-gdi-shadowed-names*
                 (append all-params name-shadow cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
            (js-call-parser-handler :function-params current))
        (%js-consume-then (rest3 (js-expect :T-LBRACE rest2))
                          (let ((cl-cc/javascript/syntax:*js-gdi-shadowed-names*
                                 (append params
                                         (when name
                                           (list name))
                                         cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
                            (multiple-value-bind (body-forms rest4) (js-parse-function-body rest3)
                              (values
                               (%js-build-function-expr-ast params
                                                            optionals
                                                            rest-sym
                                                            body-forms
                                                            async-p
                                                            is-generator
                                                            name)
                               rest4))))))))

(eval-when (:load-toplevel :execute)
  (register-js-parser-handler :function-body (function js-parse-function-body))
  (register-js-parser-handler :gdi-reference-name (function %js-gdi-reference-name)))
