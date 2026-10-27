;;;; t/parser-stmt-module-test.lisp
;;;;
;;;; Split from parser-stmt-test.lisp: import/export statement forms
;;;; (including dynamic import, import.meta, and export-declaration AST
;;;; preservation) and the using declaration (ES2025).
;;;;
;;;; Uses shared parse helpers imported from cl-cc-javascript/test.

(in-package #:cl-cc/javascript/modules/test)

;;; ─── Import / export ──────────────────────────────────────────────────────────

(defun %register-modules-parser-stmt-module-tests ()
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
          (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
          (expect (%js-call-name ast) :to-equal expected))))
  (it-sequential "js-parser-export-const"
    (let ((asts (cl-cc/javascript:parse-js-module "export const val = 1;")))
      (expect (>= (length asts) 1) :to-be-truthy)))
  (it-sequential "js-parser-export-const-preserves-declaration-ast"
    (let* ((ast (first (cl-cc/javascript:parse-js-module "export const val = 1 + 2;")))
           (args (cl-cc/ast:ast-call-args ast))
           (decl (second args))
           (names (fourth args))
           (binding (first (cl-cc/ast:ast-let-bindings decl))))
      (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
      (expect (%js-call-name ast) :to-equal "%JS-EXPORT")
      (expect (cl-cc/ast:ast-let-p decl) :to-be-truthy)
      (expect (first (cl-cc/ast:ast-let-declarations decl)) :to-equal :const)
      (expect (cl-cc/ast:ast-quote-value names) :to-equal '("val"))
      (expect (symbol-name (car binding)) :to-equal "val")
      (expect (cl-cc/ast:ast-call-p (cdr binding)) :to-be-truthy)
      (expect (string= "%JS-EXPR" (%js-call-name (cdr binding))) :to-be-falsy)))
  (it-sequential "js-parser-export-object-destructuring-names"
    (let* ((ast (first (cl-cc/javascript:parse-js-module
                        "export const {x, y: z, ...rest} = obj;")))
           (args (cl-cc/ast:ast-call-args ast))
           (names (fourth args)))
      (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
      (expect (%js-call-name ast) :to-equal "%JS-EXPORT")
      (expect (cl-cc/ast:ast-quote-value names) :to-equal '("x" "z" "rest"))))
  (it-sequential "js-parser-export-array-destructuring-names"
    (let* ((ast (first (cl-cc/javascript:parse-js-module
                        "export const [x, , y = 1, ...rest] = arr;")))
           (args (cl-cc/ast:ast-call-args ast))
           (names (fourth args)))
      (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
      (expect (%js-call-name ast) :to-equal "%JS-EXPORT")
      (expect (cl-cc/ast:ast-quote-value names) :to-equal '("x" "y" "rest"))))
  (it-sequential "js-parser-export-function-preserves-body-ast"
    (let* ((ast (first (cl-cc/javascript:parse-js-module
                        "export function add(a, b) { return a + b; }")))
           (args (cl-cc/ast:ast-call-args ast))
           (decl (second args))
           (names (fourth args)))
      (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
      (expect (%js-call-name ast) :to-equal "%JS-EXPORT")
      (expect (cl-cc/ast:ast-defun-p decl) :to-be-truthy)
      (expect (symbol-name (cl-cc/ast:ast-defun-name decl)) :to-equal "add")
      (expect (cl-cc/ast:ast-quote-value names) :to-equal '("add"))
      (expect (mapcar #'symbol-name (cl-cc/ast:ast-defun-params decl)) :to-equal '("a" "b"))
      (expect (and (= 1 (length (cl-cc/ast:ast-defun-body decl)))
                         (cl-cc/ast:ast-quote-p (first (cl-cc/ast:ast-defun-body decl)))
                         (eq :stub (cl-cc/ast:ast-quote-value
                                    (first (cl-cc/ast:ast-defun-body decl))))) :to-be-falsy)))
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
          (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
          (expect (%js-call-name ast) :to-equal expected))))
  (it-sequential "js-parser-import-meta-expression"
    (let* ((ast (first (cl-cc/javascript:parse-js-module "const meta = import.meta;")))
           (val (cdr (first (cl-cc/ast:ast-let-bindings ast)))))
      (expect (cl-cc/ast:ast-let-p ast) :to-be-truthy)
      (expect (%js-call-name val) :to-equal "%JS-IMPORT-META")))
  (it-sequential "js-parser-dynamic-import-expression-statement"
    (let ((ast (%js-first "import('./dep.js');")))
      (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
      (expect (%js-call-name ast) :to-equal "%JS-IMPORT")))
  (it-sequential "js-parser-using-declaration"
    (let ((ast (%js-first "using x = getResource();")))
      (expect (cl-cc/ast:ast-let-p ast) :to-be-truthy)
      (expect (member :js-using (cl-cc/ast:ast-let-declarations ast)) :to-be-truthy)))
  )

;;; ─── Using declaration (ES2025) ───────────────────────────────────────────────

(defmacro with-fresh-js-module-exports (&body body)
  "Bind *js-module-exports* to a fresh, empty exports object for BODY. Each
module-exports test below needs its own isolated table so registrations from
one test can't leak into another."
  `(let ((cl-cc/javascript/modules::*js-module-exports* (cl-cc/javascript::%js-make-object)))
     ,@body))

(defun %register-modules-module-registration-tests ()
  (it-sequential "js-rt-export-default-registers-module-value"
      (with-fresh-js-module-exports
        (let* ((result (cl-cc/javascript::%js-export :default 42))
               (exports (cl-cc/javascript/modules::%js-current-module-exports)))
          (expect (= 42 result) :to-be-truthy)
          (expect (= 42 (cl-cc/javascript::%js-get-prop exports "default")) :to-be-truthy))))
  (it-sequential "js-rt-export-declaration-registers-named-value"
      (with-fresh-js-module-exports
        (let* ((fn (lambda () 7))
               (result (cl-cc/javascript::%js-export :declaration fn nil '("add")))
               (exports (cl-cc/javascript/modules::%js-current-module-exports)))
          (expect result :to-be fn)
          (expect (gethash "add" exports) :to-be fn))))
  (it-sequential "js-rt-export-reexport-records-source-metadata"
      (with-fresh-js-module-exports
        (cl-cc/javascript::%js-export
         :re-export
         (list (list :local "foo" :exported "bar"))
         "./dep.js")
        (let* ((exports (cl-cc/javascript/modules::%js-current-module-exports))
               (reexports (cl-cc/javascript::%js-get-prop exports "__reexports__"))
               (entry (aref reexports 0))
               (specs (cl-cc/javascript::%js-get-prop entry "value"))
               (spec (aref specs 0)))
          (expect (= 1 (length reexports)) :to-be-truthy)
          (expect (cl-cc/javascript::%js-get-prop entry "kind") :to-equal "named")
          (expect (cl-cc/javascript::%js-get-prop entry "from") :to-equal "./dep.js")
          (expect (cl-cc/javascript::%js-get-prop spec "local") :to-equal "foo")
          (expect (cl-cc/javascript::%js-get-prop spec "exported") :to-equal "bar"))))
)
