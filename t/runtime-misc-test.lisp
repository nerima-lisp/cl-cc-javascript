;;;; t/runtime-misc-test.lisp
;;;;
;;;; Split from runtime-method-resolver-test.lisp: Object.is NaN/zero
;;;; special cases, ToString extended coverage (float formatting, Infinity,
;;;; BigInt), template string joining, and structuredClone / deep-clone.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr)

(in-package :cl-cc-javascript/test)

;;; ─── Object.is — NaN/zero special cases ─────────────────────────────────────

(it-sequential-each ((:js-nan :js-nan t)
                     (:js-nan 1.0d0 nil)
                     (0.0d0 -0.0d0 nil)
                     (-0.0d0 0.0d0 nil)
                     (3.0d0 3.0d0 t)
                     ("x" "x" t)
                     ("a" "b" nil))
    "js-rt-object-is ~A/~A"
    (a b expected)
  (expect (cl-cc/javascript::%js-object-is a b) :to-equal expected))

;;; ─── ToString: float formatting + Infinity + BigInt ──────────────────────────

(it-sequential-each ((7.0d0 "7") (3.14d0 "3.14"))
    "js-rt-to-string-extended ~A"
    (value expected)
  (expect (cl-cc/javascript::%js-to-string value) :to-equal expected))

(it-sequential "js-rt-to-string-extended infinity"
  (destructuring-bind (value expected) (list cl-cc/javascript::+js-infinity+ "Infinity")
    (expect (cl-cc/javascript::%js-to-string value) :to-equal expected)))

(it-sequential "js-rt-to-string-extended neg-inf"
  (destructuring-bind (value expected) (list cl-cc/javascript::+js-neg-infinity+ "-Infinity")
    (expect (cl-cc/javascript::%js-to-string value) :to-equal expected)))

(it-sequential "js-rt-to-string-extended float-nan"
  (destructuring-bind (value expected) (list cl-cc/javascript::*js-nan-float* "NaN")
    (expect (cl-cc/javascript::%js-to-string value) :to-equal expected)))

(it-sequential "js-rt-to-string-extended bigint"
  (destructuring-bind (value expected) (list (cl-cc/javascript::%make-js-bigint 99) "99")
    (expect (cl-cc/javascript::%js-to-string value) :to-equal expected)))

;;; ─── Template string joining ─────────────────────────────────────────────────

(it-sequential "js-rt-template-string-join"
  (expect (cl-cc/javascript::%js-template-string '("hello " 42 " world")) :to-equal "hello 42 world")
  (expect (cl-cc/javascript::%js-template-string '(t " and " nil)) :to-equal "true and false"))

;;; ─── structuredClone / deep-clone ────────────────────────────────────────────

(it-sequential "js-rt-deep-clone-array"
  (let* ((orig  (%jr-arr 1 2 3))
         (clone (cl-cc/javascript::%js-deep-clone orig)))
    (expect (cl-cc/javascript::%js-vec-p clone) :to-be-truthy)
    (expect (= (length orig) (length clone)) :to-be-truthy)
    (expect (= 1 (aref clone 0)) :to-be-truthy)
    (expect (eq orig clone) :to-be-falsy)))

(it-sequential "js-rt-deep-clone-object"
  (let* ((orig  (cl-cc/javascript::%js-make-object "x" 10))
         (clone (cl-cc/javascript::%js-deep-clone orig)))
    (expect (cl-cc/javascript::%js-ht-p clone) :to-be-truthy)
    (expect (= 10 (gethash "x" clone)) :to-be-truthy)
    (expect (eq orig clone) :to-be-falsy)))
