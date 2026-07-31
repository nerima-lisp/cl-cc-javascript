;;;; packages/javascript/src/parser-stmt-binding.lisp — JS destructuring & binding helpers
;;;;
;;;; Extracted from parser-stmt.lisp to isolate the binding/destructuring machinery.
;;;; Loaded before parser-stmt.lisp so these helpers are available to all subsequent
;;;; parser files (parser-stmt, parser-stmt-control, etc.).
(in-package :cl-cc/javascript)

;;; ─── Token Stream Helpers (needed by binding parsers) ────────────────────────
;;; js-peek*, js-consume, js-expect, js-at-eof-p are in parser.lisp (loads first).
(defun %js-consume-expected (type stream)
  "Like js-expect but returns only the rest stream (discards the token)."
  (nth-value 1 (js-expect type stream)))

(defun js-skip-semis (stream)
  "Skip zero or more semicolons in a loop (unlike js-skip-semi which skips one)."
  (loop while (and stream (eq (js-peek-type stream) :T-SEMI))
        do (setf stream (cdr stream)))
  stream)

;;; ─── Variable / Binding Pattern Helpers ─────────────────────────────────────
(defun %js-binding-sym (name)
  "Intern a JS binding name (param, let/const/var, destructured name) as a symbol
in :cl-cc/javascript — using the SAME scheme as js-ident-sym so a binding and its
references resolve to the identical symbol.

Previously this prefixed names with `JS.', so a parameter or local bound the
symbol JS.X while the body referenced X (via js-ident-sym). Every `return param'
or `console.log(localVar)' then hit an unbound variable, the enclosing function
body failed to compile, the top-level handler-case silently dropped the defun,
and calls reported `Undefined function'. The package already namespaces JS
symbols, so the prefix was redundant as well as desynchronized.

Preserves CASE — must use the IDENTICAL scheme as js-ident-sym (JavaScript is
case-sensitive), so a binding and its references resolve to the same symbol."
  (intern
    (if (stringp name) name
      (symbol-name name))
    :cl-cc/javascript))

(defun %js-parse-pattern-default (stream)
  "If STREAM begins with `= expr`, consume it and return (values default-ast rest);
otherwise return (values nil stream). Used for destructuring defaults like
[a = 1] and {a = 1}."
  (if (and stream (eq (js-peek-type stream) :T-OP) (equal (js-peek-value stream) "=")) (multiple-value-bind (_tok rest) (js-consume stream)
      (declare (ignore _tok))
      (js-parse-assignment-expr rest))
    (values nil stream)))

