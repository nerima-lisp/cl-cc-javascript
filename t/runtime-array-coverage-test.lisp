;;;; t/runtime-array-coverage-test.lisp
;;;;
;;;; Split from runtime-array-test.lisp once that file passed the org's
;;;; 500-line cap. TypedArray construction/element access, array method
;;;; resolution and iteration (values/@@iterator/entries/keys/copyWithin/
;;;; flatMap), forEach/isArray/Array.from(Async), and ES2024 group/groupToMap.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list)

(in-package :cl-cc-javascript/test)

;;; ─── TypedArray basic operations ─────────────────────────────────────────────

(it-sequential "js-rt-typed-array-make-get-set"
  (let ((ta (cl-cc/javascript::%js-make-typed-array "Int32Array" 3)))
    (cl-cc/javascript::%js-ta-set ta 0 10)
    (cl-cc/javascript::%js-ta-set ta 2 99)
    (expect (= 10 (cl-cc/javascript::%js-ta-get ta 0)) :to-be-truthy)
    (expect (zerop (cl-cc/javascript::%js-ta-get ta 1)) :to-be-truthy)
    (expect (= 99 (cl-cc/javascript::%js-ta-get ta 2)) :to-be-truthy)))

(it-sequential "js-rt-typed-array-length"
  (let ((ta (cl-cc/javascript::%js-make-typed-array "Float64Array" 4)))
    (expect (= 4 (cl-cc/javascript::js-ta-length ta)) :to-be-truthy)))

(it-sequential-each (("Int8Array" 3 3) ("Uint8Array" 5 5) ("Int32Array" 2 2)
                     ("Float16Array" 4 4) ("Float64Array" 1 1))
    "js-rt-typed-array-types ~A"
    (type-name length expected-length)
  (let ((ta (cl-cc/javascript::%js-make-typed-array type-name length)))
    (expect (= expected-length (cl-cc/javascript::js-ta-length ta)) :to-be-truthy)))

(it-sequential "js-rt-method-resolution-array"
  (let* ((arr (%jr-arr 10 20 30))
         (join-fn (cl-cc/javascript::%js-get-prop arr "join")))
    (expect (functionp join-fn) :to-be-truthy)
    (expect (funcall join-fn ",") :to-equal "10,20,30")))

(it-sequential "js-rt-method-resolution-length"
  (let ((arr (%jr-arr 1 2 3)))
    (expect (= 3 (cl-cc/javascript::%js-get-prop arr "length")) :to-be-truthy)))

(it-sequential "js-rt-array-values-via-get-prop"
  (let* ((arr   (%jr-arr 10 20))
         (fn    (cl-cc/javascript::%js-get-prop arr "values"))
         (iter  (funcall fn))
         (next  (gethash "next" iter))
         (r1    (funcall next))
         (r2    (funcall next))
         (done  (funcall next)))
    (expect (= 10 (gethash "value" r1)) :to-be-truthy)
    (expect (= 20 (gethash "value" r2)) :to-be-truthy)
    (expect (gethash "done"  done) :to-be-truthy)))

(it-sequential "js-rt-array-@@iterator-via-get-prop"
  (let* ((arr   (%jr-arr 5 6))
         (fn    (cl-cc/javascript::%js-get-prop arr "@@iterator"))
         (iter  (funcall fn))
         (next  (gethash "next" iter)))
    (expect (functionp next) :to-be-truthy)
    (expect (= 5 (gethash "value" (funcall next))) :to-be-truthy)
    (expect (= 6 (gethash "value" (funcall next))) :to-be-truthy)))

;;; ─── Uncovered array methods ─────────────────────────────────────────────────

