;;;; packages/javascript/src/parser-expr-primary.lisp — Primary Expression Parsers
;;;;
;;;; Concrete primary expression forms: literals, identifiers, parenthesized
;;;; expressions, arrow functions, async/class/import expressions, and the
;;;; main Pratt entry points (js-parse-expr, js-parse-assignment-expr).
;;;;
;;;; Depends on parser-expr.lisp for Pratt precedence table, operator lowering,
;;;; parameter parsers, array/object literals, function expression, new/member,
;;;; postfix, template literal, and unary parsers.
;;;;
;;;; Load order: after parser-expr.lisp, before parser-stmt.lisp.

(in-package :cl-cc/javascript)

;;; ─── Primary Expression ──────────────────────────────────────────────────────

;;; Data table: token type -> zero-arg AST builder, for primary tokens that
;;; consume exactly one token and always build the same fixed AST node
;;; (booleans, null, undefined, this, super). Mirrors *js-unary-kw-builders*
;;; in parser-expr-unary.lisp — same "consume one token, apply BUILDER" shape,
;;; just with no sub-expression to recurse into.
(define-builder-table *js-primary-constant-builders*
    (:test #'eq :documentation "Data table: keyword primary token type -> zero-arg AST builder.")
  (:T-TRUE  (lambda () (make-ast-quote :value t)))
  (:T-FALSE (lambda () (make-ast-quote :value nil)))
  ;; null literal. The runtime null sentinel is +js-null+ (= :js-null); this
  ;; MUST match it, not the bare :null keyword — otherwise %js-to-string
  ;; prints "NULL" and %js-not-nullish treats `null' as non-nullish (null ??
  ;; x broke). (+js-null+ itself can't be named here: this file compiles
  ;; before runtime.)
  (:T-NULL      (lambda () (make-ast-quote :value :js-null)))
  ;; undefined — likewise the +js-undefined+ sentinel (= :js-undefined)
  (:T-UNDEFINED (lambda () (make-ast-quote :value :js-undefined)))
  (:T-THIS      (lambda () (make-ast-var :name '%js-this)))
  (:T-SUPER     (lambda () (make-ast-var :name '%js-super))))

(defun js-parse-primary (stream)
  "Parse a primary expression. Returns (values ast rest).
Handles: numbers, strings, booleans, null, undefined, this, super,
identifiers, parenthesized expressions, array literals [...],
object literals {...}, function expressions, async functions,
generator functions, class expressions, new expr, template literals,
yield, await, import()."
  (let ((type (js-peek-type stream))
        (val  (js-peek-value stream)))
    ;; CPS helper: consume one token, discard it, apply zero-arg BUILDER.
    (labels ((consume-and-build (builder)
               (%js-consume-then (rest (js-consume stream))
                 (values (funcall builder) rest))))
    (case type
      ;; Numeric literal (integer or float)
      (:T-NUMBER
       (multiple-value-bind (tok rest) (js-consume stream)
         (let ((v (js-tok-value tok)))
           (if (integerp v)
               (values (make-ast-int :value v) rest)
               (values (make-ast-quote :value v) rest)))))
      ;; BigInt literal
      (:T-BIGINT
       (multiple-value-bind (tok rest) (js-consume stream)
         (values (make-ast-int :value (js-tok-value tok)) rest)))
      ;; String literal
      (:T-STRING
       (multiple-value-bind (tok rest) (js-consume stream)
         (values (make-ast-quote :value (js-tok-value tok)) rest)))
      ;; Regex literal — token value is (:regex pattern-string flags-string);
      ;; %js-make-regex takes (pattern &optional flags) as separate strings.
      (:T-REGEX
       (multiple-value-bind (tok rest) (js-consume stream)
         (let ((v (js-tok-value tok)))
           (values (%js-call '%js-make-regex
                             (make-ast-quote :value (second v))
                             (make-ast-quote :value (third v)))
                   rest))))
      ;; Template literal
      ((:T-TEMPLATE-START :T-TEMPLATE-PARTS)
       (%js-parse-template-literal stream))
      ;; Table-driven: booleans, null, undefined, this, super — each just
      ;; consumes its one token and builds a fixed AST node.
      ((:T-TRUE :T-FALSE :T-NULL :T-UNDEFINED :T-THIS :T-SUPER)
       (consume-and-build (gethash type *js-primary-constant-builders*)))
      ;; Array literal [...]
      (:T-LBRACKET
       (js-parse-array-literal stream))
      ;; Object literal {...}
      (:T-LBRACE
       (js-parse-object-literal stream))
      ;; Parenthesized expression or arrow function params
      (:T-LPAREN
       (%js-parse-paren-or-arrow stream))
      ;; function expression
      (:T-FUNCTION
       (%js-consume-then (rest (js-consume stream))
         (js-parse-function-expr rest)))
      ;; async function / async arrow
      (:T-ASYNC
       (%js-parse-async-expr stream))
      ;; class expression
      (:T-CLASS
       (%js-parse-class-expr stream))
      ;; new expression (including new.target)
      (:T-NEW
       (js-parse-new-expr stream))
      ;; import() dynamic import
      (:T-IMPORT
       (%js-parse-import-expr stream))
      ;; yield as expression (when used as identifier-like)
      (:T-YIELD
       (%js-parse-yield-expr stream))
      ;; await as expression
      (:T-AWAIT
       (%js-consume-then (rest (js-consume stream))
         (multiple-value-bind (expr rest2) (js-parse-unary rest)
           (values (%js-call '%js-await expr) rest2))))
      ;; Identifier — may begin a single-parameter arrow function: x => body
      (:T-IDENT
       (%js-consume-then (rest (js-consume stream))
         (if (eq (js-peek-type rest) :T-ARROW)
             (%js-finish-arrow-function (list (js-ident-sym val)) rest)
             (values (make-ast-var :name (js-ident-sym val)) rest))))
      ;; Private field identifier #name — as standalone (for #name in obj)
      (:T-PRIVATE-IDENT
       (%js-consume-then (rest (js-consume stream))
         (values (make-ast-var :name (js-ident-sym (concatenate 'string "#" val))) rest)))
      (t
       ;; Contextual keywords used as identifiers (get, set, from, as, of,
       ;; target, meta, using, static) — a CASE clause's keys must be a
       ;; literal list, so this membership test (against the table shared
       ;; with parser-stmt-binding.lisp) lives here instead of as a clause key.
       (if (member type *js-contextual-keyword-token-types* :test #'eq)
           (%js-consume-then (rest (js-consume stream))
             (values (make-ast-var :name (js-ident-sym val)) rest))
           (error "JS parse error: unexpected token ~S in expression" (js-peek stream))))))))


;;; Arrow/paren/async/class/import expression helpers → see parser-arrow.lisp
;;; Main Pratt parser → see below (js-parse-expr, js-parse-assignment-expr)
;;; ─── Main Pratt Parser ───────────────────────────────────────────────────────

(defun js-parse-expr (stream &optional (min-prec 0))
  "Main Pratt expression parser. Returns (values ast rest).
Handles all infix operators at precedence >= MIN-PREC including
assignment (right-assoc), ternary, binary ops, and comma."
  (with-js-parse-depth
  (multiple-value-bind (lhs rest) (js-parse-unary stream)
    (loop
      (multiple-value-bind (prec right-assoc-p) (js-infix-prec rest)
        (when (<= prec min-prec)
          (return))
        (let ((op-type  (js-peek-type rest))
              (op-val   (js-peek-value rest)))
          (cond
            ;; Ternary: ? then : else
            ((eq op-type :T-QUESTION)
             (%js-consume-then (rest2 (js-consume rest))
               (multiple-value-bind (then-ast rest3) (js-parse-assignment-expr rest2)
                 (%js-consume-then (rest4 (js-expect :T-COLON rest3))
                   (multiple-value-bind (else-ast rest5) (js-parse-assignment-expr rest4)
                     ;; Coerce the condition to a JS boolean (%js-truthy), like the
                     ;; if/while/for statements do — otherwise "", null, undefined
                     ;; and NaN (all non-nil values) test as truthy in `c ? a : b'.
                     (setf lhs (make-ast-if :cond (%js-truthy-call lhs)
                                            :then then-ast :else else-ast)
                           rest rest5))))))
            ;; Comma operator
            ((eq op-type :T-COMMA)
             (when (> prec min-prec)
               (%js-consume-then (rest2 (js-consume rest))
                 (multiple-value-bind (rhs rest3) (js-parse-expr rest2 1)
                   (setf lhs (make-ast-progn :forms (list lhs rhs))
                         rest rest3)))))
            ;; Assignment operators (right-associative)
            ((and (eq op-type :T-OP)
                  (member op-val *js-assignment-op-strings* :test #'string=))
             ;; Only assign if prec > min-prec (for right-assoc, use >= on rhs)
             (when (> prec min-prec)
               (%js-consume-then (rest2 (js-consume rest))
                 (multiple-value-bind (rhs rest3)
                     (js-parse-expr rest2 (if right-assoc-p (1- prec) prec))
                   (setf lhs (%js-lower-assignment op-val lhs rhs)
                         rest rest3)))))
            ;; instanceof / in (keyword tokens, not :T-OP)
            ((or (eq op-type :T-INSTANCEOF) (eq op-type :T-IN))
             (%js-consume-then (rest2 (js-consume rest))
               (let ((next-prec (if right-assoc-p (1- prec) prec)))
                 (multiple-value-bind (rhs rest3) (js-parse-expr rest2 next-prec)
                   (setf lhs (%js-lower-binary op-val lhs rhs)
                         rest rest3)))))
            ;; All other binary operators
            (t
             (%js-consume-then (rest2 (js-consume rest))
               (let ((next-prec (if right-assoc-p (1- prec) prec)))
                 (multiple-value-bind (rhs rest3) (js-parse-expr rest2 next-prec)
                   (setf lhs (%js-lower-binary op-val lhs rhs)
                         rest rest3)))))))))
    (values lhs rest))))