(defun %js-default-access (access-expr default-ast)
  "Wrap ACCESS-EXPR so it yields DEFAULT-AST when the access is undefined,
matching JS destructuring-default semantics. Returns ACCESS-EXPR unchanged when
DEFAULT-AST is nil."
  (if default-ast (make-ast-if
      :cond
      (make-ast-call
        :func
        (make-ast-var :name '%js-strict-eq)
        :args
        (list access-expr (make-ast-quote :value :js-undefined)))
      :then
      default-ast
      :else
      access-expr)
    access-expr))

(defun %js-parse-object-binding-pattern (stream)
  "Parse {a, b: c, ...rest} destructuring pattern. STREAM points past '{'.
Returns (values (:object-pattern tmp keys) rest)."
  (let ((current stream)
        (keys nil))
    (loop
      (setf current (js-skip-semis current))
      (when (or (js-at-eof-p current)
                (eq (js-peek-type current) :T-RBRACE))
        (return))
      (cond
        ;; Rest element: ...rest
        ((eq (js-peek-type current) :T-ELLIPSIS)
         (setf current (cdr current))
         (multiple-value-bind (tok rest) (js-consume current)
           (push (list :rest (%js-binding-sym (js-tok-value tok))) keys)
           (setf current rest)))
        ;; key: binding or shorthand key
        (t
         (multiple-value-bind (key-tok rest) (js-consume current)
           (let* ((key-name (js-tok-value key-tok))
                  (local-sym (%js-binding-sym key-name)))
             (if (and rest (eq (js-peek-type rest) :T-COLON))
                 (progn
                   (setf rest (cdr rest))
                   (multiple-value-bind (local-sym2 rest2)
                       (%js-parse-binding-pattern rest)
                     ;; key: pattern [= default]
                     (multiple-value-bind (dflt rest3) (%js-parse-pattern-default rest2)
                       (push (list key-name local-sym2 dflt) keys)
                       (setf current rest3))))
                 ;; shorthand {key [= default]}
                 (multiple-value-bind (dflt rest2) (%js-parse-pattern-default rest)
                   (push (list key-name local-sym dflt) keys)
                   (setf current rest2)))))))
      (when (eq (js-peek-type current) :T-COMMA)
        (setf current (cdr current))))
    (setf current (%js-consume-expected :T-RBRACE current))
    ;; Return a gensym for the binding; destructuring is emitted as a let
    (let ((tmp (gensym "OBJ-DEST-")))
      (values (list :object-pattern tmp (nreverse keys)) current))))

(defun %js-parse-array-binding-pattern (stream)
  "Parse [a, b, ...rest] destructuring pattern. STREAM points past '['.
Returns (values (:array-pattern tmp elements) rest)."
  (let ((current stream)
        (elements nil))
    (loop
      (setf current (js-skip-semis current))
      (when (or (js-at-eof-p current)
                (eq (js-peek-type current) :T-RBRACKET))
        (return))
      (cond
        ;; Elision (hole): ,
        ((eq (js-peek-type current) :T-COMMA)
         (push :hole elements))
        ;; Rest element: ...rest
        ((eq (js-peek-type current) :T-ELLIPSIS)
         (setf current (cdr current))
         (multiple-value-bind (tok rest) (js-consume current)
           (push (list :rest (%js-binding-sym (js-tok-value tok))) elements)
           (setf current rest)))
        (t
         (multiple-value-bind (sym rest) (%js-parse-binding-pattern current)
           ;; element [= default]
           (multiple-value-bind (dflt rest2) (%js-parse-pattern-default rest)
             (push (if dflt (list :default sym dflt) sym) elements)
             (setf current rest2)))))
      (when (eq (js-peek-type current) :T-COMMA)
        (setf current (cdr current))))
    (setf current (%js-consume-expected :T-RBRACKET current))
    (let ((tmp (gensym "ARR-DEST-")))
      (values (list :array-pattern tmp (nreverse elements)) current))))

(defun %js-parse-binding-pattern (stream)
  "Parse a destructuring pattern or simple identifier.
  Returns (values sym/pattern rest).
  Handles: ident, {a,b,...}, [a,b,...] — simplified to %js-destructure-object/array calls."
  (let ((type (js-peek-type stream)))
    (cond
      ;; Simple identifier
      ((eq type :T-IDENT)
       (multiple-value-bind (tok rest) (js-consume stream)
         (values (%js-binding-sym (js-tok-value tok)) rest)))
      ;; Contextual keywords are valid identifiers in a binding position
      ;; (const set = …, function f(get){…}).  They only act as keywords in
      ;; specific positions (class getter/setter, for-of, import …), which are
      ;; parsed before reaching here.  Mirrors the expression-side handling.
      ((member type *js-contextual-keyword-token-types* :test #'eq)
       (multiple-value-bind (tok rest) (js-consume stream)
         (values (%js-binding-sym (js-tok-value tok)) rest)))
      ;; Object destructuring: {a, b: c, ...rest}
      ((eq type :T-LBRACE)
       (%js-parse-object-binding-pattern (cdr stream)))
      ;; Array destructuring: [a, b, ...rest]
      ((eq type :T-LBRACKET)
       (%js-parse-array-binding-pattern (cdr stream)))
      (t
       (error "JS parse error: expected binding pattern, got ~S" (js-peek stream))))))

(defun %js-binding-to-sym (binding-or-sym)
  "Extract the primary gensym from a binding pattern or plain symbol."
  (if (listp binding-or-sym) (second binding-or-sym)
    binding-or-sym))

(defun %js-destructure-sub-bindings (target access-expr)
  "Return an ORDERED list of (sym . init) bindings for a destructuring sub-TARGET
initialized from ACCESS-EXPR.  When TARGET is itself a nested array/object pattern
(e.g. the [b,c] in [a,[b,c]], or the {b} in {a:{b}}), recurse so the nested names
are bound too; a plain symbol yields a single binding.  Recursion is what makes
nested destructuring work — previously the nested pattern's gensym was bound but
never unpacked, so b/c stayed undefined and the binding form failed to compile."
  (if (and (listp target) (member (first target) '(:array-pattern :object-pattern))) (multiple-value-bind (b _e) (%js-emit-destructure-bindings target access-expr)
      (declare (ignore _e))
      b)
    (list (cons (%js-binding-to-sym target) access-expr))))

(defun %js-emit-rest-property-binding (rest-sym tmp consumed-keys)
  "The single (sym . init-expr) binding for an object pattern's ...rest
property: (%js-destructure-object TMP :rest KEY1 KEY2 ...), passing the
already-bound keys so they're excluded from the rest object. Object-pattern
rest is syntactically last, so CONSUMED-KEYS is always complete by the time
this runs."
  (cons rest-sym
        (make-ast-call
         :func (make-ast-var :name '%js-destructure-object)
         :args (list* (make-ast-var :name tmp)
                      (make-ast-quote :value :rest)
                      (mapcar (lambda (k) (make-ast-quote :value k))
                              (reverse consumed-keys))))))

(defun %js-emit-named-property-bindings (field tmp)
  "The bindings alist for one named object-pattern property FIELD — (key
local default). LOCAL may itself be a nested pattern, so this recurses via
%js-destructure-sub-bindings."
  (let* ((key    (first field))
         (local  (second field))
         (dflt   (third field))
         (access (%js-default-access
                  (make-ast-call
                   :func (make-ast-var :name '%js-get-prop)
                   :args (list (make-ast-var :name tmp)
                               (make-ast-quote :value key)))
                  dflt)))
    (%js-destructure-sub-bindings local access)))

(defun %js-emit-object-pattern-bindings (tmp desc init-expr)
  "Emit bindings for an :object-pattern with temp symbol TMP and field
descriptor list DESC (as produced by %js-parse-object-binding-pattern),
initialized from INIT-EXPR. Returns a bindings alist ((sym . init-expr) ...)
in let* order."
  ;; tmp = init-expr, then destructure fields. LOOP's NCONC clause splices
  ;; each field's fresh bindings list onto the accumulated tail in O(1), so
  ;; the whole walk stays O(n) in the number of bindings emitted rather than
  ;; the O(n^2) a repeated (setf bindings (append bindings ...)) costs.
  (let ((consumed-keys nil))
    (cons (cons tmp init-expr)
          (loop for field in desc
                nconc (if (eq (car field) :rest)
                          (list (%js-emit-rest-property-binding (second field) tmp consumed-keys))
                          (progn
                            (push (first field) consumed-keys)
                            (%js-emit-named-property-bindings field tmp)))))))

(defun %js-emit-array-rest-binding (rest-sym tmp idx)
  "The single (sym . init-expr) binding for an array pattern's ...rest
element: (%js-destructure-array TMP IDX :rest)."
  (cons rest-sym
        (make-ast-call
         :func (make-ast-var :name '%js-destructure-array)
         :args (list (make-ast-var :name tmp)
                     (make-ast-quote :value idx)
                     (make-ast-quote :value :rest)))))

(defun %js-emit-array-element-bindings (target tmp idx default)
  "The bindings alist for one array-pattern element at IDX — TARGET may
itself be a nested pattern. DEFAULT is the :default form's default-ast, or
nil for a plain element; %js-default-access returns its access-expr
unchanged when DEFAULT is nil, so this one path covers both cases."
  (let ((access (%js-default-access
                 (make-ast-call
                  :func (make-ast-var :name '%js-get-prop)
                  :args (list (make-ast-var :name tmp)
                              (make-ast-quote :value idx)))
                 default)))
    (%js-destructure-sub-bindings target access)))

(defun %js-emit-array-pattern-bindings (tmp desc init-expr)
  "Emit bindings for an :array-pattern with temp symbol TMP and element
descriptor list DESC (as produced by %js-parse-array-binding-pattern),
initialized from INIT-EXPR. Returns a bindings alist ((sym . init-expr) ...)
in let* order."
  ;; tmp = init-expr, then destructure by index. See
  ;; %js-emit-object-pattern-bindings for why NCONC replaces repeated APPEND.
  (let ((idx 0))
    (cons (cons tmp init-expr)
          (loop for elem in desc
                nconc (cond
                        ((eq elem :hole)
                         (incf idx)
                         nil)
                        ((and (listp elem) (eq (car elem) :rest))
                         (list (%js-emit-array-rest-binding (second elem) tmp idx)))
                        ;; element with default: (:default target default-ast) — TARGET may
                        ;; be a nested pattern.
                        ((and (listp elem) (eq (car elem) :default))
                         (prog1 (%js-emit-array-element-bindings (second elem) tmp idx (third elem))
                           (incf idx)))
                        ;; plain element — may itself be a nested pattern.
                        (t
                         (prog1 (%js-emit-array-element-bindings elem tmp idx nil)
                           (incf idx))))))))

(defun %js-emit-destructure-bindings (binding init-expr)
  "Emit let bindings for a destructuring BINDING initialized from INIT-EXPR.
  Returns (values bindings-alist extra-lets) where bindings-alist is
  ((sym . init-expr) ...) in let* order and extra-lets is unused (nil).
  Order is preserved throughout: a nested pattern's gensym must be bound
  before the bindings that read from it."
  (if (listp binding) (let ((kind (first binding))
          (tmp (second binding))
          (desc (third binding)))
      (case kind
        (:object-pattern
          (values (%js-emit-object-pattern-bindings tmp desc init-expr) nil))
        (:array-pattern
          (values (%js-emit-array-pattern-bindings tmp desc init-expr) nil))
        (t (values (list (cons binding init-expr)) nil))))
    (values (list (cons binding init-expr)) nil)))
