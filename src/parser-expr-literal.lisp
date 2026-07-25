;;;; packages/javascript/src/parser-expr-literal.lisp — Array/Object/Function-Expr parsers
;;;;
;;;; Extracted from parser-expr.lisp.  These three parsers form a cohesive
;;;; "literal expression" layer that builds compound primary expressions.
;;;; Load order: after parser-expr-args.lisp (needs js-parse-params, %js-call),
;;;;             before parser-expr-primary.lisp (calls these parsers).

(in-package :cl-cc/javascript)

;;; ─── Array Literal ───────────────────────────────────────────────────────────

(defun js-parse-array-literal (stream)
  "Parse [...] array literal. Returns (values ast rest).
Handles elision (holes), spread elements, and assignment expressions."
  (multiple-value-bind (tok rest) (js-expect :T-LBRACKET stream)
    (declare (ignore tok))
    (if (eq (js-peek-type rest) :T-RBRACKET)
        (multiple-value-bind (tok2 rest2) (js-consume rest)
          (declare (ignore tok2))
          (values (%js-call '%js-make-array) rest2))
        (let ((elements nil)
              (current rest))
          (loop
            (when (eq (js-peek-type current) :T-RBRACKET)
              (return))
            (cond
              ;; Elision hole: consecutive comma or leading comma
              ((eq (js-peek-type current) :T-COMMA)
               (push (make-ast-quote :value :js-hole) elements)
               (multiple-value-bind (tok2 rest2) (js-consume current)
                 (declare (ignore tok2))
                 (setf current rest2)))
              ;; Spread element: ...expr
              ((eq (js-peek-type current) :T-ELLIPSIS)
               (multiple-value-bind (tok2 rest2) (js-consume current)
                 (declare (ignore tok2))
                 (multiple-value-bind (expr rest3) (js-parse-assignment-expr rest2)
                   (push (%js-call '%js-spread expr) elements)
                   (setf current rest3)
                   ;; Consume trailing comma if present
                   (when (eq (js-peek-type current) :T-COMMA)
                     (multiple-value-bind (tok3 rest4) (js-consume current)
                       (declare (ignore tok3))
                       (setf current rest4))))))
              ;; Regular element
              (t
               (multiple-value-bind (expr rest2) (js-parse-assignment-expr current)
                 (push expr elements)
                 (setf current rest2)
                 (cond
                   ((eq (js-peek-type current) :T-COMMA)
                    (multiple-value-bind (tok2 rest2b) (js-consume current)
                      (declare (ignore tok2))
                      (setf current rest2b)))
                   (t (return)))))))
          (multiple-value-bind (tok2 rest2) (js-expect :T-RBRACKET current)
            (declare (ignore tok2))
            (let ((elems (nreverse elements)))
              (values (if (%js-items-have-spread-p elems)
                          ;; [...a, x] -> (apply #'%js-make-array (append a (list x)))
                          (make-ast-apply :func '%js-make-array
                                          :args (list (%js-spread-list-expr elems)))
                          (make-ast-call :func (make-ast-var :name '%js-make-array)
                                         :args elems))
                      rest2)))))))

;;; ─── Object Literal ──────────────────────────────────────────────────────────

(defun %js-parse-object-property-spread (stream)
  "...expr — STREAM points at the ellipsis token."
  (multiple-value-bind (tok rest) (js-consume stream)
    (declare (ignore tok))
    (multiple-value-bind (expr rest2) (js-parse-assignment-expr rest)
      (values :spread expr nil nil rest2))))

(defun %js-parse-object-property-computed (stream)
  "[expr]: value or [expr](...) {} — STREAM points at '['."
  (multiple-value-bind (tok rest) (js-consume stream)
    (declare (ignore tok))
    (multiple-value-bind (key-expr rest2) (js-parse-assignment-expr rest)
      (multiple-value-bind (tok2 rest3) (js-expect :T-RBRACKET rest2)
        (declare (ignore tok2))
        (if (eq (js-peek-type rest3) :T-LPAREN)
            (multiple-value-bind (fn-ast rest4) (js-parse-function-expr rest3 :name nil)
              (values key-expr fn-ast t t rest4))
            (multiple-value-bind (tok3 rest4) (js-expect :T-COLON rest3)
              (declare (ignore tok3))
              (multiple-value-bind (val-expr rest5) (js-parse-assignment-expr rest4)
                (values key-expr val-expr nil t rest5))))))))

(defun %js-parse-object-property-generator-method (stream)
  "*name(...) {} — STREAM points past '*'."
  (let ((key-str (js-peek-value stream)))
    (multiple-value-bind (key-tok rest) (js-consume stream)
      (declare (ignore key-tok))
      (multiple-value-bind (fn-ast rest2)
          (js-parse-function-expr rest :generator-p t :name (js-ident-sym key-str))
        (values (make-ast-quote :value key-str) fn-ast t nil rest2)))))

(defun %js-parse-object-property-async-method (stream)
  "async [*]name(...) {} or the {async} shorthand — STREAM points past 'async'."
  (let ((next-type (js-peek-type stream))
        (next-val  (js-peek-value stream)))
    (cond
      ;; async * name — async generator
      ((and (eq next-type :T-OP) (string= next-val "*"))
       (multiple-value-bind (tok2 rest2) (js-consume stream)
         (declare (ignore tok2))
         (let ((key-str (js-peek-value rest2)))
           (multiple-value-bind (key-tok rest3) (js-consume rest2)
             (declare (ignore key-tok))
             (multiple-value-bind (fn-ast rest4)
                 (js-parse-function-expr rest3 :async-p t :generator-p t
                                               :name (js-ident-sym key-str))
               (values (make-ast-quote :value key-str) fn-ast t nil rest4))))))
      ;; async name (not followed by = or , — it's a shorthand method)
      ((or (eq next-type :T-IDENT)
           (eq next-type :T-STRING)
           (eq next-type :T-NUMBER))
       (let ((key-str next-val))
         (multiple-value-bind (key-tok rest2) (js-consume stream)
           (declare (ignore key-tok))
           (multiple-value-bind (fn-ast rest3)
               (js-parse-function-expr rest2 :async-p t :name (js-ident-sym key-str))
             (values (make-ast-quote :value key-str) fn-ast t nil rest3)))))
      ;; async used as shorthand property name: { async }
      (t
       (let ((key-sym (js-ident-sym "async")))
         (if (eq (js-peek-type stream) :T-COLON)
             (multiple-value-bind (tok2 rest2) (js-consume stream)
               (declare (ignore tok2))
               (multiple-value-bind (val-expr rest3) (js-parse-assignment-expr rest2)
                 (values (make-ast-quote :value "async") val-expr nil nil rest3)))
             (values (make-ast-quote :value "async")
                     (make-ast-var :name key-sym)
                     nil nil stream)))))))

(defun %js-parse-object-property-accessor (stream)
  "get name() {} / set name(x) {} — STREAM points at the T-GET/T-SET token."
  (let ((accessor-kind (js-tok-value (car stream))))
    (multiple-value-bind (tok rest) (js-consume stream)
      (declare (ignore tok))
      (let ((key-str (js-peek-value rest)))
        (multiple-value-bind (key-tok rest2) (js-consume rest)
          (declare (ignore key-tok))
          (multiple-value-bind (fn-ast rest3)
              (js-parse-function-expr rest2 :name (js-ident-sym key-str))
            (let ((tagged-fn (%js-call '%js-accessor
                                       (make-ast-quote :value accessor-kind)
                                       fn-ast)))
              (values (make-ast-quote :value key-str) tagged-fn t nil rest3))))))))

(defun %js-parse-object-property-shorthand-or-method-or-kv (stream key-str)
  "name(...) {} / name: value / {name} shorthand — STREAM points past the
already-consumed key token; KEY-STR is that key's value."
  (let ((next-type (js-peek-type stream)))
    (cond
      ;; Method shorthand: name(...) { }
      ((eq next-type :T-LPAREN)
       (multiple-value-bind (fn-ast rest2)
           (js-parse-function-expr stream :name (js-ident-sym key-str))
         (values (make-ast-quote :value key-str) fn-ast t nil rest2)))
      ;; Key : value
      ((eq next-type :T-COLON)
       (multiple-value-bind (tok2 rest2) (js-consume stream)
         (declare (ignore tok2))
         (multiple-value-bind (val-expr rest3) (js-parse-assignment-expr rest2)
           (values (make-ast-quote :value key-str) val-expr nil nil rest3))))
      ;; Shorthand: { name } — same as { name: name }
      (t
       (values (make-ast-quote :value key-str)
               (make-ast-var :name (js-ident-sym key-str))
               nil nil stream)))))

(defun %js-parse-object-property (stream)
  "Parse one property in an object literal.
Returns (values key-expr value-expr method-p computed-p rest)."
  (let ((type (js-peek-type stream))
        (val  (js-peek-value stream)))
    (cond
      ;; Spread: ...expr
      ((eq type :T-ELLIPSIS) (%js-parse-object-property-spread stream))
      ;; Computed property: [expr]: value
      ((eq type :T-LBRACKET) (%js-parse-object-property-computed stream))
      ;; Generator method: * name(...) { }
      ((and (eq type :T-OP) (string= val "*"))
       (%js-parse-object-property-generator-method (cdr stream)))
      ;; async method: async name(...) { }
      ((eq type :T-ASYNC)
       (%js-parse-object-property-async-method (cdr stream)))
      ;; get/set accessor: get name() { } / set name(x) { }
      ((and (or (eq type :T-GET) (eq type :T-SET))
            ;; Distinguish from shorthand {get} or {get, ...}, and from a
            ;; method named get/set: `{ get() {} }` — when `(` follows, `get`
            ;; is the METHOD NAME, so fall through to the method-shorthand arm.
            (let ((next (js-peek-type (cdr stream))))
              (and (not (eq next :T-COMMA))
                   (not (eq next :T-RBRACE))
                   (not (eq next :T-COLON))
                   (not (eq next :T-LPAREN))
                   (not (eq next :T-EOF)))))
       (%js-parse-object-property-accessor stream))
      ;; Identifier shorthand, method, or key: value
      (t
       (multiple-value-bind (key-tok rest) (js-consume stream)
         (declare (ignore key-tok))
         (%js-parse-object-property-shorthand-or-method-or-kv rest val))))))

(defun js-parse-object-literal (stream)
  "Parse {...} object literal. Returns (values ast rest).
Handles shorthand properties, method shorthands, computed keys,
spread elements, getters, and setters."
  (multiple-value-bind (tok rest) (js-expect :T-LBRACE stream)
    (declare (ignore tok))
    (if (eq (js-peek-type rest) :T-RBRACE)
        (multiple-value-bind (tok2 rest2) (js-consume rest)
          (declare (ignore tok2))
          (values (%js-call '%js-make-object) rest2))
        (let ((entries nil)        ; ordered: (:spread expr) | (:pair key val)
              (has-spread nil)
              (current rest))
          (loop
            (when (eq (js-peek-type current) :T-RBRACE)
              (return))
            (multiple-value-bind (key val method-p computed-p rest2)
                (%js-parse-object-property current)
              (declare (ignore method-p computed-p))
              (if (eq key :spread)
                  (progn (push (list :spread val) entries) (setf has-spread t))
                  (push (list :pair key val) entries))
              (setf current rest2))
            (if (eq (js-peek-type current) :T-COMMA)
                (multiple-value-bind (tok2 rest2) (js-consume current)
                  (declare (ignore tok2))
                  (setf current rest2))
                (return)))
          (setf entries (nreverse entries))
          (multiple-value-bind (tok2 rest2) (js-expect :T-RBRACE current)
            (declare (ignore tok2))
            (values
             (if has-spread
                 ;; {...a, k:v, ...b}: merge semantics. Fold entries left-to-right,
                 ;; threading the object: a spread copies the source's own props
                 ;; (%js-object-assign), a pair sets one key (%js-object-spread-set,
                 ;; which returns the object). Later entries override earlier keys.
                 (let ((acc (%js-call '%js-make-object)))
                   (dolist (e entries acc)
                     (setf acc (if (eq (first e) :spread)
                                   (%js-call '%js-object-assign acc (second e))
                                   (%js-call '%js-object-spread-set acc
                                             (second e) (third e))))))
                 (make-ast-call
                  :func (make-ast-var :name '%js-make-object)
                  :args (loop for e in entries
                              append (list (second e) (third e)))))
             rest2))))))

;;; ─── Function Expression Parser ──────────────────────────────────────────────

(defun js-parse-function-expr (stream &key async-p generator-p name)
  "Parse function [*] [name] (params) { body } as expression.
ASYNC-P and GENERATOR-P are boolean flags from the calling context.
NAME is an optional symbol for the function name.
Returns (values ast rest)."
  (let ((current stream)
        (is-generator generator-p))
    ;; Consume optional * for generators
    (when (and (eq (js-peek-type current) :T-OP)
               (string= (js-peek-value current) "*"))
      (multiple-value-bind (tok rest) (js-consume current)
        (declare (ignore tok))
        (setf is-generator t
              current rest)))
    ;; Optional function name
    (when (and (null name) (eq (js-peek-type current) :T-IDENT))
      (multiple-value-bind (name-tok rest) (js-consume current)
        (setf name (js-ident-sym (js-tok-value name-tok))
              current rest)))
    ;; Parameter list
    (multiple-value-bind (params optionals rest-sym rest2)
        (js-parse-params current)
      ;; Body: { stmts... }
      (multiple-value-bind (tok3 rest3) (js-expect :T-LBRACE rest2)
        (declare (ignore tok3))
        (multiple-value-bind (body-forms rest4)
            (js-parse-function-body rest3)
          (multiple-value-bind (required opts)
              (%js-split-params-by-defaults params optionals)
          ;; Wrap in (block nil ...) so `return' (which lowers to return-from nil)
          ;; works — a function-expression body was previously used raw, so any
          ;; `return value' silently produced nothing.
          (multiple-value-bind (rest-param wrapped-body)
              (%js-rest-binding rest-sym (%js-callable-body body-forms))
          (let ((lambda-ast (make-ast-lambda :params required
                                             :optional-params opts
                                             :rest-param rest-param
                                             :body wrapped-body)))
            ;; Wrap async/generator expressions.
            ;; Generator expressions use %js-wrap-generator-body which returns a
            ;; CALLABLE that creates a fresh generator on each invocation — unlike
            ;; %js-make-generator which runs the body eagerly with no arguments.
            (let ((result (cond
                            ((and async-p is-generator)
                             (%js-call '%js-make-async-generator lambda-ast))
                            (async-p
                             (%js-call '%js-make-async lambda-ast))
                            (is-generator
                             (%js-call '%js-wrap-generator-body lambda-ast))
                            (t lambda-ast))))
              ;; Named function expression — the name is visible INSIDE the body
              ;; (for self-recursion) but not outside.  A plain (let ((f lambda)) f)
              ;; binds in PARALLEL, so `f` inside the lambda body resolves to the
              ;; enclosing scope (undefined → "Undefined function") rather than the
              ;; function itself.  Bind the name to nil first, then assign the
              ;; lambda: the name is now mutated AND captured by the lambda, so the
              ;; compiler boxes it and the closure reads the assigned value —
              ;; letrec semantics, so `function fac(n){...fac(n-1)...}` recurses.
              (values (if name
                          (make-ast-let
                           :bindings (list (cons name (make-ast-quote :value nil)))
                           :body (list (make-ast-setq :var name :value result)
                                       (make-ast-var :name name)))
                          result)
                      rest4))))))))))

(defun js-parse-function-body (stream)
  "Parse statements inside { } until matching }."
  (funcall #'js-parse-stmt-list stream))