(defun %js-lower-assignment (op-val lhs rhs)
  "Lower an assignment expression LHS op RHS to the appropriate AST."
  (cond
    ;; Simple variable assignment
    ((ast-var-p lhs)
     (let ((var-sym (ast-var-name lhs)))
       (cond
         ((string= op-val "=")
          (make-ast-setq :var var-sym :value rhs))
         ;; Logical assign
         ((assoc op-val *js-logical-assign-ops* :test #'string=)
          (%js-lower-logical-assign op-val var-sym rhs))
         ;; Compound assign
         (t
          (make-ast-setq :var var-sym
                         :value (%js-compound-rhs op-val lhs rhs))))))
    ;; Property assignment: obj.prop = val or obj[key] = val
    ((and (ast-call-p lhs)
          (ast-var-p (ast-call-func lhs))
          (eq (ast-var-name (ast-call-func lhs)) '%js-get-prop))
     (let ((obj (first  (ast-call-args lhs)))
           (key (second (ast-call-args lhs))))
       (cond
         ((string= op-val "=")
          (%js-call '%js-set-prop obj key rhs))
         (t
          ;; Compound prop assign: obj.k op= rhs → obj.k = (obj.k op rhs)
          (let ((obj-tmp (gensym "JS-OBJ-"))
                (key-tmp (gensym "JS-KEY-")))
            (make-ast-let
             :bindings (list (cons obj-tmp obj) (cons key-tmp key))
             :body (list (%js-call '%js-set-prop
                                   (make-ast-var :name obj-tmp)
                                   (make-ast-var :name key-tmp)
                                   (%js-compound-rhs op-val lhs rhs)))))))))
    ;; Private field assignment
    ((and (ast-call-p lhs)
          (ast-var-p (ast-call-func lhs))
          (eq (ast-var-name (ast-call-func lhs)) '%js-class-private-field-get))
     (let ((obj (first  (ast-call-args lhs)))
           (key (second (ast-call-args lhs))))
       (%js-call '%js-class-private-field-set obj key rhs)))
    ;; Destructuring assignment (array or object pattern) — lower to runtime helper
    (t
     (%js-call '%js-assign-pattern lhs rhs))))

(defun js-parse-assignment-expr (stream)
  "Like js-parse-expr but stops at comma (min-prec = 2).
Use for function arguments and array/object elements."
  (js-parse-expr stream 2))

;;; ─── Entry Point Helpers ─────────────────────────────────────────────────────

