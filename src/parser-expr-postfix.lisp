;;;; packages/javascript/src/parser-expr-postfix.lisp — Postfix, unary, template, new
;;;;
;;;; Second half of the expression parser: new/member expressions, postfix operators
;;;; (++/--, . [] () ?.),  template literals, and prefix unary operators.
;;;;
;;;; Depends on parser-expr.lisp (defines %js-call, %js-place-get-prop-p, etc.)
;;;; Load order: after parser-expr.lisp, before parser-expr-primary.lisp.

(in-package :cl-cc/javascript)

;;; ─── New Expression ──────────────────────────────────────────────────────────

(defun js-parse-new-expr (stream)
  "Parse new ClassName(args) or new.target. Returns (values ast rest)."
  (multiple-value-bind (tok rest) (js-consume stream) ; consume 'new'
    (declare (ignore tok))
    ;; new.target
    (when (and (eq (js-peek-type rest) :T-DOT)
               (eq (js-peek-type (cdr rest)) :T-TARGET))
      (multiple-value-bind (dot-tok rest2) (js-consume rest)
        (declare (ignore dot-tok))
        (multiple-value-bind (target-tok rest3) (js-consume rest2)
          (declare (ignore target-tok))
          (return-from js-parse-new-expr
            (values (%js-call '%js-new-target) rest3)))))
    ;; new expr
    (multiple-value-bind (ctor-ast rest2) (js-parse-member-expr rest)
      ;; Optional argument list
      (if (eq (js-peek-type rest2) :T-LPAREN)
          (multiple-value-bind (args rest3) (js-parse-arguments rest2)
            (values (%js-call '%js-new ctor-ast
                              (make-ast-call :func (make-ast-var :name '%js-make-array)
                                             :args args))
                    rest3))
          (values (%js-call '%js-new ctor-ast
                            (%js-call '%js-make-array))
                  rest2)))))

(defun %js-parse-member-dot (ast stream)
  "obj.prop for a 'new' member expression. Unlike the postfix version, there
is no private-field (#name) special-casing here — that only applies in
class-body postfix context. STREAM points past '.'.
Returns (values ast new-stream)."
  (multiple-value-bind (prop-tok rest3) (js-consume stream)
    (let* ((prop-str (js-tok-value prop-tok))
           (key (make-ast-quote :value prop-str)))
      (values (make-ast-call :func (make-ast-var :name '%js-get-prop)
                             :args (list ast key))
              rest3))))

(defun %js-parse-member-optional-chain (ast stream)
  "?.prop / ?.[expr] for a 'new' member expression. Unlike the postfix
version, there is no standalone ?.(args) case — calls are not valid in
member-expression context. STREAM points past '?.'.
Returns (values ast new-stream continue-p); CONTINUE-P is false when nothing
recognizable follows, matching the original inline loop-exit (return)."
  (cond
    ;; ?.prop — if followed by ( emit optional-method-call, else optional-chain
    ((eq (js-peek-type stream) :T-IDENT)
     (multiple-value-bind (prop-tok rest3) (js-consume stream)
       (let ((key (make-ast-quote :value (js-tok-value prop-tok))))
         (if (eq (js-peek-type rest3) :T-LPAREN)
             (multiple-value-bind (args rest4) (js-parse-arguments rest3)
               (values (make-ast-call :func (make-ast-var :name '%js-optional-method-call)
                                      :args (list* ast key args))
                       rest4 t))
             (values (make-ast-call :func (make-ast-var :name '%js-optional-chain)
                                    :args (list ast key))
                     rest3 t)))))
    ;; ?.[expr]
    ((eq (js-peek-type stream) :T-LBRACKET)
     (multiple-value-bind (tok2 rest3) (js-consume stream)
       (declare (ignore tok2))
       (multiple-value-bind (idx-ast rest4) (js-parse-assignment-expr rest3)
         (multiple-value-bind (tok3 rest5) (js-expect :T-RBRACKET rest4)
           (declare (ignore tok3))
           (values (make-ast-call :func (make-ast-var :name '%js-optional-chain)
                                  :args (list ast idx-ast))
                   rest5 t)))))
    (t (values ast stream nil))))

(defun js-parse-member-expr (stream)
  "Parse a member expression for 'new' context (no call, only . and []).
Returns (values ast rest)."
  (multiple-value-bind (ast rest) (js-parse-primary stream)
    ;; Apply member accesses only (no calls — that would be CallExpression)
    (loop
      (let ((type (js-peek-type rest))
            (val  (js-peek-value rest)))
        (cond
          ;; obj.prop
          ((eq type :T-DOT)
           (multiple-value-bind (tok rest2) (js-consume rest)
             (declare (ignore tok))
             (multiple-value-bind (new-ast new-rest) (%js-parse-member-dot ast rest2)
               (setf ast new-ast rest new-rest))))
          ;; obj[expr]
          ((eq type :T-LBRACKET)
           (multiple-value-bind (tok rest2) (js-consume rest)
             (declare (ignore tok))
             (multiple-value-bind (new-ast new-rest) (%js-parse-postfix-computed-member ast rest2)
               (setf ast new-ast rest new-rest))))
          ;; optional chain ?.
          ((and (eq type :T-OP) (string= val "?."))
           (multiple-value-bind (tok rest2) (js-consume rest)
             (declare (ignore tok))
             (multiple-value-bind (new-ast new-rest continue-p)
                 (%js-parse-member-optional-chain ast rest2)
               (setf ast new-ast rest new-rest)
               (unless continue-p (return)))))
          (t (return)))))
    (values ast rest)))

;;; ─── Increment / decrement on places (obj.x / arr[i]) ────────────────────────

(defun %js-place-get-prop-p (ast)
  "True when AST is an assignable property place — either a public property
access (%js-get-prop OBJ KEY) or a private field access
(%js-class-private-field-get OBJ KEY)."
  (and (ast-call-p ast)
       (ast-var-p (ast-call-func ast))
       (member (ast-var-name (ast-call-func ast))
               '(%js-get-prop %js-class-private-field-get))
       (= (length (ast-call-args ast)) 2)))

(defun %js-lower-place-incdec (place op return-new-p)
  "Lower ++/-- applied to a property/element PLACE.
PLACE may be a public (%js-get-prop) or private (%js-class-private-field-get) access.
OP is '+ or '-. RETURN-NEW-P true means prefix (yields updated value); false
means postfix (yields original). OBJ and KEY are captured in temps so the place
expression is evaluated exactly once."
  (let* ((obj     (first  (ast-call-args place)))
         (key     (second (ast-call-args place)))
         (get-fn  (ast-var-name (ast-call-func place)))
         (set-fn  (if (eq get-fn '%js-class-private-field-get)
                      '%js-class-private-field-set
                      '%js-set-prop))
         (obj-tmp (gensym "JS-OBJ-"))
         (key-tmp (gensym "JS-KEY-"))
         (old-tmp (gensym "JS-OLD-")))
    (flet ((bumped ()
             (make-ast-binop :op op
                             :lhs (make-ast-var :name old-tmp)
                             :rhs (make-ast-int :value 1))))
      (make-ast-let
       :bindings (list (cons obj-tmp obj) (cons key-tmp key))
       :body
       (list
        (make-ast-let
         :bindings (list (cons old-tmp (%js-call get-fn
                                                 (make-ast-var :name obj-tmp)
                                                 (make-ast-var :name key-tmp))))
         :body (list (%js-call set-fn
                               (make-ast-var :name obj-tmp)
                               (make-ast-var :name key-tmp)
                               (bumped))
                     (if return-new-p (bumped) (make-ast-var :name old-tmp)))))))))

(defun %js-lower-incdec (expr op-sym prefix-p fallback-helper)
  "Lower a ++/-- application to EXPR (OP-SYM is '+ or '-), shared by prefix
and postfix parsing. A plain variable rewrites to a direct setq (prefix:
yields the updated value; postfix: binds the original to a temp and yields
that). A property/element place delegates to %js-lower-place-incdec, which
already knows prefix vs postfix. Anything else falls back to FALLBACK-HELPER
\(%js-prefix-inc / %js-postfix-inc / -dec at the call site)."
  (cond
    ((ast-var-p expr)
     (let ((var-sym (ast-var-name expr)))
       (if prefix-p
           (make-ast-setq :var var-sym
                          :value (make-ast-binop :op op-sym :lhs expr :rhs (make-ast-int :value 1)))
           (let ((tmp (gensym "JS-POSTFIX-")))
             (make-ast-let
              :bindings (list (cons tmp (make-ast-var :name var-sym)))
              :body (list (make-ast-setq
                           :var var-sym
                           :value (make-ast-binop :op op-sym
                                                  :lhs (make-ast-var :name var-sym)
                                                  :rhs (make-ast-int :value 1)))
                          (make-ast-var :name tmp)))))))
    ((%js-place-get-prop-p expr)
     (%js-lower-place-incdec expr op-sym prefix-p))
    (t (%js-call fallback-helper expr))))

;;; ─── Postfix ─────────────────────────────────────────────────────────────────

(defun %js-parse-postfix-dot (ast stream)
  "obj.prop or obj.#privateField — STREAM points past '.'."
  (multiple-value-bind (prop-tok rest2) (js-consume stream)
    (let ((key (make-ast-quote :value (js-tok-value prop-tok)))
          (accessor (if (eq (js-peek-type stream) :T-PRIVATE-IDENT)
                        '%js-class-private-field-get
                        '%js-get-prop)))
      (values (make-ast-call :func (make-ast-var :name accessor) :args (list ast key))
              rest2))))

(defun %js-parse-postfix-computed-member (ast stream)
  "obj[expr] — STREAM points past '['."
  (multiple-value-bind (idx-ast rest2) (js-parse-assignment-expr stream)
    (multiple-value-bind (tok2 rest3) (js-expect :T-RBRACKET rest2)
      (declare (ignore tok2))
      (values (make-ast-call :func (make-ast-var :name '%js-get-prop)
                             :args (list ast idx-ast))
              rest3))))

(defun %js-parse-postfix-call (ast stream)
  "fn(args) — STREAM points at '('."
  (multiple-value-bind (args rest) (js-parse-arguments stream)
    (values (cond
              ((%js-items-have-spread-p args)
               (make-ast-apply :func ast :args (list (%js-spread-list-expr args))))
              ((and (ast-var-p ast)
                    (gethash (ast-var-name ast) *js-coercion-call-helpers*))
               (%js-lower-coercion-call
                (gethash (ast-var-name ast) *js-coercion-call-helpers*) args))
              (t (make-ast-call :func ast :args args)))
            rest)))

(defun %js-parse-postfix-optional-chain (ast stream)
  "?.prop / ?.[expr] / ?.(args) — STREAM points past '?.'.
Returns (values ast new-stream continue-p); CONTINUE-P is false when nothing
recognizable follows, matching the original inline loop-exit (return)."
  (cond
    ;; ?.prop — if followed by ( emit optional-method-call, else optional-chain
    ((eq (js-peek-type stream) :T-IDENT)
     (multiple-value-bind (prop-tok rest2) (js-consume stream)
       (let ((key (make-ast-quote :value (js-tok-value prop-tok))))
         (if (eq (js-peek-type rest2) :T-LPAREN)
             (multiple-value-bind (args rest3) (js-parse-arguments rest2)
               (values (make-ast-call :func (make-ast-var :name '%js-optional-method-call)
                                      :args (list* ast key args))
                       rest3 t))
             (values (make-ast-call :func (make-ast-var :name '%js-optional-chain)
                                    :args (list ast key))
                     rest2 t)))))
    ;; ?.[expr]
    ((eq (js-peek-type stream) :T-LBRACKET)
     (multiple-value-bind (tok2 rest2) (js-consume stream)
       (declare (ignore tok2))
       (multiple-value-bind (idx-ast rest3) (js-parse-assignment-expr rest2)
         (multiple-value-bind (tok3 rest4) (js-expect :T-RBRACKET rest3)
           (declare (ignore tok3))
           (values (make-ast-call :func (make-ast-var :name '%js-optional-chain)
                                  :args (list ast idx-ast))
                   rest4 t)))))
    ;; ?.(args)
    ((eq (js-peek-type stream) :T-LPAREN)
     (multiple-value-bind (args rest2) (js-parse-arguments stream)
       (values (make-ast-call :func (make-ast-var :name '%js-optional-call)
                              :args (cons ast args))
               rest2 t)))
    (t (values ast stream nil))))

(defun js-parse-postfix (ast stream)
  "Apply postfix operations: ++ -- . [] () ?. to AST.
Returns (values ast rest). Loops until no more postfix ops."
  (loop
    (let ((type (js-peek-type stream))
          (val  (js-peek-value stream)))
      (cond
        ;; Postfix ++
        ((and (eq type :T-OP) (string= val "++"))
         (multiple-value-bind (tok rest) (js-consume stream)
           (declare (ignore tok))
           (setf ast (%js-lower-incdec ast '+ nil '%js-postfix-inc)
                 stream rest)))
        ;; Postfix --
        ((and (eq type :T-OP) (string= val "--"))
         (multiple-value-bind (tok rest) (js-consume stream)
           (declare (ignore tok))
           (setf ast (%js-lower-incdec ast '- nil '%js-postfix-dec)
                 stream rest)))
        ;; Property access: obj.prop
        ((eq type :T-DOT)
         (multiple-value-bind (tok rest) (js-consume stream)
           (declare (ignore tok))
           (multiple-value-bind (new-ast new-stream) (%js-parse-postfix-dot ast rest)
             (setf ast new-ast stream new-stream))))
        ;; Computed member: obj[expr]
        ((eq type :T-LBRACKET)
         (multiple-value-bind (tok rest) (js-consume stream)
           (declare (ignore tok))
           (multiple-value-bind (new-ast new-stream) (%js-parse-postfix-computed-member ast rest)
             (setf ast new-ast stream new-stream))))
        ;; Call: fn(args)
        ((eq type :T-LPAREN)
         (multiple-value-bind (new-ast new-stream) (%js-parse-postfix-call ast stream)
           (setf ast new-ast stream new-stream)))
        ;; Optional chain ?.
        ((and (eq type :T-OP) (string= val "?."))
         (multiple-value-bind (tok rest) (js-consume stream)
           (declare (ignore tok))
           (multiple-value-bind (new-ast new-stream continue-p)
               (%js-parse-postfix-optional-chain ast rest)
             (setf ast new-ast stream new-stream)
             (unless continue-p (return)))))
        ;; Tagged template literal
        ((or (eq type :T-TEMPLATE-START)
             (eq type :T-TEMPLATE-PARTS))
         (multiple-value-bind (call-ast rest) (%js-parse-tagged-template ast stream)
           (setf ast call-ast stream rest)))
        (t (return)))))
  (values ast stream))
