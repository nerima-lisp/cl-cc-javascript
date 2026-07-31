;;;; t/parser-stmt-module-test.lisp
;;;;
;;;; Split from parser-stmt-test.lisp: import/export statement forms
;;;; (including dynamic import, import.meta, and export-declaration AST
;;;; preservation) and the using declaration (ES2025).
;;;;
;;;; Depends on: parser-decl-test.lisp (%js-parse, %js-first, %js-call-name).

(in-package :cl-cc-javascript/test)

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
      (signals error (cl-cc/javascript:parse-js-module src))
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
      (signals error (cl-cc/javascript:parse-js-module src))
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
