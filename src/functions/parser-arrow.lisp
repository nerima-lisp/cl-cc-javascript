;;;; packages/javascript/src/parser-arrow.lisp — Arrow/Async/Paren/Class/Import Expression Parsers
;;;;
;;;; Helpers for complex primary expressions that require expression recursion:
;;;;   - Parenthesized expression / arrow function  (%js-parse-paren-or-arrow)
;;;;   - Arrow-function finishing                   (%js-finish-arrow-function)
;;;;   - Async expression / async arrow             (%js-parse-async-expr, %js-finish-async-arrow)
;;;;   - Class expression                           (%js-parse-class-expr)
;;;;   - Dynamic import()                           (%js-parse-import-expr)
;;;;
;;;; These are called by js-parse-primary (defined in parser-expr-primary.lisp).
;;;; Load order: after parser-expr-args.lisp and parser-expr-primary.lisp
;;;; (CL resolves calls at runtime, so the forward-reference from
;;;; js-parse-primary to these helpers is fine).
(in-package #:cl-cc/javascript/functions)

(defun %js-parse-arrow-or-paren-item (current)
  "Parse one expression item and classify it as an arrow parameter when possible."
  (let ((start current))
    (multiple-value-bind (expr rest2) (js-call-parser-handler :assignment-expression current)
      (setf current rest2)
      (let* ((assignment-p
              (and (cl-cc/ast:ast-setq-p expr)
                   (eq (js-peek-type start) :T-IDENT)
                   (js-at-op-p (cdr start) "=")))
             (param-sym
              (or (and (ast-var-p expr) (ast-var-name expr))
                  (js-call-parser-handler :gdi-reference-name expr)
                  (and assignment-p (cl-cc/ast:ast-setq-var expr)))))
        (cond
          ((and param-sym assignment-p)
           (values current expr param-sym (cons param-sym (cl-cc/ast:ast-setq-value expr)) nil t))
          ((and param-sym (js-at-op-p current "="))
           (multiple-value-bind (eq-tok rest3) (js-consume current)
             (declare (ignore eq-tok))
             (let ((cl-cc/javascript/syntax:*js-gdi-shadowed-names*
                    (cons param-sym cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
               (multiple-value-bind (default-expr rest4)
                   (js-call-parser-handler :assignment-expression rest3)
                 (values rest4
                         (make-ast-setq :var param-sym :value default-expr)
                         param-sym
                         (cons param-sym default-expr)
                         nil
                         t)))))
          (param-sym (values current expr param-sym nil nil t))
          (t
           (let ((pat (%js-expr-to-binding-pattern expr)))
             (if (and pat (listp pat))
                 (let ((g (second pat)))
                   (values current expr g nil (cons g pat) t))
                 (values current expr nil nil nil nil)))))))))

(defun %js-parse-paren-or-arrow (stream)
  "Parse ( ... ) as either a parenthesized expression or arrow parameters.
Returns (values ast rest)."
  (multiple-value-bind (tok rest) (js-consume stream)
    (declare (ignore tok))
    (if (eq (js-peek-type rest) :T-RPAREN)
        (multiple-value-bind (tok2 rest2) (js-consume rest)
          (declare (ignore tok2))
          (if (eq (js-peek-type rest2) :T-ARROW)
              (%js-finish-arrow-function nil rest2)
              (values (make-ast-quote :value :js-undefined) rest2)))
        (let ((exprs nil)
              (params nil)
              (optionals nil)
              (param-patterns nil)
              (is-arrow-candidate t)
              (current rest)
              (rest-sym nil))
          (loop do (if (eq (js-peek-type current) :T-ELLIPSIS)
                       (progn
                         (multiple-value-bind (tok2 rest2) (js-consume current)
                           (declare (ignore tok2))
                           (multiple-value-bind (name-tok rest3) (js-expect :T-IDENT rest2)
                             (setf rest-sym (js-ident-sym (js-tok-value name-tok))
                                   current rest3)))
                         (return))
                       (let ((reparse-fallback-p
                              (and params cl-cc/javascript/syntax:*js-gdi-global-reference-mode*))
                             (fallback-expr nil))
                         (when reparse-fallback-p
                           (multiple-value-bind (_stream expr-form
                                                         _param
                                                         _optional
                                                         _pattern
                                                         _candidate)
                               (%js-parse-arrow-or-paren-item current)
                             (declare (ignore _stream _param _optional _pattern _candidate))
                             (setf fallback-expr expr-form)))
                         (multiple-value-bind (new-current expr-form
                                                           param-sym
                                                           optional-pair
                                                           pattern-pair
                                                           arrow-candidate-p)
                             (let ((cl-cc/javascript/syntax:*js-gdi-shadowed-names*
                                    (append (reverse params)
                                            cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
                               (%js-parse-arrow-or-paren-item current))
                           (setf current new-current)
                           (push
                            (if reparse-fallback-p
                                fallback-expr
                                expr-form)
                            exprs)
                           (when param-sym
                             (push param-sym params))
                           (when optional-pair
                             (push optional-pair optionals))
                           (when pattern-pair
                             (push pattern-pair param-patterns))
                           (unless arrow-candidate-p
                             (setf is-arrow-candidate nil)))))
                do (multiple-value-bind (next-stream more-p) (%js-comma-list-step current :T-RPAREN)
                     (setf current next-stream)
                     (unless more-p
                       (return))))
          (multiple-value-bind (tok2 rest2) (js-expect :T-RPAREN current)
            (declare (ignore tok2))
            (if (and is-arrow-candidate (eq (js-peek-type rest2) :T-ARROW))
                (let* ((first-pass (multiple-value-list (%js-parse-param-list stream)))
                       (all-params (first first-pass)))
                  (multiple-value-bind (new-params new-stream
                                                   new-optionals
                                                   new-rest-sym
                                                   new-patterns)
                      (let ((cl-cc/javascript/syntax:*js-gdi-shadowed-names*
                             (append all-params cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
                        (%js-parse-param-list stream))
                    (%js-finish-arrow-function new-params
                                               new-stream
                                               :optionals
                                               new-optionals
                                               :rest-sym
                                               new-rest-sym
                                               :param-patterns
                                               new-patterns)))
                (let ((all-exprs (nreverse exprs)))
                  (values
                   (if (cdr all-exprs)
                       (make-ast-progn :forms all-exprs)
                       (car all-exprs))
                   rest2))))))))

(defun %js-finish-arrow-function (params stream &key optionals rest-sym param-patterns)
  "Parse => body and build a lambda."
  (multiple-value-bind (tok rest) (js-expect :T-ARROW stream)
    (declare (ignore tok))
    (let ((cl-cc/javascript/syntax:*js-gdi-shadowed-names*
           (append params cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
      (multiple-value-bind (required opts) (%js-split-params-by-defaults params optionals)
        (flet ((finish (body-forms rest2)
                 (multiple-value-bind (rest-param wrapped-body)
                     (%js-rest-binding rest-sym
                                       (%js-prepend-param-destructuring param-patterns body-forms))
                   (values
                    (make-ast-lambda :params
                                     required
                                     :optional-params
                                     opts
                                     :rest-param
                                     rest-param
                                     :body
                                     wrapped-body)
                    rest2))))
          (if (eq (js-peek-type rest) :T-LBRACE)
              (multiple-value-bind (tok2 rest2) (js-consume rest)
                (declare (ignore tok2))
                (multiple-value-bind (body-forms rest3)
                    (js-call-parser-handler :function-body rest2)
                  (finish (%js-callable-body body-forms) rest3)))
              (multiple-value-bind (expr rest2) (js-call-parser-handler :assignment-expression rest)
                (finish (list expr) rest2))))))))

;;; ─── Async Expression ────────────────────────────────────────────────────────
(defun %js-parse-async-expr (stream)
  "Parse async function or async arrow function.
Returns (values ast rest)."
  (multiple-value-bind (tok rest) (js-consume stream) ; consume 'async'
    (declare (ignore tok))
    (let ((next-type (js-peek-type rest))
          (next-val  (js-peek-value rest)))
      (cond
        ;; async function [*] name? (params) { body }
        ((eq next-type :T-FUNCTION)
         (%js-consume-then (rest2 (js-consume rest))
           (js-parse-function-expr rest2 :async-p t)))
        ;; async (params) => body  or  async ident => body
        ((eq next-type :T-LPAREN)
         ;; async arrow function: async (params) =>
         (multiple-value-bind (params optionals rest-sym rest2)
             (js-parse-params rest)
           (declare (ignore optionals rest-sym))
           (if (eq (js-peek-type rest2) :T-ARROW)
               (%js-finish-async-arrow params rest2)
               ;; Not an arrow — async followed by ( is a call: async(...)
               (multiple-value-bind (args rest3) (js-parse-arguments rest)
                 (values (make-ast-call :func (make-ast-var :name (js-ident-sym "async"))
                                        :args args)
                         rest3)))))
        ;; async ident => body (single param arrow)
        ((eq next-type :T-IDENT)
         (let ((param-sym (js-ident-sym next-val)))
           (multiple-value-bind (tok2 rest2) (js-consume rest)
             (declare (ignore tok2))
             (if (eq (js-peek-type rest2) :T-ARROW)
                 (%js-finish-async-arrow (list param-sym) rest2)
                 ;; async used as property / identifier
                 (multiple-value-bind (ast rest3)
                     (js-parse-postfix (make-ast-var :name (js-ident-sym "async")) rest)
                   (values ast rest3))))))
        ;; async as standalone identifier
        (t
         (values (make-ast-var :name (js-ident-sym "async")) rest))))))

(defun %js-finish-async-arrow (params stream)
  "Parse => body for an async arrow function."
  (multiple-value-bind (tok rest) (js-expect :T-ARROW stream)
    (declare (ignore tok))
    (let ((cl-cc/javascript/syntax:*js-gdi-shadowed-names*
           (append params cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
      (let ((body-and-rest
             (if (eq (js-peek-type rest) :T-LBRACE)
                 (multiple-value-bind (tok2 rest2) (js-consume rest)
                   (declare (ignore tok2))
                   (multiple-value-bind (body-forms rest3)
                       (js-call-parser-handler :function-body rest2)
                     (list (%js-callable-body body-forms) rest3)))
                 (multiple-value-bind (expr rest2)
                     (js-call-parser-handler :assignment-expression rest)
                   (list (list expr) rest2)))))
        (values
         (%js-call (quote %js-object-make-async)
                   (make-ast-lambda :params params :body (car body-and-rest)))
         (cadr body-and-rest))))))

;;; ─── Class Expression ────────────────────────────────────────────────────────
(defun %js-parse-class-expr (stream)
  "Parse a class EXPRESSION: class [name] [extends expr] { body }.
Delegates to js-parse-class-decl (parser-class.lisp) — the single source of
truth for class parsing — with :expression-p t. Returns (values ast rest).

Previously this file carried duplicate %js-parse-class-body/%js-parse-class-member
definitions that, under serial load, were shadowed by parser-class.lisp's
arity-2 %js-parse-class-body, so the old 1-arg call here crashed every class
expression. Routing through js-parse-class-decl removes the duplication."
  (multiple-value-bind (tok rest) (js-consume stream) ; consume 'class'
    (declare (ignore tok))
    (multiple-value-bind (ast-list rest2) (js-call-parser-handler :class-declaration rest :expression-p t)
      (values (if (and (consp ast-list) (= (length ast-list) 1))
                  (first ast-list)
                  (make-ast-progn :forms ast-list))
              rest2))))

;;; ─── import() Dynamic Import ─────────────────────────────────────────────────
(defun %js-parse-import-expr (stream)
  "Parse import(specifier) or import.meta.
Returns (values ast rest)."
  (multiple-value-bind (tok rest) (js-consume stream) ; consume 'import'
    (declare (ignore tok))
    (cond
      ;; import.meta
      ((and (eq (js-peek-type rest) :T-DOT)
            (eq (js-peek-type (cdr rest)) :T-META))
       (%js-consume-then (rest2 (js-consume rest))
         (%js-consume-then (rest3 (js-consume rest2))
           (values (%js-call '%js-import-meta) rest3))))
      ;; import(specifier)
      ((eq (js-peek-type rest) :T-LPAREN)
       (multiple-value-bind (tok2 rest2) (js-consume rest)
         (declare (ignore tok2))
         (multiple-value-bind (spec-ast rest3) (js-call-parser-handler :assignment-expression rest2)
           (multiple-value-bind (tok3 rest4) (js-expect :T-RPAREN rest3)
             (declare (ignore tok3))
             (values (%js-call '%js-import spec-ast) rest4)))))
      (t
       (error "JS parse error: unexpected token after 'import': ~S" (js-peek rest))))))

;;; ─── import() Dynamic Import ─────────────────────────────────────────────────
(eval-when (:load-toplevel :execute)
  (register-js-parser-handler :function-paren-or-arrow (function %js-parse-paren-or-arrow))
  (register-js-parser-handler :function-finish-arrow (function %js-finish-arrow-function))
  (register-js-parser-handler :function-async-expression (function %js-parse-async-expr))
  (register-js-parser-handler :function-class-expression (function %js-parse-class-expr))
  (register-js-parser-handler :function-import-expression (function %js-parse-import-expr)))
