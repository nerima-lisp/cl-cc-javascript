;;;; packages/javascript/src/parser-class-lower-classify.lisp — JS class member
;;;; classification for AST lowering.
;;;;
;;;; Split out of parser-class-lower.lisp (which grew past the 300-line file
;;;; guideline): shared slot/key accessor helpers, and the predicates that
;;;; partition a parsed class's MEMBERS list by role (constructor, public/
;;;; private instance methods, public/private static methods, static fields,
;;;; instance fields) before any of it gets lowered. No function here builds
;;;; an %js-make-class argument -- that's parser-class-lower.lisp's job; this
;;;; file only answers "which slot is this."
;;;; Load order: after parser-class.lisp (needs %js-parse-class-body's slot
;;;; shape), before parser-class-lower.lisp (which calls these predicates).
(in-package :cl-cc/javascript)

;;; ─── slot/key accessor helpers ───────────────────────────────────────────────
;;; Accessor shorthands — ast-slot-def uses (:conc-name ast-slot-) so slots
;;; are read as ast-slot-NAME, but :imports is inherited from ast-node which
;;; uses (:conc-name ast-) and is therefore read as ast-imports.
(defun %js-slot-method-p (slot)
  "True when SLOT is an instance method (initform is ast-defun/lambda, not a field)."
  (and
    slot
    (ast-slot-def-p slot)
    (or
      (ast-defun-p (ast-slot-initform slot))
      (ast-lambda-p (ast-slot-initform slot)))
    (not (member :field (ast-imports slot)))))

(defun %js-slot-to-method-lambda (slot)
  "Convert a method slot's initform to an ast-lambda for %js-make-class."
  (let ((fn (ast-slot-initform slot)))
    (cond
      ((ast-lambda-p fn) fn)
      ((ast-defun-p fn)
        (make-ast-lambda :params (ast-defun-params fn) :body (ast-defun-body fn)))
      (t nil))))

(defun %js-super-ref (super-expr)
  "A FRESH reference to SUPER-EXPR for embedding inside a method/constructor body,
so the super-class AST node is not shared between the %js-make-class call and each
wrapped body."
  (if (ast-var-p super-expr) (make-ast-var :name (ast-var-name super-expr))
    super-expr))

