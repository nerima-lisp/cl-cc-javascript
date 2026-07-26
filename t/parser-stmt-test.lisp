;;;; t/parser-stmt-test.lisp — JS parser: statements + expressions
;;;;
;;;; Covers: if/else, while, for loop variants, switch, try/catch/finally,
;;;;         destructuring, spread, optional chaining, nullish coalescing,
;;;;         logical assignment, template literals, import/export, using,
;;;;         throw, return, multi-statement, generators, for-of/in, new, unary.
;;;;
;;;; Depends on: parser-decl-test.lisp (%js-parse, %js-first, %js-call-name).

(in-package :cl-cc-javascript/test)

;;; ─── If / else ────────────────────────────────────────────────────────────────

(it-sequential "js-parser-if-stmt"
  (let ((ast (%js-first "if (x) { y; }")))
    (expect (cl-cc:ast-if-p ast) :to-be-truthy)))

(it-sequential "js-parser-if-else-stmt"
  (let ((ast (%js-first "if (a) { return 1; } else { return 2; }")))
    (expect (cl-cc:ast-if-p ast) :to-be-truthy)
    (expect (not (cl-cc:ast-quote-p (cl-cc:ast-if-else ast))) :to-be-truthy)))

;;; ─── While loop ───────────────────────────────────────────────────────────────

