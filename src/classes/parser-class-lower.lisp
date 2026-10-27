;;;; packages/javascript/src/parser-class-lower.lisp — JS class AST lowering
;;;;
;;;; Extracted from parser-class.lisp: the %js-lower-class-to-ast family and
;;;; the public js-parse-class-decl entry point. Per-role lowering (turning a
;;;; classified slot into %js-make-class arguments) only -- classifying which
;;;; slot is which role lives in parser-class-lower-classify.lisp.
;;;; Load order: after parser-class-lower-classify.lisp (needs its
;;;; %js-class-*-slots predicates and %js-class-member-key-ast/
;;;; %js-slot-to-method-lambda/%js-wrap-method-super helpers).
(in-package :cl-cc/javascript)

;;; ─── %js-lower-class-to-ast: per-role lowering ──────────────────────────────
(defun %js-lower-class-field-inits (field-slots)
  "Lower FIELD-SLOTS to (%js-set-prop this \"x\" init) forms — or the private-field
equivalent for #x fields — to prepend to the constructor body."
  (loop for slot in field-slots
        for imports   = (ast-imports slot)
        for private-p = (getf imports :js-private)
        for orig-name = (%js-class-member-orig-name slot)
        for initform  = (or (ast-slot-initform slot)
                            (make-ast-quote :value +js-undefined+))
        ;; Private fields (#x) must use the private-field-set accessor so
        ;; they land in the __private__ table, not the public property bag.
        ;; A computed field name ([expr] = init;) can never be private
        ;; (private names are always literal #ident), so only the public
        ;; branch needs the runtime %js-class-member-key-ast key.
        collect (if private-p
                    (%js-call '%js-class-private-field-set
                              (make-ast-var :name '%js-this)
                              (make-ast-quote :value orig-name)
                              initform)
                    (%js-call '%js-set-prop
                              (make-ast-var :name '%js-this)
                              (%js-class-member-key-ast slot orig-name)
                              initform))))

(defun %js-lower-class-private-method-inits (private-method-slots super-expr)
  "Lower PRIVATE-METHOD-SLOTS to (%js-class-private-field-set this \"name\" fn)
forms, to prepend to the constructor body alongside %JS-LOWER-CLASS-FIELD-
INITS's field inits. A #name() method is stored in the SAME per-instance
__private__ table a #name field would use, so this.#name() (which reads via
%js-class-private-field-get) actually finds it -- unlike a public method,
which lives on __prototype__ and is shared, a private method's closure is
rebuilt once per instance here, matching how field inits already work."
  (loop for slot in private-method-slots
        for orig-name = (%js-class-member-orig-name slot)
        for fn = (%js-wrap-method-super (%js-slot-to-method-lambda slot) super-expr)
        when fn
          collect (%js-call '%js-class-private-field-set
                             (make-ast-var :name '%js-this)
                             (make-ast-quote :value orig-name)
                             fn)))

(defun %js-lower-class-ctor (ctor-slot field-inits super-expr)
  "Build the class's constructor lambda: an explicit ctor gets FIELD-INITS
prepended; a class with fields but no explicit ctor gets a synthetic one
(forwarding to super for a derived class so the parent still initializes)."
  (cond
    (ctor-slot
      (let ((lam (%js-slot-to-method-lambda ctor-slot)))
        (when field-inits
          (setf (ast-lambda-body lam) (append field-inits (ast-lambda-body lam))))
        (%js-wrap-method-super lam super-expr)))
    (field-inits
      (make-ast-lambda
        :params
        nil
        :rest-param
        (when super-expr
          'js-ctor-rest-args)
        :body
        (append
          (when super-expr
            (list
              (%js-call
                '%js-run-constructor
                (%js-super-ref super-expr)
                (make-ast-var :name '%js-this)
                (make-ast-var :name 'js-ctor-rest-args))))
          field-inits)))
    (t (make-ast-quote :value nil))))

(defun %js-lower-class-method-args (method-slots super-expr)
  "Instance method args for %js-make-class: (\"name1\" fn1 \"name2\" fn2 ...)."
  (loop for slot in method-slots
        for orig-name = (%js-class-member-orig-name slot)
        for fn = (%js-wrap-method-super (%js-slot-to-method-lambda slot) super-expr)
        when fn
          append (list (%js-class-member-key-ast slot orig-name) fn)))

(defun %js-lower-class-static-args (static-slots)
  "(name1 fn1 name2 fn2 ...) pairs for %js-make-class, built the same way
regardless of whether STATIC-SLOTS are public or private static methods --
%js-lower-class-to-ast calls this twice, once for each, and the CALLER
decides where the result lands (after \"@@static\" for public, after the
further \"@@private-static\" marker for private)."
  (loop for slot in static-slots
        for orig-name = (%js-class-member-orig-name slot)
        for fn = (%js-slot-to-method-lambda slot)
        when fn
          append (list (%js-class-member-key-ast slot orig-name) fn)))

(defun %js-lower-class-static-field-args (static-field-slots)
  "Static field args (name value ...) for %js-make-class, set on the class
object alongside the static methods via the same \"@@static\" marker."
  (loop for slot in static-field-slots
        for orig-name = (%js-class-member-orig-name slot)
        append (list
      (%js-class-member-key-ast slot orig-name)
      (or (ast-slot-initform slot) (make-ast-quote :value +js-undefined+)))))

(defun %js-lower-class-make-class-call
    (super-expr ctor-lambda method-args static-args static-field-args private-static-args)
  "The %js-make-class call itself: super ctor inst-methods...
[@@static statics... [@@private-static private-statics...]]. The
\"@@private-static\" marker (and everything after \"@@static\") is only
emitted when PRIVATE-STATIC-ARGS is non-empty, since %js-make-class's own
marker search only looks for it within whatever follows \"@@static\" --
so \"@@static\" itself must be present whenever private static methods are,
even if there are no ordinary static methods/fields to go with it."
  (make-ast-call
    :func
    (make-ast-var :name '%js-make-class)
    :args
    (list*
      (or super-expr (make-ast-quote :value nil))
      ctor-lambda
      (append
        method-args
        (when (or static-args static-field-args private-static-args)
          (append
            (list (make-ast-quote :value "@@static"))
            static-args
            static-field-args
            (when private-static-args
              (cons (make-ast-quote :value "@@private-static") private-static-args))))))))

;;; ─── %js-lower-class-to-ast ──────────────────────────────────────────────────
(defun %js-lower-class-to-ast (name-sym super-expr members decorators)
  "Lower a parsed class to a prototype-based JS class using %js-make-class.
Emits: (defvar ClassName (%js-make-class SuperOrNil CtorOrNil 'method1 fn1 ...))

NAME-SYM   — symbol or NIL for anonymous class expressions
SUPER-EXPR — AST node for the superclass or NIL
MEMBERS    — list of ast-slot-def nodes from %js-parse-class-body
DECORATORS — list of AST nodes for class-level decorators"
  (declare (ignore decorators))
  (let* ((effective-name (or name-sym (gensym "JS-CLASS-")))
         (field-slots (%js-class-field-slots members))
         (field-inits (append (%js-lower-class-field-inits field-slots)
                               (%js-lower-class-private-method-inits
                                (%js-class-private-method-slots members) super-expr)))
         (ctor-lambda (%js-lower-class-ctor (%js-class-ctor-slot members) field-inits super-expr))
         (method-args (%js-lower-class-method-args (%js-class-method-slots members) super-expr))
         (static-args (%js-lower-class-static-args (%js-class-static-slots members)))
         (static-field-args (%js-lower-class-static-field-args
                              (%js-class-static-field-slots members)))
         (private-static-args (%js-lower-class-static-args
                                (%js-class-private-static-method-slots members)))
         (make-class-call (%js-lower-class-make-class-call
                            super-expr ctor-lambda method-args static-args
                            static-field-args private-static-args))
         ;; Single primary ast-defclass node — carries full semantic info for
         ;; tools/tests AND encodes the runtime implementation. :php-kind
         ;; :javascript tells codegen-clos to compile the :metaclass make-class-call
         ;; (which now includes statics, so no separate set-prop bindings are
         ;; needed and the lowering yields exactly one top-level node).
         (class-node
          (make-ast-defclass
           :name effective-name
           :superclasses (when (and super-expr (ast-var-p super-expr))
                           (list (ast-var-name super-expr)))
           :slots members
           :php-kind :javascript
           :metaclass make-class-call)))
    (list class-node)))

;;; ─── js-parse-class-decl (public entry point) ───────────────────────────────
(defun js-parse-class-decl (stream &key expression-p decorators)
  "Parse class [Name] [extends Super] { body }.

EXPRESSION-P — when T, the class keyword was consumed as part of an expression
               context; NAME is optional.
DECORATORS   — list of decorator AST nodes collected before the class keyword.

Returns (values ast-list rest) where AST-LIST is a list of AST nodes produced
by %js-lower-class-to-ast."
  ;; The 'class' keyword has already been consumed by the caller.
  (let ((current stream)
        (class-name nil)
        (super-expr nil))
    ;; Optional class name: present in declarations, optional in expressions
    (when (eq (js-peek-type current) :T-IDENT)
      (multiple-value-bind (tok rest) (js-consume current)
        (setf class-name (js-ident-sym (js-tok-value tok))
              current rest)))
    (unless (or expression-p class-name)
      (error "JS parse error: class declaration requires a name"))
    ;; Optional: extends SuperClass
    (when (and current (eq (js-peek-type current) :T-EXTENDS))
      (setf current (cdr current))   ; consume 'extends'
      ;; Parse super-class reference (simple identifier or member expression)
      (multiple-value-bind (tok rest) (js-expect :T-IDENT current)
        (setf super-expr (make-ast-var :name (js-ident-sym (js-tok-value tok)))
              current rest)
        ;; Walk optional .Member access on super expression
        (loop while (and current (eq (js-peek-type current) :T-DOT))
              do (setf current (cdr current))   ; consume '.'
              (multiple-value-bind (mem-tok rest2) (js-expect :T-IDENT current)
                (setf super-expr
                      (make-ast-call
                       :func (make-ast-var :name (js-ident-sym "%JS-GET-PROP"))
                       :args (list super-expr
                                   (make-ast-quote
                                    :value (js-tok-value mem-tok))))
                      current rest2)))))
    ;; Class body
    (multiple-value-bind (members rest) (%js-parse-class-body current class-name)
      (values (%js-lower-class-to-ast class-name super-expr members decorators)
              rest))))
