;;;; t/runtime-collections-values-test.lisp
;;;;
;;;; Split from runtime-collections-test.lisp: Promise built-ins (resolve/
;;;; reject/then/all/any/withResolvers), Map built-ins (set/get/has/size,
;;;; SameValueZero keys, forEach order, clear, getOrInsert(Computed),
;;;; groupBy), Generator/yield, and BigInt arithmetic/bitwise/asIntN/asUintN
;;;; operations.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list, %jr-set)

(in-package :cl-cc-javascript/test)

;;; ─── Promise built-ins ───────────────────────────────────────────────────────

(it-sequential "js-rt-promise-resolve-await"
  (let* ((p (cl-cc/javascript::%js-promise-resolve 42))
         (v (cl-cc/javascript::%js-await p)))
    (expect (= 42 v) :to-be-truthy)))

(it-sequential "js-rt-promise-reject-await"
  (let ((p (cl-cc/javascript::%js-promise-reject "oops")))
    (expect-rejects (lambda () (cl-cc/javascript::%js-await p))
      :to-be-instance-of 'cl-cc/javascript:js-exception)))

(it-sequential "js-rt-promise-then"
  (let* ((p (cl-cc/javascript::%js-promise-resolve 5))
         (p2 (cl-cc/javascript::%js-promise-then
              p (lambda (v &rest _) (declare (ignore _)) (* v 2)))))
    (expect (= 10 (cl-cc/javascript::%js-await p2)) :to-be-truthy)))

(it-sequential "js-rt-promise-all"
  (let* ((promises (%jr-arr (cl-cc/javascript::%js-promise-resolve 1)
                            (cl-cc/javascript::%js-promise-resolve 2)
                            (cl-cc/javascript::%js-promise-resolve 3)))
         (result (cl-cc/javascript::%js-await
                  (cl-cc/javascript::%js-promise-all promises))))
    (expect (%jr-list result) :to-equal '(1 2 3))))

(it-sequential "js-rt-promise-any-first-fulfilled"
  (let* ((p1 (cl-cc/javascript::%js-promise-reject "e1"))
         (p2 (cl-cc/javascript::%js-promise-resolve 42))
         (arr (%jr-arr p1 p2))
         (r   (cl-cc/javascript::%js-promise-any arr)))
    (expect (cl-cc/javascript::js-promise-rejected-p r) :to-be-falsy)
    (expect (= 42 (cl-cc/javascript::js-promise-value r)) :to-be-truthy)))

(it-sequential "js-rt-promise-any-all-rejected"
  (let* ((p1 (cl-cc/javascript::%js-promise-reject "e1"))
         (p2 (cl-cc/javascript::%js-promise-reject "e2"))
         (arr (%jr-arr p1 p2))
         (r   (cl-cc/javascript::%js-promise-any arr))
         (err (cl-cc/javascript::js-promise-value r)))
    (expect (cl-cc/javascript::js-promise-rejected-p r) :to-be-truthy)
    ;; Regression: this used to reject with a plain object that merely had
    ;; matching "errors"/"message" properties — instanceof AggregateError
    ;; (and instanceof Error) both failed, unlike real Promise.any.
    (expect (cl-cc/javascript::%js-instanceof
             err cl-cc/javascript::*js-aggregate-error-class*) :to-be-truthy)
    (expect (gethash "message" err) :to-equal "All promises were rejected")
    (expect (%jr-list (gethash "errors" err)) :to-equal '("e1" "e2"))))

(it-sequential "js-rt-promise-with-resolvers"
  (let* ((trio    (cl-cc/javascript::%js-promise-with-resolvers))
         (promise (gethash "promise" trio))
         (resolve (gethash "resolve" trio))
         (reject  (gethash "reject"  trio)))
    (expect (cl-cc/javascript::js-promise-p promise) :to-be-truthy)
    (expect (functionp resolve) :to-be-truthy)
    (expect (functionp reject) :to-be-truthy)
    (funcall resolve 99)
    (expect (= 99 (cl-cc/javascript::js-promise-value promise)) :to-be-truthy)))

;;; ─── Map built-ins ───────────────────────────────────────────────────────────

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
  (let ((nan-a cl-cc/javascript::*js-nan-float*)
        (nan-b cl-cc/javascript::+js-nan+)
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
    (expect (= 1 (cl-cc/javascript::%js-map-get-or-insert m "a" 99)) :to-be-truthy)
    (expect (= 1 (cl-cc/javascript::%js-map-get m "a")) :to-be-truthy)
    (expect (= 7 (cl-cc/javascript::%js-map-get-or-insert m "b" 7)) :to-be-truthy)
    (expect (= 7 (cl-cc/javascript::%js-map-get m "b")) :to-be-truthy)))

(it-sequential "js-rt-map-get-or-insert-computed"
  (let ((m (cl-cc/javascript::%js-make-map))
        (calls 0))
    (cl-cc/javascript::%js-map-set m "a" 1)
    (expect (= 1 (cl-cc/javascript::%js-map-get-or-insert-computed
               m "a"
               (lambda (k)
                 (declare (ignore k))
                 (incf calls)
                 99))) :to-be-truthy)
    (expect (zerop calls) :to-be-truthy)
    (expect (= 10 (cl-cc/javascript::%js-map-get-or-insert-computed
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
    (expect (= 20 (cl-cc/javascript::%js-map-get-or-insert-computed
               m "a"
               (lambda (k)
                 (incf calls)
                 (cl-cc/javascript::%js-map-set m k 20)
                 99))) :to-be-truthy)
    (expect (= 1 calls) :to-be-truthy)
    (expect (= 20 (cl-cc/javascript::%js-map-get m "a")) :to-be-truthy)))

(it-sequential "js-rt-map-group-by"
  (let* ((arr (%jr-arr 1 2 3 4 6))
         (result (cl-cc/javascript::%js-map-group-by
                  arr
                  (lambda (x) (svref #("even" "odd") (mod x 2)))))
         (evens (cl-cc/javascript::%js-map-get result "even"))
         (odds  (cl-cc/javascript::%js-map-get result "odd")))
    (expect (= 3 (length evens)) :to-be-truthy)
    (expect (= 2 (length odds)) :to-be-truthy)))

;;; ─── Generator / yield ───────────────────────────────────────────────────────

(it-sequential "js-rt-generator-basic"
  (let* ((gen (cl-cc/javascript::%js-make-generator
               (lambda ()
                 (cl-cc/javascript::%js-yield 10)
                 (cl-cc/javascript::%js-yield 20)
                 (cl-cc/javascript::%js-yield 30))))
         (arr (cl-cc/javascript::%js-iterator-to-array gen)))
    (expect (%jr-list arr) :to-equal '(10 20 30))))

(it-sequential "js-rt-generator-done-after-exhaust"
  (let* ((gen  (cl-cc/javascript::%js-make-generator
                (lambda () (cl-cc/javascript::%js-yield 1))))
         (r1   (cl-cc/javascript::%js-generator-next gen))
         (r2   (cl-cc/javascript::%js-generator-next gen)))
    (expect (cl-cc/javascript::%js-get-prop r1 "done") :to-be-falsy)
    (expect (cl-cc/javascript::%js-get-prop r2 "done") :to-be-truthy)))

;;; ─── BigInt operations ───────────────────────────────────────────────────────

(it-sequential-each ((42 42) (-7 -7) (10 10) (3 3))
    "js-rt-bigint-val ~A"
    (raw expected)
  (let ((bi (cl-cc/javascript::%make-js-bigint raw)))
    (expect (= expected (cl-cc/javascript::%js-bigint-val bi)) :to-be-truthy)))

(it-sequential-each ((cl-cc/javascript::%js-bigint-add 3 4 7)
                     (cl-cc/javascript::%js-bigint-sub 9 4 5)
                     (cl-cc/javascript::%js-bigint-mul 3 4 12)
                     (cl-cc/javascript::%js-bigint-pow 2 8 256)
                     (cl-cc/javascript::%js-bigint-bitwise-and #b1010 #b1100 #b1000)
                     (cl-cc/javascript::%js-bigint-bitwise-or #b1010 #b1100 #b1110)
                     (cl-cc/javascript::%js-bigint-bitwise-xor #b1010 #b1100 #b0110))
    "js-rt-bigint-arithmetic ~A"
    (fn a b expected)
  (let ((result (funcall fn (cl-cc/javascript::%make-js-bigint a)
                          (cl-cc/javascript::%make-js-bigint b))))
    (expect (= expected (cl-cc/javascript::js-bigint-value result)) :to-be-truthy)))

(it-sequential-each ((cl-cc/javascript::%js-bigint-as-int-n 8 127 127)
                     (cl-cc/javascript::%js-bigint-as-int-n 8 128 -128)
                     (cl-cc/javascript::%js-bigint-as-uint-n 8 300 44))
    "js-rt-bigint-as-int-n-uint-n ~A ~A ~A"
    (fn width val expected)
  (let ((result (funcall fn width (cl-cc/javascript::%make-js-bigint val))))
    (expect (= expected (cl-cc/javascript::js-bigint-value result)) :to-be-truthy)))