(it-sequential "js-parser-while-loop"
  (let ((ast (%js-first "while (x) { }")))
    (expect (cl-cc:ast-block-p ast) :to-be-truthy)
    (expect (some #'cl-cc:ast-tagbody-p (cl-cc:ast-block-body ast)) :to-be-truthy)))

;;; ─── For loop ─────────────────────────────────────────────────────────────────

(it-sequential-each (("for (let i = 0; i < 10; i++) { }")
                     ("for (const x of arr) { }")
                     ("for (const k in obj) { }"))
    "js-parser-for-loop-variants ~S"
    (src)
  (let ((ast (%js-first src)))
    (expect (or (cl-cc:ast-let-p ast) (cl-cc:ast-block-p ast)
                (cl-cc:ast-progn-p ast)) :to-be-truthy)))

;;; ─── Switch / case ────────────────────────────────────────────────────────────

(it-sequential "js-parser-switch-stmt"
  (let ((ast (%js-first "switch (x) { case 1: break; default: break; }")))
    (expect (cl-cc:ast-let-p ast) :to-be-truthy)
    (let ((block (first (cl-cc:ast-let-body ast))))
      (expect (cl-cc:ast-block-p block) :to-be-truthy))))

;;; ─── Try / catch / finally ────────────────────────────────────────────────────

(it-sequential-each (("try { throw 1; } catch (e) { }")
                     ("try { } finally { }")
                     ("try { throw 1; } catch (e) { } finally { }"))
    "js-parser-try-forms ~S"
    (src)
  (let ((ast (%js-first src)))
    (expect (cl-cc:ast-call-p ast) :to-be-truthy)
    (expect (%js-call-name ast) :to-equal "%JS-TRY-CATCH-FINALLY")))

;;; ─── Destructuring ────────────────────────────────────────────────────────────

(it-sequential-each (("const [a, b] = arr;")
                     ("const {x, y} = obj;")
                     ("const [a = 1, b = 2] = arr;")
                     ("const {a = 1} = obj;")
                     ("const {a: x = 5} = obj;")
                     ("const [x, y = 10, ...rest] = arr;"))
    "js-parser-destructuring ~S"
    (src)
  (let ((ast (%js-first src)))
    (expect (cl-cc:ast-let-p ast) :to-be-truthy)))

;;; ─── Spread operator ──────────────────────────────────────────────────────────

(it-sequential "js-parser-spread-in-array"
  (let ((ast (%js-first "const x = [...arr];")))
    (expect (cl-cc:ast-let-p ast) :to-be-truthy)
    (let ((val (cdr (first (cl-cc:ast-let-bindings ast)))))
      (expect (cl-cc:ast-apply-p val) :to-be-truthy))))

;;; ─── Optional chaining ────────────────────────────────────────────────────────

(it-sequential "js-parser-optional-chaining"
  (let* ((ast (%js-first "const r = a?.b;"))
         (val (cdr (first (cl-cc:ast-let-bindings ast)))))
    (expect (cl-cc:ast-call-p val) :to-be-truthy)
    (expect (%js-call-name val) :to-equal "%JS-OPTIONAL-CHAIN")))

;;; ─── Nullish coalescing ───────────────────────────────────────────────────────

(it-sequential "js-parser-nullish-coalescing"
  (let* ((ast (%js-first "const r = a ?? b;"))
         (val (cdr (first (cl-cc:ast-let-bindings ast)))))
    (expect (or (cl-cc:ast-let-p val) (cl-cc:ast-if-p val)
            (cl-cc:ast-call-p val)) :to-be-truthy)))

;;; ─── Logical assignment ───────────────────────────────────────────────────────

(it-sequential-each (("let x = 1;    x &&= 0;")
                     ("let x = null; x ||= 42;")
                     ("let x = null; x ??= 'default';"))
    "js-parser-logical-assignment ~S"
    (src)
  (let ((asts (%js-parse src)))
    (expect (= 1 (length asts)) :to-be-truthy)
    (expect (cl-cc:ast-let-p (first asts)) :to-be-truthy)))

;;; ─── Template literals ────────────────────────────────────────────────────────

(it-sequential-each (("const s = `hello`;")
                     ("const s = `hi ${name}!`;")
                     ("const s = `sum=${a + b * 2}`;"))
    "js-parser-template-literals ~S"
    (src)
  (let ((ast (%js-first src)))
    (expect (cl-cc:ast-let-p ast) :to-be-truthy)
    (expect (not (null (cdr (first (cl-cc:ast-let-bindings ast))))) :to-be-truthy)))

;;; ─── Import / export ──────────────────────────────────────────────────────────

(it-sequential "js-parser-import-statement"
  (let ((asts (cl-cc/javascript:parse-js-module "import x from 'mod';")))
    (expect (>= (length asts) 0) :to-be-truthy)))

(it-sequential-each (("import 'mod';" "%JS-IMPORT")
                     ("import 'mod' with { type: 'json' };" "%JS-IMPORT")
                     ("import { 'default' as def, foo } from 'mod';" "%JS-IMPORT")
                     ("import foo from 'mod';" "%JS-IMPORT")
                     ("import foo, * as ns from 'mod';" "%JS-IMPORT")
                     ("import foo, { bar as baz } from 'mod';" "%JS-IMPORT")
                     ("import { foo }" "error"))
    "js-parser-import-forms ~S"
    (src expected)
  (if (string= expected "error")
      (let ((%%signaled1 nil)) (handler-case (progn (cl-cc/javascript:parse-js-module src)) (error () (setf %%signaled1 t))) (expect %%signaled1 :to-be-truthy))
      (let ((ast (first (cl-cc/javascript:parse-js-module src))))
        (expect (cl-cc:ast-call-p ast) :to-be-truthy)
        (expect (%js-call-name ast) :to-equal expected))))

(it-sequential "js-parser-export-const"
  (let ((asts (cl-cc/javascript:parse-js-module "export const val = 1;")))
    (expect (>= (length asts) 1) :to-be-truthy)))

(it-sequential "js-parser-export-const-preserves-declaration-ast"
  (let* ((ast (first (cl-cc/javascript:parse-js-module "export const val = 1 + 2;")))
         (args (cl-cc:ast-call-args ast))
         (decl (second args))
         (names (fourth args))
         (binding (first (cl-cc:ast-let-bindings decl))))
    (expect (cl-cc:ast-call-p ast) :to-be-truthy)
    (expect (%js-call-name ast) :to-equal "%JS-EXPORT")
    (expect (cl-cc:ast-let-p decl) :to-be-truthy)
    (expect (first (cl-cc:ast-let-declarations decl)) :to-equal :const)
    (expect (cl-cc:ast-quote-value names) :to-equal '("val"))
    (expect (symbol-name (car binding)) :to-equal "val")
    (expect (cl-cc:ast-call-p (cdr binding)) :to-be-truthy)
    (expect (string= "%JS-EXPR" (%js-call-name (cdr binding))) :to-be-falsy)))

(it-sequential "js-parser-export-object-destructuring-names"
  (let* ((ast (first (cl-cc/javascript:parse-js-module
                      "export const {x, y: z, ...rest} = obj;")))
         (args (cl-cc:ast-call-args ast))
         (names (fourth args)))
    (expect (cl-cc:ast-call-p ast) :to-be-truthy)
    (expect (%js-call-name ast) :to-equal "%JS-EXPORT")
    (expect (cl-cc:ast-quote-value names) :to-equal '("x" "z" "rest"))))

(it-sequential "js-parser-export-array-destructuring-names"
  (let* ((ast (first (cl-cc/javascript:parse-js-module
                      "export const [x, , y = 1, ...rest] = arr;")))
         (args (cl-cc:ast-call-args ast))
         (names (fourth args)))
    (expect (cl-cc:ast-call-p ast) :to-be-truthy)
    (expect (%js-call-name ast) :to-equal "%JS-EXPORT")
    (expect (cl-cc:ast-quote-value names) :to-equal '("x" "y" "rest"))))

(it-sequential "js-parser-export-function-preserves-body-ast"
  (let* ((ast (first (cl-cc/javascript:parse-js-module
                      "export function add(a, b) { return a + b; }")))
         (args (cl-cc:ast-call-args ast))
         (decl (second args))
         (names (fourth args)))
    (expect (cl-cc:ast-call-p ast) :to-be-truthy)
    (expect (%js-call-name ast) :to-equal "%JS-EXPORT")
    (expect (cl-cc:ast-defun-p decl) :to-be-truthy)
    (expect (symbol-name (cl-cc:ast-defun-name decl)) :to-equal "add")
    (expect (cl-cc:ast-quote-value names) :to-equal '("add"))
    (expect (mapcar #'symbol-name (cl-cc:ast-defun-params decl)) :to-equal '("a" "b"))
    (expect (and (= 1 (length (cl-cc:ast-defun-body decl)))
                       (cl-cc:ast-quote-p (first (cl-cc:ast-defun-body decl)))
                       (eq :stub (cl-cc:ast-quote-value
                                  (first (cl-cc:ast-defun-body decl))))) :to-be-falsy)))

(it-sequential-each (("export default 1 + 2;" "%JS-EXPORT")
                     ("export default function foo() {}" "%JS-EXPORT")
                     ("export default async function foo() {}" "%JS-EXPORT")
                     ("export default class Foo {}" "%JS-EXPORT")
                     ("export * from 'mod';" "%JS-EXPORT")
                     ("export * as ns from 'mod';" "%JS-EXPORT")
                     ("export { foo, bar as baz };" "%JS-EXPORT")
                     ("export { foo as bar } from 'mod';" "%JS-EXPORT")
                     ("export const value = 1;" "%JS-EXPORT")
                     ("export function fn() {}" "%JS-EXPORT")
                     ("export async function fn() {}" "%JS-EXPORT")
                     ("export class C {}" "%JS-EXPORT")
                     ("export default" "error"))
    "js-parser-export-forms ~S"
    (src expected)
  (if (string= expected "error")
      (let ((%%signaled2 nil)) (handler-case (progn (cl-cc/javascript:parse-js-module src)) (error () (setf %%signaled2 t))) (expect %%signaled2 :to-be-truthy))
      (let ((ast (first (cl-cc/javascript:parse-js-module src))))
        (expect (cl-cc:ast-call-p ast) :to-be-truthy)
        (expect (%js-call-name ast) :to-equal expected))))

(it-sequential "js-parser-import-meta-expression"
  (let* ((ast (first (cl-cc/javascript:parse-js-module "const meta = import.meta;")))
         (val (cdr (first (cl-cc:ast-let-bindings ast)))))
    (expect (cl-cc:ast-let-p ast) :to-be-truthy)
    (expect (%js-call-name val) :to-equal "%JS-IMPORT-META")))

(it-sequential "js-parser-dynamic-import-expression-statement"
  (let ((ast (%js-first "import('./dep.js');")))
    (expect (cl-cc:ast-call-p ast) :to-be-truthy)
    (expect (%js-call-name ast) :to-equal "%JS-IMPORT")))

;;; ─── Using declaration (ES2025) ───────────────────────────────────────────────

(it-sequential "js-parser-using-declaration"
  (let ((ast (%js-first "using x = getResource();")))
    (expect (cl-cc:ast-let-p ast) :to-be-truthy)
    (expect (member :js-using (cl-cc:ast-let-declarations ast)) :to-be-truthy)))

;;; ─── Internal destructuring / default-expression coverage ────────────────────

(defun %js-token-ast (src)
  "Build the minimal AST returned by %js-toks-to-ast for the first token in SRC."
  (cl-cc/javascript::%js-toks-to-ast
   (list (first (cl-cc/javascript:tokenize-js-source src)))))

(it-sequential-each (("42" :int)
                     ("'hello'" :quote)
                     ("true" :quote)
                     ("false" :quote)
                     ("null" :quote)
                     ("undefined" :quote)
                     ("name" :var)
                     ("." :quote))
    "js-parser-toks-to-ast-single-token ~S"
    (src kind)
  (let ((ast (%js-token-ast src)))
    (case kind
      (:int   (expect (cl-cc:ast-int-p ast) :to-be-truthy))
      (:quote (expect (cl-cc:ast-quote-p ast) :to-be-truthy))
      (:var   (expect (cl-cc:ast-var-p ast) :to-be-truthy)))))

(it-sequential "js-parser-toks-to-ast-multi-token"
  (let ((ast (cl-cc/javascript::%js-toks-to-ast
              (butlast (cl-cc/javascript:tokenize-js-source "(a + b)")))))
    (expect (cl-cc:ast-call-p ast) :to-be-truthy)
    (expect (%js-call-name ast) :to-equal "%JS-RAW-DEFAULT")))

(it-sequential-each ((", tail" :quote)
                     ("] tail" :quote)
                     ("(a, [b, c], {d: e}) , tail" :call))
    "js-parser-default-expr-delimiters ~S"
    (src kind)
  (multiple-value-bind (ast rest)
      (cl-cc/javascript::%js-parse-default-expr (cl-cc/javascript:tokenize-js-source src))
    (case kind
      (:quote
       (expect (cl-cc:ast-quote-p ast) :to-be-truthy)
       (expect (cl-cc:ast-quote-value ast) :to-equal nil))
      (:call
       (expect (cl-cc:ast-call-p ast) :to-be-truthy)
       (expect (%js-call-name ast) :to-equal "%JS-RAW-DEFAULT")
       (expect (getf (first rest) :type) :to-be :T-COMMA)))))

(it-sequential "js-parser-binding-pattern-array-branches"
  (multiple-value-bind (pat rest)
      (cl-cc/javascript::js-parse-binding-pattern
       (cl-cc/javascript:tokenize-js-source "[, a = 1, [b, ...r], ...rest]"))
    (expect (getf (first rest) :type) :to-be :T-EOF)
    (expect (cl-cc/javascript::js-binding-pattern-kind pat) :to-be :array)
    (let* ((elements (cl-cc/javascript::js-binding-pattern-elements pat))
           (first-el (first elements))
           (second-el (second elements))
           (third-el  (third elements)))
      (expect (= 3 (length elements)) :to-be-truthy)
      (expect (null (first first-el)) :to-be-truthy)
      (expect (cl-cc/javascript::js-binding-pattern-kind
                         (first second-el)) :to-be :ident)
      (expect (cl-cc:ast-int-p (second second-el)) :to-be-truthy)
      (expect (cl-cc/javascript::js-binding-pattern-kind
                         (first third-el)) :to-be :array)
      (expect (cl-cc/javascript::js-binding-pattern-rest pat) :to-be-truthy)
      (expect (cl-cc/javascript::js-binding-pattern-kind
                         (cl-cc/javascript::js-binding-pattern-rest pat)) :to-be :ident))))

(it-sequential "js-parser-binding-pattern-object-branches"
  (multiple-value-bind (pat rest)
      (cl-cc/javascript::js-parse-binding-pattern
       (cl-cc/javascript:tokenize-js-source
        "{x, \"s\": s, 1: n = 3, nested: [a, ...r], ...rest}"))
    (expect (getf (first rest) :type) :to-be :T-EOF)
    (expect (cl-cc/javascript::js-binding-pattern-kind pat) :to-be :object)
    (expect (= 4 (length (cl-cc/javascript::js-binding-pattern-properties pat))) :to-be-truthy)
    (let* ((props (cl-cc/javascript::js-binding-pattern-properties pat))
           (p1 (first props))
           (p2 (second props))
           (p3 (third props))
           (p4 (fourth props)))
      (expect (first p1) :to-equal "x")
      (expect (cl-cc/javascript::js-binding-pattern-kind (second p1)) :to-be :ident)
      (expect (first p2) :to-equal "s")
      (expect (cl-cc/javascript::js-binding-pattern-kind (second p2)) :to-be :ident)
      (expect (first p3) :to-equal "1")
      (expect (cl-cc/javascript::js-binding-pattern-kind (second p3)) :to-be :ident)
      (expect (cl-cc:ast-int-p (third p3)) :to-be-truthy)
      (expect (first p4) :to-equal "nested")
      (expect (cl-cc/javascript::js-binding-pattern-kind (second p4)) :to-be :array)
      (expect (cl-cc/javascript::js-binding-pattern-kind
                         (cl-cc/javascript::js-binding-pattern-rest pat)) :to-be :ident))))

(it-sequential "js-parser-binding-pattern-error"
  (let ((%%signaled3 nil)) (handler-case (progn (cl-cc/javascript::js-parse-binding-pattern
     (cl-cc/javascript:tokenize-js-source "."))) (error () (setf %%signaled3 t))) (expect %%signaled3 :to-be-truthy)))

(it-sequential "js-parser-build-pattern-let-array-rest"
  (let* ((pat (first (%js-parse "[a, ...rest]")))
         (body (cl-cc/javascript::%js-build-pattern-let
                (cl-cc/javascript::js-parse-binding-pattern
                 (cl-cc/javascript:tokenize-js-source "[a, ...rest]"))
                (make-ast-var :name 'src)
                (list (make-ast-quote :value :done)))))
    (declare (ignore pat))
    (expect (cl-cc:ast-let-p (first body)) :to-be-truthy)
    (let* ((outer (first body))
           (inner (first (cl-cc:ast-let-body outer)))
           (rest-let (first (cl-cc:ast-let-body inner)))
           (rest-binding (first (cl-cc:ast-let-bindings rest-let))))
      (expect (cl-cc:ast-let-p outer) :to-be-truthy)
      (expect (cl-cc:ast-let-p inner) :to-be-truthy)
      (expect (cl-cc:ast-let-p rest-let) :to-be-truthy)
      (expect (%js-call-name (cdr rest-binding)) :to-equal "%JS-ARRAY-SLICE"))))

(it-sequential "js-parser-build-pattern-let-object-rest"
  (let* ((body (cl-cc/javascript::%js-build-pattern-let
                (cl-cc/javascript::js-parse-binding-pattern
                 (cl-cc/javascript:tokenize-js-source "{a, ...rest}"))
                (make-ast-var :name 'src)
                (list (make-ast-quote :value :done))))
         (outer (first body))
         (inner (first (cl-cc:ast-let-body outer)))
         (rest-let (first (cl-cc:ast-let-body inner)))
         (rest-binding (first (cl-cc:ast-let-bindings rest-let))))
    (expect (cl-cc:ast-let-p outer) :to-be-truthy)
    (expect (cl-cc:ast-let-p inner) :to-be-truthy)
    (expect (cl-cc:ast-let-p rest-let) :to-be-truthy)
    (expect (%js-call-name (cdr rest-binding)) :to-equal "%JS-OBJECT-REST")))

(it-sequential "js-parser-build-pattern-let-error"
  (let ((%%signaled4 nil)) (handler-case (progn (cl-cc/javascript::%js-build-pattern-let
     (cl-cc/javascript::make-js-binding-pattern :kind :bogus)
     (make-ast-var :name 'src)
     (list (make-ast-quote :value :done)))) (error () (setf %%signaled4 t))) (expect %%signaled4 :to-be-truthy)))

(it-sequential "js-parser-lower-binding-pattern-ident"
  (multiple-value-bind (bindings inner)
      (cl-cc/javascript::js-lower-binding-pattern
       (cl-cc/javascript::make-js-binding-pattern :kind :ident :name 'x)
       (make-ast-var :name 'src))
    (expect (= 1 (length bindings)) :to-be-truthy)
    (expect (car (first bindings)) :to-be 'x)
    (expect (cl-cc:ast-var-p (cdr (first bindings))) :to-be-truthy)
    (expect inner :to-equal nil)))

(it-sequential-each (("[[a], ...rest]")
                     ("{nested: [a], ...rest}"))
    "js-parser-lower-binding-pattern-nested ~S"
    (src)
  (multiple-value-bind (pat rest)
      (cl-cc/javascript::js-parse-binding-pattern
       (cl-cc/javascript:tokenize-js-source src))
    (declare (ignore rest))
    (multiple-value-bind (bindings inner)
        (cl-cc/javascript::js-lower-binding-pattern
         pat
         (make-ast-var :name 'src))
      (expect (= 1 (length bindings)) :to-be-truthy)
      (expect (consp inner) :to-be-truthy)
      (expect (cl-cc:ast-let-p (first inner)) :to-be-truthy))))

(it-sequential "js-parser-lower-binding-pattern-error"
  (let ((%%signaled5 nil)) (handler-case (progn (cl-cc/javascript::js-lower-binding-pattern
     (cl-cc/javascript::make-js-binding-pattern :kind :bogus)
     (make-ast-var :name 'src))) (error () (setf %%signaled5 t))) (expect %%signaled5 :to-be-truthy)))

;;; ─── Throw statement ──────────────────────────────────────────────────────────

(it-sequential "js-parser-throw-stmt"
  (let ((ast (%js-first "throw new Error('msg');")))
    (expect (cl-cc:ast-call-p ast) :to-be-truthy)
    (expect (%js-call-name ast) :to-equal "%JS-THROW")))

;;; ─── Return statement ─────────────────────────────────────────────────────────

(it-sequential "js-parser-return-with-value"
  (let* ((ast (%js-first "function f() { return 42; }"))
         (body (cl-cc:ast-defun-body ast))
         (block (first body))
         (inner (when (cl-cc:ast-block-p block) (cl-cc:ast-block-body block))))
    (expect (cl-cc:ast-defun-p ast) :to-be-truthy)
    (expect (some #'cl-cc:ast-return-from-p (or inner body)) :to-be-truthy)))

(it-sequential "js-parser-return-bare"
  (let* ((ast (%js-first "function g() { return; }"))
         (body (cl-cc:ast-defun-body ast))
         (block (first body))
         (ret (when (cl-cc:ast-block-p block)
                (first (cl-cc:ast-block-body block)))))
    (expect (cl-cc:ast-block-p block) :to-be-truthy)
    (expect (cl-cc:ast-return-from-p ret) :to-be-truthy)
    (expect (cl-cc:ast-quote-p (cl-cc:ast-return-from-value ret)) :to-be-truthy)))

;;; ─── Multi-statement source ───────────────────────────────────────────────────

(it-sequential "js-parser-multi-statement-source"
  (let ((asts (%js-parse "const a = 1; const b = 2; const c = 3;")))
    (expect (= 1 (length asts)) :to-be-truthy)
    (expect (cl-cc:ast-let-p (first asts)) :to-be-truthy)))

;;; ─── Generator functions ──────────────────────────────────────────────────────

(it-sequential "js-parser-generator-function-star"
  (let ((ast (%js-first "function* gen() { yield 1; }")))
    (expect (cl-cc:ast-defun-p ast) :to-be-truthy)
    (expect (member :js-generator (cl-cc:ast-defun-declarations ast)) :to-be-truthy)))

(it-sequential "js-parser-yield-expr"
  (let* ((ast (%js-first "function* gen() { yield 42; }"))
         (body (cl-cc:ast-defun-body ast))
         (generator-call (first body)))
    (expect (%js-call-name generator-call) :to-equal "%JS-MAKE-GENERATOR")))

(it-sequential "js-parser-yield-star"
  (let* ((ast (%js-first "function* gen() { yield* [1,2]; }"))
         (body (cl-cc:ast-defun-body ast)))
    (expect (cl-cc:ast-defun-p ast) :to-be-truthy)
    (expect (%js-call-name (first body)) :to-equal "%JS-MAKE-GENERATOR")))

;;; ─── for-of / for-in ──────────────────────────────────────────────────────────

(it-sequential "js-parser-for-of-array"
  (let* ((ast (%js-first "for (const x of [1,2,3]) {}"))
         (bindings (cl-cc:ast-let-bindings ast))
         (iter-val (cdr (first bindings))))
    (expect (cl-cc:ast-let-p ast) :to-be-truthy)
    (expect (%js-call-name iter-val) :to-equal "%JS-ITER-VALUES")))

(it-sequential "js-parser-for-in-object"
  (let* ((ast (%js-first "for (const k in {a: 1}) {}"))
         (bindings (cl-cc:ast-let-bindings ast))
         (iter-val (cdr (first bindings))))
    (expect (cl-cc:ast-let-p ast) :to-be-truthy)
    (expect (%js-call-name iter-val) :to-equal "%JS-ITER-KEYS")))

;;; ─── New expression ───────────────────────────────────────────────────────────

(it-sequential "js-parser-new-expr"
  (let ((ast (%js-first "new Foo();")))
    (expect (%js-call-name ast) :to-equal "%JS-NEW")))

(it-sequential "js-parser-new-target"
  (let* ((ast (%js-first "function f() { return new.target; }"))
         (body (cl-cc:ast-defun-body ast)))
    (expect (cl-cc:ast-defun-p ast) :to-be-truthy)
    (expect (not (null body)) :to-be-truthy)))

;;; ─── Unary operators ──────────────────────────────────────────────────────────

(it-sequential-each (("!x" "NOT")
                     ("typeof x" "%JS-TYPEOF")
                     ("void 0" "PROGN")
                     ("delete x" "%JS-DELETE"))
    "js-parser-unary-ops ~S"
    (src expected)
  (let ((ast (%js-first src)))
    (cond
      ((string= expected "PROGN")
       (expect (cl-cc:ast-progn-p ast) :to-be-truthy))
      ((string= expected "NOT")
       (expect (cl-cc:ast-call-p ast) :to-be-truthy)
       (expect (%js-call-name ast) :to-equal "NOT"))
      (t
       (expect (%js-call-name ast) :to-equal expected)))))

;;; ─── Decorators ───────────────────────────────────────────────────────────────
;;; %js-parse-decorator(s) itself, beyond the lexer-only "@decorator" tokenize
;;; check elsewhere — member-chain walking and argument-list parsing were
;;; previously untested.

(defun %js-decorators (src)
  "Parse the leading @decorator forms in SRC, returning (values decorators rest)."
  (cl-cc/javascript::%js-parse-decorators (cl-cc/javascript:tokenize-js-source src)))

(it-sequential "js-parser-decorators-none"
  (multiple-value-bind (decorators rest) (%js-decorators "class Foo {}")
    (expect decorators :to-be-null)
    (expect (cl-cc/javascript::js-peek-type rest) :to-be :T-CLASS)))

(it-sequential "js-parser-decorators-simple"
  (multiple-value-bind (decorators rest) (%js-decorators "@dec class Foo {}")
    (expect (length decorators) :to-be 1)
    (expect (cl-cc:ast-var-p (first decorators)) :to-be-truthy)
    (expect (symbol-name (cl-cc:ast-var-name (first decorators))) :to-equal "dec")
    (expect (cl-cc/javascript::js-peek-type rest) :to-be :T-CLASS)))

(it-sequential "js-parser-decorators-member-chain"
  (multiple-value-bind (decorators rest) (%js-decorators "@ns.sub.dec class Foo {}")
    (declare (ignore rest))
    (expect (length decorators) :to-be 1)
    (expect (symbol-name (cl-cc:ast-var-name (first decorators))) :to-equal "ns.sub.dec")))

(it-sequential "js-parser-decorators-with-args"
  (multiple-value-bind (decorators rest) (%js-decorators "@dec(1, 2) class Foo {}")
    (declare (ignore rest))
    (expect (length decorators) :to-be 1)
    (expect (cl-cc:ast-call-p (first decorators)) :to-be-truthy)
    (expect (symbol-name (cl-cc:ast-var-name (cl-cc:ast-call-func (first decorators))))
            :to-equal "dec")
    (expect (length (cl-cc:ast-call-args (first decorators))) :to-be 2)))

(it-sequential "js-parser-decorators-stacked"
  (multiple-value-bind (decorators rest) (%js-decorators "@a @b @c class Foo {}")
    (declare (ignore rest))
    (expect (length decorators) :to-be 3)
    (expect (mapcar (lambda (d) (symbol-name (cl-cc:ast-var-name d))) decorators)
            :to-equal '("a" "b" "c"))))
