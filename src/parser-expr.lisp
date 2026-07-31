;;;; packages/javascript/src/parser-expr.lisp — ES2026 JavaScript Expression Parser
;;;;
;;;; Pratt (top-down operator precedence) expression parser for JavaScript.
;;;;
;;;; Token stream is a list of token plists: (:type :T-XXX :value val).
;;;; All parsers return (values ast remaining-stream).
;;;;
;;;; Depends on lexer.lisp for token types and tokenize-js-source.
;;;; Load order: after lexer.lisp, before any statement parser.

(in-package :cl-cc/javascript)

;;; ─── Pratt Precedence Table ──────────────────────────────────────────────────
;;;
;;; Data table for operator string → (prec right-assoc-p).
;;; Type-keyed specials (comma, ternary, instanceof, in, member) remain in the
;;; dispatch function since they match on token type, not string value.

(defparameter *js-assignment-op-strings*
  '("=" "+=" "-=" "*=" "/=" "%=" "**="
    "<<=" ">>=" ">>>=" "&=" "|=" "^="
    "&&=" "||=" "??=")
  "Every JS assignment operator string, shared with parser-expr-primary.lisp's
js-parse-expr (which needs the same set to recognize an assignment RHS)
so the two can't silently drift apart.")

(define-builder-table *js-op-infix-prec*
    (;; Assignment operators are all right-associative at precedence 2; they
     ;; are seeded from *js-assignment-op-strings* rather than re-listed so
     ;; the two definitions cannot drift apart.
     :seed (mapcar (lambda (op) (cons op '(2 t))) *js-assignment-op-strings*)
     :documentation
     "Maps JS operator strings to (prec right-assoc-p). Used by js-infix-prec.")
  ;; Remaining binary ops (left-associative unless noted)
  ("??"  '(5 nil))   ("||"  '(6 nil))   ("&&"  '(7 nil))
  ("|"   '(8 nil))   ("^"   '(9 nil))   ("&"   '(10 nil))
  ("=="  '(11 nil))  ("!="  '(11 nil))  ("===" '(11 nil))  ("!==" '(11 nil))
  ("<"   '(12 nil))  (">"   '(12 nil))  ("<="  '(12 nil))  (">="  '(12 nil))
  ("<<"  '(13 nil))  (">>"  '(13 nil))  (">>>" '(13 nil))
  ("+"   '(14 nil))  ("-"   '(14 nil))
  ("*"   '(15 nil))  ("/"   '(15 nil))  ("%"   '(15 nil))
  ("**"  '(16 t))    ("?."  '(19 nil)))

(defun js-infix-prec (stream)
  "Return (values prec right-assoc-p) for current token as infix op, or (values 0 nil).

Precedence levels: 1=comma 2=assign 4=ternary 5=?? 6=|| 7=&& 8=| 9=^ 10=&
  11=equality 12=relational 13=shift 14=additive 15=multiplicative 16=** 19=member"
  (let ((type (js-peek-type stream))
        (val  (js-peek-value stream)))
    (cond
      ((eq type :T-COMMA)    (values 1 nil))
      ((eq type :T-QUESTION) (values 4 nil))
      ((or (eq type :T-INSTANCEOF) (eq type :T-IN)) (values 12 nil))
      ((or (eq type :T-DOT) (eq type :T-LBRACKET) (eq type :T-LPAREN)) (values 19 nil))
      ((eq type :T-OP)
       (let ((entry (gethash val *js-op-infix-prec*)))
         (if entry (values (first entry) (second entry)) (values 0 nil))))
      (t (values 0 nil)))))

;;; ─── Operator Lowering ───────────────────────────────────────────────────────

(define-builder-table *js-direct-binop-keywords*
    (:documentation
     "Maps arithmetic operator strings to AST binop operator symbols.")
    ;; Values are the operator SYMBOLS the codegen op→constructor table
    ;; (*numeric-binop-ctor-specs*, keyed by symbol with :test #'eq) expects:
    ;; CL +,-,*,/,<,>,<=,>=. They were keywords (:+, :-, …) which never matched,
    ;; so `a + b' raised `Unknown binary operator :+', the enclosing form/function
    ;; body failed to compile, and was silently dropped — every JS program using
    ;; arithmetic broke. `%' and `**' have no direct VM constructor; they fall
    ;; through %js-lower-binary to the %js-binop runtime helper.
    ;; NOTE: `+' is intentionally NOT here — it is polymorphic in JS (numeric add
    ;; OR string concat) and routes through %js-add via *js-binop-runtime-helpers*.
    ;; `- * /' and comparisons are numeric-only and use the direct VM constructors.
    ;; `/' is NOT here — JS division must yield a float (5/2 => 2.5), but the VM
    ;; `/' returns the CL rational 5/2; it routes through %js-divide instead.
    ;; Comparisons (< > <= >=) are NOT here: lowering them to the VM's CL
    ;; comparison returns 1/0 (not a JS boolean) and ignores JS relational
    ;; semantics (string compare, NaN-always-false, ToNumber coercion). They
    ;; route through %js-lt/gt/le/ge via *js-binop-runtime-helpers* instead.
  ("-" '-)
  ("*" '*))

(define-builder-table *js-binop-runtime-helpers*
    (:documentation
     "Maps operator strings to their CPS runtime helper symbols.")
  ("+"   '%js-add)          ("/"   '%js-divide)
  ("%"   '%js-mod)          ("**"  '%js-pow)
  ("===" '%js-strict-eq)    ("=="  '%js-loose-eq)
  ("<"   '%js-lt)           (">"   '%js-gt)
  ("<="  '%js-le)           (">="  '%js-ge)
  ("|"   '%js-bitwise-or)   ("^"   '%js-bitwise-xor)
  ("&"   '%js-bitwise-and)
  ("<<"  '%js-shift-left)   (">>"  '%js-shift-right)
  (">>>" '%js-unsigned-shift-right)
  ("instanceof" '%js-instanceof)  ("in" '%js-in))

(defun %js-call (name &rest args)
  "Build an AST call to a JS runtime helper NAME with ARGS."
  (make-ast-call :func (make-ast-var :name name)
                 :args args))

(defun %js-not (ast)
  "Build an AST call wrapping AST in CL NOT.  JS `!x', `a !== b' and `a != b'
all lower to the same `(not <boolean-producing-call>)' shape."
  (make-ast-call :func (make-ast-var :name 'not) :args (list ast)))

(define-builder-table *js-coercion-call-helpers*
    (:test 'eq
     :key js-ident-sym
     :documentation
     "Bare-call coercion builtins -> runtime helper symbols.  Number(x)/String(x)/
Boolean(x)/parseInt/parseFloat are called as functions, but the global holding
each is a value (not a callable function symbol the codegen can dispatch), so a
bare `Number(x)' raised `Undefined function: NUMBER'.  We lower the CALL directly
to the helper; `Number.isInteger' (member access) is unaffected.")
  ("Number"     '%js-to-number)
  ("String"     '%js-to-string)
  ("Boolean"    '%js-truthy)
  ("parseInt"   '%js-parse-int)
  ("parseFloat" '%js-parse-float)
  ;; Standalone global builtins whose prelude binding is a value, not a
  ;; callable function symbol — lower the direct call to the helper (the
  ;; global binding still serves indirect/value use).
  ("structuredClone" '%js-structured-clone)
  ("queueMicrotask"  '%js-queue-microtask)
  ;; Symbol(desc) constructs a symbol; Symbol.iterator (member access on the
  ;; global) is unaffected.
  ("Symbol" '%js-make-symbol)
  ;; BigInt(x) coerces; BigInt.asIntN/asUintN (member access on the global)
  ;; are unaffected — same shape as Symbol above.
  ("BigInt" '%js-bigint)
  ;; Other global functions whose prelude binding is a value (not a callable
  ;; symbol), so a bare call needs lowering.
  ("encodeURIComponent" '%js-encode-uri-component)
  ("decodeURIComponent" '%js-decode-uri-component)
  ("encodeURI" '%js-encode-uri)
  ("decodeURI" '%js-decode-uri)
  ("btoa"      '%js-btoa)
  ("atob"      '%js-atob)
  ("isNaN"     '%js-is-nan)
  ("isFinite"  '%js-is-finite))

(defun %js-lower-coercion-call (helper args)
  "Lower a coercion builtin CALL to its HELPER. parseInt/parseFloat take the args
as-is (s, radix); Number/String/Boolean take one argument, with the JS empty-call
defaults Number()=0, String()=\"\", Boolean()=false."
  (cond
    ((member helper '(%js-parse-int %js-parse-float
                      %js-structured-clone %js-queue-microtask
                      %js-make-symbol %js-bigint
                      %js-encode-uri-component %js-decode-uri-component
                      %js-encode-uri %js-decode-uri %js-btoa %js-atob
                      %js-is-nan %js-is-finite))
     (apply #'%js-call helper args))
    ((null args)
     (case helper
       (%js-to-number (make-ast-int :value 0))
       (%js-to-string (make-ast-quote :value ""))
       (t             (make-ast-quote :value nil))))
    (t (%js-call helper (first args)))))

(defun %js-spread-marker-p (node)
  "True when NODE is a (%js-spread expr) marker produced for ...expr."
  (and (ast-call-p node)
       (let ((f (ast-call-func node)))
         (and (ast-var-p f) (eq (ast-var-name f) '%js-spread)))))

(defun %js-items-have-spread-p (items)
  "True when ITEMS contains a ...expr spread marker."
  (some #'%js-spread-marker-p items))

(defun %js-spread-list-expr (items)
  "Build a runtime list expression that flattens ITEMS: each (%js-spread expr)
marker contributes its values (%js-spread already returns a CL list) and each
regular item contributes a one-element list, appended together. Used to expand
spread in array literals and call arguments via apply."
  (make-ast-call
   :func (make-ast-var :name 'append)
   :args (mapcar (lambda (it)
                   (if (%js-spread-marker-p it)
                       it
                       (make-ast-call :func (make-ast-var :name 'list) :args (list it))))
                 items)))

(defun %js-lower-binary (op-str lhs rhs)
  "Lower a binary operator string + lhs + rhs to the appropriate AST.
   Dispatch is data-driven via *js-direct-binop-keywords* and *js-binop-runtime-helpers*."
  (cond
    ;; Direct AST binop (arithmetic, comparison) — O(1) table lookup
    ((gethash op-str *js-direct-binop-keywords*)
     (make-ast-binop :op (gethash op-str *js-direct-binop-keywords*) :lhs lhs :rhs rhs))
    ;; Logical short-circuit operators. JS && / || yield an OPERAND (not a
    ;; boolean) and short-circuit, so they lower to let+if like ?? does — NOT to
    ;; an ast-binop :and/:or (which codegen cannot emit; the enclosing function
    ;; then failed to compile and was silently dropped — "Undefined function").
    ((string= op-str "||") (%js-lower-logical-or  lhs rhs))
    ((string= op-str "&&") (%js-lower-logical-and lhs rhs))
    ((string= op-str "??") (%js-lower-nullish-coalesce lhs rhs))
    ;; Negated equality — wrap in NOT
    ((string= op-str "!==") (%js-not (%js-call '%js-strict-eq lhs rhs)))
    ((string= op-str "!=")  (%js-not (%js-call '%js-loose-eq  lhs rhs)))
    ;; Runtime helpers — O(1) table lookup
    ((gethash op-str *js-binop-runtime-helpers*)
     (%js-call (gethash op-str *js-binop-runtime-helpers*) lhs rhs))
    ;; Fallback: runtime dispatch
    (t (%js-call '%js-binop (make-ast-quote :value (intern op-str :keyword)) lhs rhs))))

(defun %js-lower-short-circuit (gensym-prefix test-helper lhs rhs var-on-true-p)
  "Shared shape behind ??/&&/||: evaluate LHS once into a temporary, test it
via TEST-HELPER, and return the temporary on the branch VAR-ON-TRUE-P says to
(T = when the test is true, NIL = when it's false), RHS on the other branch."
  (let ((tmp (gensym gensym-prefix)))
    (make-ast-let
     :bindings (list (cons tmp lhs))
     :body (list (make-ast-if
                  :cond (%js-call test-helper (make-ast-var :name tmp))
                  :then (if var-on-true-p (make-ast-var :name tmp) rhs)
                  :else (if var-on-true-p rhs (make-ast-var :name tmp)))))))

(defun %js-lower-nullish-coalesce (lhs rhs)
  "Lower LHS ?? RHS without evaluating LHS twice."
  (%js-lower-short-circuit "JS-NC-" '%js-not-nullish lhs rhs t))

(defun %js-lower-logical-and (lhs rhs)
  "Lower LHS && RHS: evaluate LHS once; if it is JS-truthy the result is RHS,
otherwise the result is LHS itself (so `0 && x' -> 0, `a && b' -> b)."
  (%js-lower-short-circuit "JS-AND-" '%js-truthy lhs rhs nil))

(defun %js-lower-logical-or (lhs rhs)
  "Lower LHS || RHS: evaluate LHS once; if it is JS-truthy the result is LHS,
otherwise the result is RHS (so `3 || x' -> 3, `0 || b' -> b)."
  (%js-lower-short-circuit "JS-OR-" '%js-truthy lhs rhs t))

(defparameter *js-logical-assign-ops*
  '(("&&=" . :truthy) ("||=" . :falsy) ("??=" . :non-null))
  "Every JS logical-assignment operator string mapped to its short-circuit
semantics, shared with parser-expr-primary.lisp's %js-lower-assignment (which
needs the same set to recognize a logical assignment) so the two can't
silently drift apart.")

(defun %js-logical-assign-short-circuit-p (op-str)
  "Return :truthy for &&=, :falsy for ||=, :non-null for ??="
  (or (cdr (assoc op-str *js-logical-assign-ops* :test #'string=))
      (error "JS parse error: unknown logical assign op ~S" op-str)))

(defun %js-lower-logical-assign (op-str lhs-sym rhs)
  "Lower &&= ||= ??= compound logical assignment on a variable.
   CPS-style: dispatches through %js-logical-assign-short-circuit-p to a uniform template."
  (let* ((lhs-var (make-ast-var :name lhs-sym))
         (kind    (%js-logical-assign-short-circuit-p op-str))
         (test    (ecase kind
                    (:truthy   (%js-call '%js-truthy lhs-var))
                    (:falsy    (%js-call '%js-truthy lhs-var))
                    (:non-null (%js-call '%js-not-nullish lhs-var))))
         (setq-ast    (make-ast-setq :var lhs-sym :value rhs)))
    (ecase kind
      (:truthy   (make-ast-if :cond test :then setq-ast    :else lhs-var))
      (:falsy    (make-ast-if :cond test :then lhs-var :else setq-ast))
      (:non-null (make-ast-if :cond test :then lhs-var :else setq-ast)))))

(defun %js-compound-rhs (op-str lhs-var rhs)
  "Compute the rhs value for compound assignment op like +=, -=, etc."
  (let ((plain (subseq op-str 0 (1- (length op-str))))) ; strip =
    (%js-lower-binary plain lhs-var rhs)))

;;; ─── Array / Object / Function-Expr Literals ───────────────────────────────
;;; js-parse-array-literal, %js-parse-object-property, js-parse-object-literal,
;;; js-parse-function-expr, and js-parse-function-body are in
;;; parser-expr-literal.lisp (loaded after this file).

;;; parser-expr-args.lisp owns js-parse-params and js-parse-arguments.

;;; parser-expr-postfix.lisp handles:
;;;   js-parse-new-expr, js-parse-member-expr, %js-place-get-prop-p,
;;;   %js-lower-place-incdec, js-parse-postfix, template-literal parsers,
;;;   js-parse-unary, %js-template-parts-and-rest, %js-parse-tagged-template,
;;;   %js-parse-template-literal
