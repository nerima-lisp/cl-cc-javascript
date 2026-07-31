;;;; t/parser-stmt-misc-test.lisp
;;;;
;;;; Split from parser-stmt-test.lisp: throw, return, multi-statement
;;;; sources, generator functions, for-of/for-in, new expressions, unary
;;;; operators, and decorators (member-chain walking and argument-list
;;;; parsing beyond the lexer-only "@decorator" tokenize check).
;;;;
;;;; Depends on: parser-decl-test.lisp (%js-parse, %js-first, %js-call-name).

(in-package :cl-cc-javascript/test)

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

(it-sequential "js-parser-decorators-with-nested-call-arg"
  ;; @dec(1, 2)'s test above never checks REST -- a decorator argument that
  ;; is itself a call (nested parens/commas) is where a naive "skip tokens
  ;; until the next comma or ')'" argument-list scan (as opposed to one that
  ;; tracks nesting depth) stops at the INNER call's own comma/close-paren
  ;; instead of the outer one, leaving REST pointing at a stray ')' instead
  ;; of the class keyword.
  (multiple-value-bind (decorators rest) (%js-decorators "@dec(foo(1,2)) class Foo {}")
    (expect (length decorators) :to-be 1)
    (expect (cl-cc/javascript::js-peek-type rest) :to-be :T-CLASS)))

(it-sequential "js-parser-decorators-stacked"
  (multiple-value-bind (decorators rest) (%js-decorators "@a @b @c class Foo {}")
    (declare (ignore rest))
    (expect (length decorators) :to-be 3)
    (expect (mapcar (lambda (d) (symbol-name (cl-cc:ast-var-name d))) decorators)
            :to-equal '("a" "b" "c"))))
