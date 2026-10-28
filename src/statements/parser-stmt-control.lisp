;;;; packages/javascript/src/parser-stmt-control.lisp — JS Control-Flow Statement Parser
;;;;
;;;; Contains: for-statement (C-style, for-in, for-of), switch/case/default.
;;;;
;;;; Load order: after parser-stmt.lisp (loop/if/for lowering helpers,
;;;; *js-stmt-parsers* variable, and early statement registrations).
(in-package #:cl-cc/javascript/statements)

;;; ─── For Statement ───────────────────────────────────────────────────────────
;;;
;;; Handles: for(init;cond;update)body, for(var x in obj)body,
;;;          for(var x of iter)body, for await(var x of asyncIter)body.
(defun %js-lower-for-c-style (current init-ast)
  "Lower a C-style for(init;cond;update){body} loop from CURRENT (at ;).
INIT-AST is the already-parsed init form (or NIL for no-init).
Returns (values ast rest)."
  (let* ((rest2 (%js-consume-expected :T-SEMI current))
         (cond-expr
          (if (eq (js-peek-type rest2) :T-SEMI)
              (make-ast-quote :value t)
              (multiple-value-bind (e r) (js-call-parser-handler :expression rest2)
                (setf rest2 r)
                e)))
         (rest3 (%js-consume-expected :T-SEMI rest2))
         (update-expr
          (if (eq (js-peek-type rest3) :T-RPAREN)
              (make-ast-quote :value nil)
              (multiple-value-bind (e r) (js-call-parser-handler :expression rest3)
                (setf rest3 r)
                e)))
         (rest4 (%js-consume-expected :T-RPAREN rest3)))
    (with-js-loop-tags (loop-tag end-tag "FOR")
                       (multiple-value-bind (body-ast rest5) (%js-parse-stmt-body rest4)
                         (let* ((body-stmts
                                 (if (ast-progn-p body-ast)
                                     (ast-progn-forms body-ast)
                                     (list body-ast)))
                                (loop-ast
                                 (%js-lower-while-with-tags (%js-truthy-call cond-expr)
                                                            (append body-stmts (list update-expr))
                                                            loop-tag
                                                            end-tag)))
                           (values
                            (if init-ast
                                (make-ast-progn :forms (list init-ast loop-ast))
                                loop-ast)
                            rest5))))))

(defun %js-lower-for-of-in (binding iter-expr
                                    body-fn-name
                                    loop-tag
                                    end-tag
                                    &optional
                                    await-p
                                    global-var-p)
  "Lower a for-in/of loop body, writing top-level var bindings globally."
  (declare (ignore body-fn-name))
  (let ((var-sym (%js-binding-to-sym binding))
        (iter-sym (gensym "FOR-ITER-")))
    (lambda (body-ast)
      (let* ((body-stmts
              (if (ast-progn-p body-ast)
                  (ast-progn-forms body-ast)
                  (list body-ast)))
             (raw-elem-access
              (make-ast-call :func
                             (make-ast-var :name (quote car))
                             :args
                             (list (make-ast-var :name iter-sym))))
             (elem-access
              (if await-p
                  (make-ast-call :func (make-ast-var :name '%js-await) :args (list raw-elem-access))
                  raw-elem-access))
             (loop-bindings
              (if (listp binding)
                  (multiple-value-bind (dest-bindings extras)
                      (%js-emit-destructure-bindings binding (make-ast-var :name var-sym))
                    (declare (ignore extras))
                    (cons (cons var-sym elem-access) (rest dest-bindings)))
                  (list (cons var-sym elem-access)))))
        (let* ((iter-advance
                (make-ast-setq :var
                               iter-sym
                               :value
                               (make-ast-call :func
                                              (make-ast-var :name (quote cdr))
                                              :args
                                              (list (make-ast-var :name iter-sym)))))
               (combined-body (append body-stmts (list iter-advance)))
               (inner-form
                (if global-var-p
                    (let ((forms combined-body))
                      (dolist (binding-pair (reverse loop-bindings))
                        (let ((name (car binding-pair))
                              (value (cdr binding-pair)))
                          (when
                              (and (symbolp name)
                                   (eq (symbol-package name) (find-package :cl-cc/javascript)))
                            (setf forms (cons
                                         (js-call-parser-handler :gdi-global-write-ast name value)
                                         forms)))
                          (setf forms (list
                                       (make-ast-let :bindings (list binding-pair) :body forms)))))
                      (make-ast-progn :forms forms))
                    (if (listp binding)
                        (let ((forms combined-body))
                          (dolist (binding-pair (reverse loop-bindings))
                            (setf forms (list
                                         (make-ast-let :bindings (list binding-pair) :body forms))))
                          (first forms))
                        (make-ast-let :bindings loop-bindings :body combined-body)))))
          (make-ast-let :bindings
                        (list (cons iter-sym iter-expr))
                        :body
                        (list
                         (%js-lower-while-with-tags (%js-truthy-call (make-ast-var :name iter-sym))
                                                    (list inner-form)
                                                    loop-tag
                                                    end-tag))))))))

(defun %js-parse-for-in-of-stmt (binding kind rest2 tag-prefix wrap-fn-name &optional await-p)
  "Parse and lower a declared for-in/of loop."
  (multiple-value-bind (expr rest3) (js-call-parser-handler :expression (cdr rest2))
    (setf rest3 (%js-consume-expected :T-RPAREN rest3))
    (let ((shadow-names
           (when (member kind (list :let :const) :test (function eq))
             (multiple-value-bind (bindings extras)
                 (%js-emit-destructure-bindings binding (make-ast-quote :value :js-undefined))
               (declare (ignore extras))
               (loop for binding-pair in bindings
                     for name = (car binding-pair)
                     when (and (symbolp name)
                               (eq (symbol-package name) (find-package :cl-cc/javascript)))
                       collect name)))))
      (with-js-loop-tags (loop-tag end-tag tag-prefix)
                         (let ((cl-cc/javascript/syntax:*js-gdi-shadowed-names*
                                (append
                                 (when *js-gdi-mode*
                                   shadow-names)
                                 cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
                           (multiple-value-bind (body-ast rest4) (%js-parse-stmt-body rest3)
                             (let* ((gdi-var-p
                                     (and *js-gdi-mode*
                                          (zerop *js-gdi-function-depth*)
                                          (eq kind :var)))
                                    (global-var-p (and gdi-var-p *js-gdi-lower-var-declarations*))
                                    (lower
                                     (funcall
                                      (%js-lower-for-of-in binding
                                                           (make-ast-call :func
                                                                          (make-ast-var :name
                                                                                        wrap-fn-name)
                                                                          :args
                                                                          (list expr))
                                                           nil
                                                           loop-tag
                                                           end-tag
                                                           await-p
                                                           global-var-p)
                                      body-ast)))
                               (if gdi-var-p
                                   (multiple-value-bind (declared-bindings extras)
                                       (%js-emit-destructure-bindings binding
                                                                      (make-ast-quote :value
                                                                                      :js-undefined))
                                     (declare (ignore extras))
                                     (setf (ast-let-declarations lower) nil)
                                     (values
                                      (make-ast-progn :forms
                                                      (cons
                                                       (make-ast-let :bindings
                                                                     (remove-if-not
                                                                      (lambda (declaration-binding)
                                                                        (let ((name
                                                                               (car
                                                                                declaration-binding)))
                                                                          (and (symbolp name)
                                                                               (eq
                                                                                (symbol-package
                                                                                 name)
                                                                                (find-package
                                                                                 :cl-cc/javascript)))))
                                                                      declared-bindings)
                                                                     :declarations
                                                                     (list :var)
                                                                     :body
                                                                     nil)
                                                       (list lower)))
                                      rest4))
                                   (progn
                                     (setf (ast-let-declarations lower) (list kind))
                                     (values lower rest4))))))))))

(defun %js-parse-for-in-stmt (binding kind rest2)
  "Parse and lower 'for (KIND BINDING in obj) body'. REST2 points at 'in'.
Returns (values ast rest)."
  (%js-parse-for-in-of-stmt binding kind rest2 "FOR-IN" '%js-iter-keys))

(defun %js-parse-for-of-stmt (binding kind rest2 &optional await-p)
  "Parse and lower 'for (KIND BINDING of iter) body' / for-await-of (AWAIT-P
unwraps each element through %js-await — see %js-lower-for-of-in). REST2
points at 'of'. Returns (values ast rest)."
  (%js-parse-for-in-of-stmt binding kind rest2 "FOR-OF" '%js-iter-values await-p))

(defun %js-parse-for-c-style-declared-stmt (binding kind rest2)
  "Parse and lower a declared C-style for loop."
  (let* ((shadow-names
          (when (member kind (list :let :const) :test (function eq))
            (multiple-value-bind (bindings extras)
                (%js-emit-destructure-bindings binding (make-ast-quote :value :js-undefined))
              (declare (ignore extras))
              (loop for binding-pair in bindings
                    for name = (car binding-pair)
                    when (and (symbolp name)
                              (eq (symbol-package name) (find-package :cl-cc/javascript)))
                      collect name))))
         (cl-cc/javascript/syntax:*js-gdi-shadowed-names*
          (append
           (when *js-gdi-mode*
             shadow-names)
           cl-cc/javascript/syntax:*js-gdi-shadowed-names*))
         (var-sym (%js-binding-to-sym binding))
         (init-val (make-ast-quote :value nil))
         (has-init nil)
         (rest-at-semi rest2))
    (when (and (eq (js-peek-type rest2) :T-OP) (equal (js-peek-value rest2) "="))
      (multiple-value-bind (expr rest) (js-call-parser-handler :expression (cdr rest2))
        (setf init-val expr
              has-init t
              rest-at-semi rest)))
    (if (and *js-gdi-mode*
             *js-gdi-lower-var-declarations*
             (zerop *js-gdi-function-depth*)
             (eq kind :var))
        (multiple-value-bind (loop-ast rest) (%js-lower-for-c-style rest-at-semi nil)
          (values
           (if has-init
               (make-ast-progn :forms
                               (list (js-call-parser-handler :gdi-global-write-ast var-sym init-val)
                                     loop-ast))
               loop-ast)
           rest))
        (multiple-value-bind (bindings extras) (%js-emit-destructure-bindings binding init-val)
          (declare (ignore extras))
          (let ((init-bindings
                 (make-ast-let :bindings bindings :declarations (list kind) :body nil)))
            (multiple-value-bind (loop-ast rest) (%js-lower-for-c-style rest-at-semi nil)
              (setf (ast-let-body init-bindings) (list loop-ast))
              (values init-bindings rest)))))))

(defun js-parse-for-stmt (stream)
  "Handle for(init;cond;update){}, for(var x in obj){},
for(var x of iter){}, for await(var x of asyncIter){}.
Returns (values ast rest)."
  (let ((await-p nil)
        (current stream))
    (when (eq (js-peek-type current) :T-AWAIT)
      (setf await-p t
            current (cdr current)))
    (setf current (%js-consume-expected :T-LPAREN current))
    (let ((init-type (js-peek-type current)))
      (cond
        ;; for (var/let/const binding in/of/; ...)
        ((member init-type '(:T-VAR :T-LET :T-CONST) :test #'eq)
         (let* ((kind (case init-type (:T-VAR :var) (:T-LET :let) (:T-CONST :const)))
                (rest (cdr current)))
           (multiple-value-bind (binding rest2) (%js-parse-binding-pattern rest)
             (case (js-peek-type rest2)
               (:T-IN (%js-parse-for-in-stmt binding kind rest2))
               (:T-OF (%js-parse-for-of-stmt binding kind rest2 await-p))
               (t     (%js-parse-for-c-style-declared-stmt binding kind rest2))))))
        ;; for (; cond ; update) { } — empty init
        ((eq init-type :T-SEMI)
         (%js-lower-for-c-style current nil))
        ;; for (expr ; cond ; update) { } — expression init
        (t
         (multiple-value-bind (init-expr rest2) (js-call-parser-handler :expression current)
           (%js-lower-for-c-style rest2 init-expr)))))))

;;; Flow-control statements (break/continue/return/throw/try/debugger/using) live in
;;; parser-stmt-flow.lisp.