(defun %js-wrap-method-super (lambda-ast super-expr)
  "When the class has a SUPER-EXPR, wrap LAMBDA-AST's body in a let binding %js-super
to a super-binding built from the (lexical) super class and the current this, so
super(args) calls the parent constructor.  Mutates LAMBDA-AST in place (preserving
its params/optional/rest) and returns it."
  (when (and lambda-ast (ast-lambda-p lambda-ast) super-expr)
    (setf (ast-lambda-body lambda-ast) (list
        (make-ast-let
          :bindings
          (list
            (cons
              '%js-super
              (%js-call
                '%js-make-super-binding
                (%js-super-ref super-expr)
                (make-ast-var :name '%js-this))))
          :declarations
          (list :let)
          :body
          (ast-lambda-body lambda-ast)))))
  lambda-ast)

(defun %js-class-member-key (slot orig-name)
  "Prototype/class key for a class member.  A get/set accessor is stored under
__get_NAME / __set_NAME so %js-get-prop / %js-set-prop dispatch it as an
accessor (invoke on read/write); a regular method keeps its plain name.  Without
this, `get v()' was stored as a plain prototype method, so `obj.v' returned the
getter FUNCTION instead of its result."
  (case (getf (ast-imports slot) :js-member-kind)
    (:getter (concatenate 'string "__get_" orig-name))
    (:setter (concatenate 'string "__set_" orig-name))
    (t orig-name)))

(defun %js-class-member-key-ast (slot orig-name)
  "AST node that EVALUATES to SLOT's prototype/class key at runtime.

A static (non-computed) name is the compile-time fast path: an ast-quote of
%JS-CLASS-MEMBER-KEY's string, same as before.

A computed name (`class C { [expr]() {} }') carries its real key expression
in SLOT's :js-computed-key-ast import (see %js-parse-class-method-member /
%js-parse-class-field-member / %js-parse-accessor).  That expression is
lowered to a runtime call to %JS-TO-PROPERTY-KEY -- the exact normalization
%js-get-prop / %js-set-prop already apply to a bracketed member access
(obj[expr]), so a computed method/field definition and a later read/write of
that same computed key resolve to the identical prototype/class slot.  A
computed getter/setter additionally needs the __get_/__set_ prefix applied
at runtime (the key isn't known until then), via %JS-CLASS-ACCESSOR-KEY."
  (let ((computed-ast (getf (ast-imports slot) :js-computed-key-ast)))
    (if computed-ast (case (getf (ast-imports slot) :js-member-kind)
        (:getter
          (%js-call '%js-class-accessor-key (make-ast-quote :value "__get_") computed-ast))
        (:setter
          (%js-call '%js-class-accessor-key (make-ast-quote :value "__set_") computed-ast))
        (t (%js-call '%js-to-property-key computed-ast)))
      (make-ast-quote :value (%js-class-member-key slot orig-name)))))

;;; ─── member classification ───────────────────────────────────────────────────
;;;
;;; A class's parsed MEMBERS list holds every slot (constructor, instance
;;; methods, static methods, static fields, instance fields) undifferentiated;
;;; these predicates partition it by role before any of it gets lowered.
(defun %js-class-member-orig-name (slot)
  "SLOT's original (pre-mangling) JS member name, as a string."
  (or
    (getf (ast-imports slot) :js-orig-name)
    (let ((n (ast-slot-name slot)))
      (if n (string-downcase (symbol-name n))
        ""))))

(defun %js-class-ctor-slot (members)
  "The constructor slot in MEMBERS, or NIL if the class declares none."
  (find-if
    (lambda (s)
      (and
        (ast-slot-def-p s)
        (let ((n (ast-slot-name s)))
          (and n (string-equal (symbol-name n) "CONSTRUCTOR")))))
    members))

(defun %js-class-method-slots (members)
  "Public instance methods in MEMBERS: non-constructor, non-static, non-field,
non-private. Private methods (%JS-CLASS-PRIVATE-METHOD-SLOTS) go through a
separate lowering path -- registering them here too would put a #name method
on __prototype__ under its ORIG-NAME, reachable via ordinary (public)
property access and defeating the whole point of the # syntax."
  (remove-if
    (lambda (s)
      (or
        (not (%js-slot-method-p s))
        (getf (ast-imports s) :js-static)
        (getf (ast-imports s) :js-private)
        (and
          (ast-slot-name s)
          (string-equal (symbol-name (ast-slot-name s)) "CONSTRUCTOR"))))
    members))

(defun %js-class-private-method-slots (members)
  "Private instance methods in MEMBERS: non-static #name(){...}."
  (remove-if-not
    (lambda (s)
      (and (%js-slot-method-p s)
           (not (getf (ast-imports s) :js-static))
           (getf (ast-imports s) :js-private)))
    members))

(defun %js-class-static-slots (members)
  "Public static methods in MEMBERS. Private static methods
(%JS-CLASS-PRIVATE-STATIC-METHOD-SLOTS) go through a separate lowering path,
for the same reason %JS-CLASS-METHOD-SLOTS excludes private instance
methods -- registering one here too would make it an ordinary public
C.name, defeating the # syntax."
  (remove-if-not
    (lambda (s)
      (and (%js-slot-method-p s)
           (getf (ast-imports s) :js-static)
           (not (getf (ast-imports s) :js-private))))
    members))

(defun %js-class-private-static-method-slots (members)
  "Private static methods in MEMBERS: `static #name(){...}'."
  (remove-if-not
    (lambda (s)
      (and (%js-slot-method-p s)
           (getf (ast-imports s) :js-static)
           (getf (ast-imports s) :js-private)))
    members))

(defun %js-class-static-field-slots (members)
  "Static fields in MEMBERS: `static x = init;' — set once on the class
object. Also includes `static { ... }' initialisation blocks (:member-kind
:static-block) — they carry no real property value worth reading, but their
initform's SIDE EFFECTS only run at all if the block is included here; this
is the only place %js-lower-class-static-field-args's caller threads a
static member's initform into the class's %js-make-class call."
  (remove-if-not
    (lambda (s)
      (and
        (not (%js-slot-method-p s))
        (getf (ast-imports s) :js-static)
        (member (getf (ast-imports s) :js-member-kind) '(:field :static-block))))
    members))

(defun %js-class-field-slots (members)
  "Instance fields in MEMBERS: non-method, non-static `x = init;' / `x;'.
These initialize on every instance BEFORE the constructor body."
  (remove-if
    (lambda (s)
      (or
        (%js-slot-method-p s)
        (getf (ast-imports s) :js-static)
        (not (eq (getf (ast-imports s) :js-member-kind) :field))))
    members))