(it-sequential "js-rt-array-flat-map"
  (let* ((arr    (%jr-arr 1 2 3))
         (result (cl-cc/javascript::%js-array-flat-map
                  arr (lambda (x &rest _) (declare (ignore _)) (%jr-arr x (* x 10))))))
    (expect (%jr-list result) :to-equal '(1 10 2 20 3 30))))

(it-sequential "js-rt-array-entries"
  (let* ((arr     (%jr-arr "a" "b"))
         (entries (cl-cc/javascript::%js-array-entries arr))
         (next    (gethash "next" entries)))
    (let* ((r0 (funcall next))
           (e0 (gethash "value" r0))
           (r1 (funcall next))
           (e1 (gethash "value" r1))
           (r2 (funcall next)))
      (expect (gethash "done" r0) :to-be-falsy)
      (expect (zerop (aref e0 0)) :to-be-truthy)
      (expect (aref e0 1) :to-equal "a")
      (expect (gethash "done" r1) :to-be-falsy)
      (expect (= 1 (aref e1 0)) :to-be-truthy)
      (expect (aref e1 1) :to-equal "b")
      (expect (gethash "done" r2) :to-be-truthy))))

(it-sequential "js-rt-array-keys"
  (let* ((arr  (%jr-arr "x" "y" "z"))
         (ks   (cl-cc/javascript::%js-array-keys arr))
         (acc  nil))
    (cl-cc/javascript::%js-for-of ks (lambda (k) (push k acc)))
    (expect (nreverse acc) :to-equal '(0 1 2))))

(it-sequential "js-rt-array-copy-within"
  (let ((arr (%jr-arr 1 2 3 4 5)))
    (cl-cc/javascript::%js-array-copy-within arr 0 3 5)
    (expect (= 4 (aref arr 0)) :to-be-truthy)
    (expect (= 5 (aref arr 1)) :to-be-truthy)
    (expect (= 3 (aref arr 2)) :to-be-truthy)))

(it-sequential "js-rt-array-copy-within-coerces-relative-indices"
  (let ((arr (%jr-arr 1 2 3 4)))
    (cl-cc/javascript::%js-array-copy-within arr "-2" "0" 2.9d0)
    (expect (%jr-list arr) :to-equal '(1 2 1 2))))

;;; ─── Coverage: forEach / isArray / Array.from ────────────────────────────────

(it-sequential "js-rt-array-for-each"
  (let ((collected nil))
    (cl-cc/javascript::%js-array-for-each
     (%jr-arr 10 20 30)
     (lambda (x i &rest _) (declare (ignore _)) (push (list i x) collected)))
    (expect collected :to-equal '((2 30) (1 20) (0 10)))
    (expect (cl-cc/javascript::%js-array-for-each (%jr-arr 1) (constantly nil)) :to-be-js-undefined)))

(it-sequential "js-rt-array-is-array"
  (expect (cl-cc/javascript::%js-array-is-array (%jr-arr 1 2)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-array-is-array "not-an-array") :to-be-falsy)
  (expect (cl-cc/javascript::%js-array-is-array 42) :to-be-falsy)
  (expect (cl-cc/javascript::%js-array-is-array cl-cc/javascript::+js-undefined+) :to-be-falsy))

(it-sequential "js-rt-array-from-plain"
  (let ((result (cl-cc/javascript::%js-array-from (%jr-arr 1 2 3))))
    (expect (%jr-list result) :to-equal '(1 2 3))))

(it-sequential "js-rt-array-from-undefined-map-fn"
  (let ((result (cl-cc/javascript::%js-array-from
                 (%jr-arr 1 2 3)
                 cl-cc/javascript::+js-undefined+)))
    (expect (%jr-list result) :to-equal '(1 2 3))))

(it-sequential "js-rt-array-from-with-map"
  (let ((result (cl-cc/javascript::%js-array-from
                 (%jr-arr 1 2 3)
                 (lambda (x &rest _) (declare (ignore _)) (* x 10)))))
    (expect (%jr-list result) :to-equal '(10 20 30))))

(it-sequential "js-rt-array-from-map-fn-receives-index"
  (let ((result (cl-cc/javascript::%js-array-from
                 (%jr-arr 10 20 30)
                 (lambda (x i) (+ x i)))))
    (expect (%jr-list result) :to-equal '(10 21 32))))

(it-sequential "js-rt-array-from-array-like"
  (let* ((source (cl-cc/javascript::%js-make-object "0" "a" "1" "b" "length" 2))
         (result (cl-cc/javascript::%js-array-from source)))
    (expect (%jr-list result) :to-equal '("a" "b"))))

(it-sequential "js-rt-array-from-array-like-missing-index"
  (let* ((source (cl-cc/javascript::%js-make-object "0" "a" "length" 2))
         (result (cl-cc/javascript::%js-array-from source)))
    (expect (%jr-list result) :to-equal (list "a" cl-cc/javascript::+js-undefined+))))

(it-sequential "js-rt-array-from-map-fn-this-arg"
  (let* ((this (cl-cc/javascript::%js-make-object "scale" 10))
         (result (cl-cc/javascript::%js-array-from
                  (%jr-arr 1 2)
                  (lambda (x i)
                    (+ (* x (cl-cc/javascript::%js-get-prop cl-cc/javascript::%js-this "scale"))
                       i))
                  this)))
    (expect (%jr-list result) :to-equal '(10 21))))

(it-sequential "js-rt-array-from-async-awaits-elements"
  (let* ((input  (%jr-arr (cl-cc/javascript::%js-promise-resolve 1)
                          (cl-cc/javascript::%js-promise-resolve 2)
                          3))
         (result (cl-cc/javascript::%js-await
                  (cl-cc/javascript::%js-array-from-async input))))
    (expect (%jr-list result) :to-equal '(1 2 3))))

(it-sequential "js-rt-array-from-async-awaits-map-results"
  (let* ((input  (%jr-arr (cl-cc/javascript::%js-promise-resolve 10)
                          (cl-cc/javascript::%js-promise-resolve 20)))
         (result (cl-cc/javascript::%js-await
                  (cl-cc/javascript::%js-array-from-async
                   input
                   (lambda (x i &rest _) (declare (ignore _))
                     (cl-cc/javascript::%js-promise-resolve (+ x i)))))))
    (expect (%jr-list result) :to-equal '(10 21))))

(it-sequential "js-rt-array-from-async-array-like"
  (let* ((source (cl-cc/javascript::%js-make-object
                  "0" (cl-cc/javascript::%js-promise-resolve 3)
                  "1" 4
                  "length" 2))
         (result (cl-cc/javascript::%js-await
                  (cl-cc/javascript::%js-array-from-async
                   source
                   (lambda (x i)
                     (cl-cc/javascript::%js-promise-resolve (+ x i)))))))
    (expect (%jr-list result) :to-equal '(3 5))))

;;; ─── Coverage: ES2024 group / groupToMap ─────────────────────────────────────

(it-sequential "js-rt-array-group"
  (let* ((arr    (%jr-arr 1 2 3 4))
         (result (cl-cc/javascript::%js-array-group
                  arr (lambda (x &rest _) (declare (ignore _))
                        (if (evenp x) "even" "odd")))))
    (expect (hash-table-p result) :to-be-truthy)
    (expect (%jr-list (gethash "odd"  result)) :to-equal '(1 3))
    (expect (%jr-list (gethash "even" result)) :to-equal '(2 4))))

(it-sequential "js-rt-array-group-to-map"
  (let* ((arr    (%jr-arr 1 2 3 4))
         (result (cl-cc/javascript::%js-array-group-to-map
                  arr (lambda (x &rest _) (declare (ignore _))
                        (if (evenp x) "even" "odd")))))
    (expect (cl-cc/javascript::%js-map-p result) :to-be-truthy)
    (expect (%jr-list (cl-cc/javascript::%js-map-get result "odd")) :to-equal '(1 3))
    (expect (%jr-list (cl-cc/javascript::%js-map-get result "even")) :to-equal '(2 4))))
