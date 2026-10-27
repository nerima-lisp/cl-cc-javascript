;;;; t/statements/parser-stmt-extended-forms-test.lisp
;;;;
;;;; Split from parser-stmt-test.lisp: throw, return, multi-statement
;;;; sources, generator functions, for-of/for-in, new expressions, unary
;;;; operators, and decorators (member-chain walking and argument-list
;;;; parsing beyond the lexer-only "@decorator" tokenize check).
;;;;
;;;; Uses shared parse helpers imported from cl-cc-javascript/test.

(in-package #:cl-cc/javascript/statements/test)

;;; ─── Throw statement ──────────────────────────────────────────────────────────

(defun %register-statements-parser-stmt-misc-part-1-tests ()
  (it-sequential "js-parser-throw-stmt"
    (let ((ast (%js-first "throw new Error('msg');")))
      (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
      (expect (%js-call-name ast) :to-equal "%JS-THROW")))
  (it-sequential "js-parser-return-with-value"
    (let* ((ast (%js-first "function f() { return 42; }"))
           (body (cl-cc/ast:ast-defun-body ast))
           (block (first body))
           (inner (when (cl-cc/ast:ast-block-p block) (cl-cc/ast:ast-block-body block))))
      (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
      (expect (some #'cl-cc/ast:ast-return-from-p (or inner body)) :to-be-truthy)))
  (it-sequential "js-parser-return-bare"
    (let* ((ast (%js-first "function g() { return; }"))
           (body (cl-cc/ast:ast-defun-body ast))
           (block (first body))
           (ret (when (cl-cc/ast:ast-block-p block)
                  (first (cl-cc/ast:ast-block-body block)))))
      (expect (cl-cc/ast:ast-block-p block) :to-be-truthy)
      (expect (cl-cc/ast:ast-return-from-p ret) :to-be-truthy)
      (expect (cl-cc/ast:ast-quote-p (cl-cc/ast:ast-return-from-value ret)) :to-be-truthy)))
  (it-sequential "js-parser-multi-statement-source"
    (let ((asts (%js-parse "const a = 1; const b = 2; const c = 3;")))
      (expect (= 1 (length asts)) :to-be-truthy)
      (expect (cl-cc/ast:ast-let-p (first asts)) :to-be-truthy)))
  (it-sequential "js-parser-generator-function-star"
    (let ((ast (%js-first "function* gen() { yield 1; }")))
      (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
      (expect (member :js-generator (cl-cc/ast:ast-defun-declarations ast)) :to-be-truthy)))
  (it-sequential "js-parser-yield-expr"
    (let* ((ast (%js-first "function* gen() { yield 42; }"))
           (body (cl-cc/ast:ast-defun-body ast))
           (generator-call (first body)))
      (expect (%js-call-name generator-call) :to-equal "%JS-OBJECT-MAKE-GENERATOR")))
  (it-sequential "js-parser-yield-star"
    (let* ((ast (%js-first "function* gen() { yield* [1,2]; }"))
           (body (cl-cc/ast:ast-defun-body ast)))
      (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
      (expect (%js-call-name (first body)) :to-equal "%JS-OBJECT-MAKE-GENERATOR")))
  (it-sequential "js-parser-for-of-array"
    (let* ((ast (%js-first "for (const x of [1,2,3]) {}"))
           (bindings (cl-cc/ast:ast-let-bindings ast))
           (iter-val (cdr (first bindings))))
      (expect (cl-cc/ast:ast-let-p ast) :to-be-truthy)
      (expect (%js-call-name iter-val) :to-equal "%JS-ITER-VALUES")))
  (it-sequential "js-parser-for-in-object"
    (let* ((ast (%js-first "for (const k in {a: 1}) {}"))
           (bindings (cl-cc/ast:ast-let-bindings ast))
           (iter-val (cdr (first bindings))))
      (expect (cl-cc/ast:ast-let-p ast) :to-be-truthy)
      (expect (%js-call-name iter-val) :to-equal "%JS-ITER-KEYS")))
  (it-sequential "js-parser-new-expr"
    (let ((ast (%js-first "new Foo();")))
      (expect (%js-call-name ast) :to-equal "%JS-NEW")))
  (it-sequential "js-parser-new-target"
    (let* ((ast (%js-first "function f() { return new.target; }"))
           (body (cl-cc/ast:ast-defun-body ast)))
      (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
      (expect (not (null body)) :to-be-truthy)))
  (it-sequential-each (("!x" "NOT")
                       ("typeof x" "%JS-TYPEOF")
                       ("void 0" "PROGN")
                       ("delete x" "%JS-DELETE"))
      "js-parser-unary-ops ~S"
      (src expected)
    (let ((ast (%js-first src)))
      (cond
        ((string= expected "PROGN")
         (expect (cl-cc/ast:ast-progn-p ast) :to-be-truthy))
        ((string= expected "NOT")
         (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
         (expect (%js-call-name ast) :to-equal "NOT"))
        (t
         (expect (%js-call-name ast) :to-equal expected)))))
  )

;;; ─── Return statement ─────────────────────────────────────────────────────────

;;; ─── Multi-statement source ───────────────────────────────────────────────────

;;; ─── Generator functions ──────────────────────────────────────────────────────

;;; ─── for-of / for-in ──────────────────────────────────────────────────────────

;;; ─── New expression ───────────────────────────────────────────────────────────

;;; ─── Unary operators ──────────────────────────────────────────────────────────

;;; ─── Decorators ───────────────────────────────────────────────────────────────
;;; %js-parse-decorator(s) itself, beyond the lexer-only "@decorator" tokenize
;;; check elsewhere — member-chain walking and argument-list parsing were
;;; previously untested.

