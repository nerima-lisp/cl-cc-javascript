;;;; t/parser-stmt-control-flow-test.lisp
;;;;
;;;; Split from parser-stmt-test.lisp: core statement and expression syntax —
;;;; if/else, while, for loop variants, switch, try/catch/finally,
;;;; destructuring, spread, optional chaining, nullish coalescing, logical
;;;; assignment, and template literals.
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
