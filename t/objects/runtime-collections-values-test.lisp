;;;; t/runtime-collections-values-test.lisp
;;;;
;;;; Split from runtime-collections-test.lisp: Promise built-ins (resolve/
;;;; reject/then/all/any/withResolvers), Map built-ins (set/get/has/size,
;;;; SameValueZero keys, forEach order, clear, getOrInsert(Computed),
;;;; groupBy), Generator/yield, and BigInt arithmetic/bitwise/asIntN/asUintN
;;;; operations.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list, %jr-set)

(in-package #:cl-cc/javascript/objects/test)

;;; ─── Promise built-ins ───────────────────────────────────────────────────────

(defun %register-objects-runtime-collections-values-tests ()
  (it-sequential "js-rt-map-set-get-has-size"
    (let ((m (cl-cc/javascript::%js-make-map)))
      (cl-cc/javascript::%js-map-set m "k" 42)
      (expect (= 1 (cl-cc/javascript::%js-map-size m)) :to-be-truthy)
      (expect (cl-cc/javascript::%js-map-has m "k") :to-be-truthy)
      (expect (cl-cc/javascript::%js-map-has m "x") :to-be-falsy)
      (expect (= 42 (cl-cc/javascript::%js-map-get m "k")) :to-be-truthy)
      (cl-cc/javascript::%js-map-delete m "k")
      (expect (zerop (cl-cc/javascript::%js-map-size m)) :to-be-truthy)))
  (it-sequential "js-rt-map-same-value-zero-keys"
    (let ((nan-a cl-cc/javascript/objects::*js-nan-float*)
          (nan-b cl-cc/javascript/objects:+js-nan+)
          (m (cl-cc/javascript::%js-make-map)))
      (cl-cc/javascript::%js-map-set m nan-a "first")
      (expect (cl-cc/javascript::%js-map-has m nan-b) :to-be-truthy)
      (expect (cl-cc/javascript::%js-map-get m nan-b) :to-equal "first")
      (cl-cc/javascript::%js-map-set m nan-b "second")
      (expect (= 1 (cl-cc/javascript::%js-map-size m)) :to-be-truthy)
      (expect (cl-cc/javascript::%js-map-get m nan-a) :to-equal "second")
      (expect (cl-cc/javascript::%js-map-delete m nan-b) :to-be-truthy)
      (expect (zerop (cl-cc/javascript::%js-map-size m)) :to-be-truthy)
      (cl-cc/javascript::%js-map-set m 0.0d0 "zero")
      (cl-cc/javascript::%js-map-set m -0.0d0 "neg-zero")
      (expect (= 1 (cl-cc/javascript::%js-map-size m)) :to-be-truthy)
      (expect (cl-cc/javascript::%js-map-get m 0.0d0) :to-equal "neg-zero")
      (expect (cl-cc/javascript::%js-map-get m -0.0d0) :to-equal "neg-zero")))
  (it-sequential "js-rt-map-for-each-order"
    (let ((m    (cl-cc/javascript::%js-make-map))
          (seen nil))
      (cl-cc/javascript::%js-map-set m "a" 1)
      (cl-cc/javascript::%js-map-set m "b" 2)
      (cl-cc/javascript::%js-map-set m "c" 3)
      (cl-cc/javascript::%js-map-for-each m
        (lambda (v k &rest _) (declare (ignore _)) (push (cons k v) seen)))
      (expect (nreverse seen) :to-equal '(("a" . 1) ("b" . 2) ("c" . 3)))))
  (it-sequential "js-rt-map-clear"
    (let ((m (cl-cc/javascript::%js-make-map)))
      (cl-cc/javascript::%js-map-set m "a" 1)
      (cl-cc/javascript::%js-map-clear m)
      (expect (zerop (cl-cc/javascript::%js-map-size m)) :to-be-truthy)))
  (it-sequential "js-rt-map-get-or-insert"
    (let ((m (cl-cc/javascript::%js-make-map)))
      (cl-cc/javascript::%js-map-set m "a" 1)
      (expect (= 1 (cl-cc/javascript/objects:%js-map-get-or-insert m "a" 99)) :to-be-truthy)
      (expect (= 1 (cl-cc/javascript::%js-map-get m "a")) :to-be-truthy)
      (expect (= 7 (cl-cc/javascript/objects:%js-map-get-or-insert m "b" 7)) :to-be-truthy)
      (expect (= 7 (cl-cc/javascript::%js-map-get m "b")) :to-be-truthy)))
  (it-sequential "js-rt-map-get-or-insert-computed"
    (let ((m (cl-cc/javascript::%js-make-map))
          (calls 0))
      (cl-cc/javascript::%js-map-set m "a" 1)
      (expect (= 1 (cl-cc/javascript/objects:%js-map-get-or-insert-computed
                 m "a"
                 (lambda (k)
                   (declare (ignore k))
                   (incf calls)
                   99))) :to-be-truthy)
      (expect (zerop calls) :to-be-truthy)
      (expect (= 10 (cl-cc/javascript/objects:%js-map-get-or-insert-computed
                 m "b"
                 (lambda (k)
                   (declare (ignore k))
                   (incf calls)
                   10))) :to-be-truthy)
      (expect (= 1 calls) :to-be-truthy)
      (expect (= 10 (cl-cc/javascript::%js-map-get m "b")) :to-be-truthy)))
  (it-sequential "js-rt-map-get-or-insert-computed-reentrant"
    (let ((m (cl-cc/javascript::%js-make-map))
          (calls 0))
      (expect (= 20 (cl-cc/javascript/objects:%js-map-get-or-insert-computed
                 m "a"
                 (lambda (k)
                   (incf calls)
                   (cl-cc/javascript::%js-map-set m k 20)
                   99))) :to-be-truthy)
      (expect (= 1 calls) :to-be-truthy)
      (expect (= 20 (cl-cc/javascript::%js-map-get m "a")) :to-be-truthy)))
  )

;;; ─── Map built-ins ───────────────────────────────────────────────────────────

;;; ─── Generator / yield ───────────────────────────────────────────────────────

;;; ─── BigInt operations ───────────────────────────────────────────────────────

