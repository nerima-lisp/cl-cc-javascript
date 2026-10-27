;;;; t/runtime-collections-iterators-test.lisp
;;;;
;;;; Split from runtime-collections-test.lisp: Iterator helper protocol
;;;; methods — map/filter, take/drop, reduce, some/every, find, forEach,
;;;; flatMap, concat, and the zip / zip-keyed family (including their
;;;; padding-mode and strict-mode error paths).
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list, %jr-set)

(in-package #:cl-cc/javascript/iterators/test)

;;; ─── Iterator helpers ────────────────────────────────────────────────────────

(defun %register-iterators-runtime-collections-iterators-tests ()
  (it-sequential "js-rt-iterator-map-filter"
    (let* ((iter  (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2 3 4)))
           (evens (cl-cc/javascript::%js-iterator-filter
                   iter (lambda (x &rest _) (declare (ignore _)) (evenp x))))
           (doubled (cl-cc/javascript::%js-iterator-map
                     (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2 3))
                     (lambda (x &rest _) (declare (ignore _)) (* x 2)))))
      (expect (%jr-list (cl-cc/javascript::%js-iterator-to-array evens)) :to-equal '(2 4))
      (expect (%jr-list (cl-cc/javascript::%js-iterator-to-array doubled)) :to-equal '(2 4 6))))
  (it-sequential "js-rt-iterator-take-drop"
    (let* ((src (%jr-arr 10 20 30 40 50))
           (taken (cl-cc/javascript::%js-iterator-to-array
                   (cl-cc/javascript::%js-iterator-take
                    (cl-cc/javascript::%js-vec-to-iter src) 3)))
           (dropped (cl-cc/javascript::%js-iterator-to-array
                     (cl-cc/javascript::%js-iterator-drop
                      (cl-cc/javascript::%js-vec-to-iter src) 2))))
      (expect (%jr-list taken) :to-equal '(10 20 30))
      (expect (%jr-list dropped) :to-equal '(30 40 50))))
  (it-sequential "js-rt-iterator-reduce"
    (let* ((iter (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2 3 4)))
           (sum  (cl-cc/javascript::%js-iterator-reduce
                  iter (lambda (a b &rest _) (declare (ignore _)) (+ a b)) 0)))
      (expect (= 10 sum) :to-be-truthy)))
  (it-sequential-each ((cl-cc/javascript::%js-iterator-some (1 3 4) t)
                       (cl-cc/javascript::%js-iterator-some (1 3 5) nil)
                       (cl-cc/javascript::%js-iterator-every (2 4 6) t)
                       (cl-cc/javascript::%js-iterator-every (2 3 6) nil))
      "js-rt-iterator-some-every ~A ~A"
      (fn vals expected)
    (let ((iter (cl-cc/javascript::%js-vec-to-iter (apply #'%jr-arr vals))))
      (expect (funcall fn iter (lambda (x &rest _) (declare (ignore _)) (evenp x))) :to-equal expected)))
  (it-sequential "js-rt-iterator-find"
    (let* ((found    (cl-cc/javascript::%js-iterator-find
                      (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 3 4 5))
                      (lambda (x &rest _) (declare (ignore _)) (evenp x))))
           (not-found (cl-cc/javascript::%js-iterator-find
                       (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 3 5))
                       (lambda (x &rest _) (declare (ignore _)) (evenp x)))))
      (expect (= 4 found) :to-be-truthy)
      (expect not-found :to-be-js-undefined)))
  (it-sequential "js-rt-iterator-for-each"
    (let ((seen nil))
      (cl-cc/javascript::%js-iterator-for-each
       (cl-cc/javascript::%js-vec-to-iter (%jr-arr 10 20 30))
       (lambda (x &rest _) (declare (ignore _)) (push x seen)))
      (expect (nreverse seen) :to-equal '(10 20 30))))
  (it-sequential "js-rt-iterator-flat-map"
    (let* ((iter   (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2 3)))
           (result (cl-cc/javascript::%js-iterator-to-array
                    (cl-cc/javascript::%js-iterator-flat-map
                     iter
                     (lambda (x &rest _) (declare (ignore _)) (%jr-arr x (* x 10)))))))
      (expect (%jr-list result) :to-equal '(1 10 2 20 3 30))))
  (it-sequential "js-rt-iterator-concat"
    (let* ((result (cl-cc/javascript::%js-iterator-to-array
                    (cl-cc/javascript/iterators:%js-iterator-concat
                     (%jr-arr 1 2)
                     "ab"
                     (%jr-set 9))))
           (values (%jr-list result)))
      (expect values :to-equal '(1 2 "a" "b" 9))))
  (it-sequential "js-rt-iterator-concat-empty"
    (multiple-value-bind (value done)
        (cl-cc/javascript::%js-iter-next (cl-cc/javascript/iterators:%js-iterator-concat))
      (declare (ignore value))
      (expect done :to-be-truthy)))
  (it-sequential "js-rt-iterator-zip"
    (let* ((rows (cl-cc/javascript::%js-iterator-to-array
                  (cl-cc/javascript/iterators:%js-iterator-zip
                   (%jr-arr (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2 3))
                             (cl-cc/javascript::%js-vec-to-iter (%jr-arr 10 20))))))
           (lists (mapcar #'%jr-list (%jr-list rows))))
      (expect lists :to-equal '((1 10) (2 20)))))
  (it-sequential "js-rt-iterator-zip-longest"
    (let* ((rows (cl-cc/javascript::%js-iterator-to-array
                  (cl-cc/javascript/iterators:%js-iterator-zip
                   (%jr-arr (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2 3))
                            (cl-cc/javascript::%js-vec-to-iter (%jr-arr 10 20)))
                   (cl-cc/javascript::%js-make-object
                    "mode" "longest"
                    "padding" (%jr-arr 0 9)))))
           (lists (mapcar #'%jr-list (%jr-list rows))))
      (expect lists :to-equal '((1 10) (2 20) (3 9)))))
  (it-sequential "js-rt-iterator-zip-longest-default-padding"
    (let* ((rows (cl-cc/javascript::%js-iterator-to-array
                  (cl-cc/javascript/iterators:%js-iterator-zip
                   (%jr-arr (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2))
                            (cl-cc/javascript::%js-vec-to-iter (%jr-arr 10)))
                   (cl-cc/javascript::%js-make-object "mode" "longest"))))
           (first (aref rows 0))
           (second (aref rows 1)))
      (expect (= 1 (aref first 0)) :to-be-truthy)
      (expect (= 10 (aref first 1)) :to-be-truthy)
      (expect (= 2 (aref second 0)) :to-be-truthy)
      (expect (aref second 1) :to-be-js-undefined)))
  (it-sequential "js-rt-iterator-zip-invalid-options"
    (expect-rejects
        (lambda ()
          (cl-cc/javascript/iterators:%js-iterator-zip
           (%jr-arr (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1)))
           42.0d0))
      :to-be-instance-of 'cl-cc/javascript:js-exception))
  (it-sequential "js-rt-iterator-zip-invalid-mode"
    (expect-rejects
        (lambda ()
          (cl-cc/javascript/iterators:%js-iterator-zip
           (%jr-arr (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1)))
           (cl-cc/javascript::%js-make-object "mode" "middle")))
      :to-be-instance-of 'cl-cc/javascript:js-exception))
  (it-sequential "js-rt-iterator-zip-primitive-padding"
    (expect-rejects
        (lambda ()
          (cl-cc/javascript/iterators:%js-iterator-zip
           (%jr-arr (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2))
                    (cl-cc/javascript::%js-vec-to-iter (%jr-arr 10)))
           (cl-cc/javascript::%js-make-object
            "mode" "longest"
            "padding" 1.0d0)))
      :to-be-instance-of 'cl-cc/javascript:js-exception))
  (it-sequential "js-rt-iterator-zip-strict-signals"
    (let ((iter (cl-cc/javascript/iterators:%js-iterator-zip
                 (%jr-arr (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2))
                          (cl-cc/javascript::%js-vec-to-iter (%jr-arr 10)))
                 (cl-cc/javascript::%js-make-object "mode" "strict"))))
      (multiple-value-bind (row done) (cl-cc/javascript::%js-iter-next iter)
        (declare (ignore row))
        (expect done :to-be-falsy))
      (expect-rejects (lambda () (cl-cc/javascript::%js-iter-next iter))
        :to-be-instance-of 'cl-cc/javascript:js-exception)))
  (it-sequential "js-rt-iterator-zip-keyed"
    (let* ((sources (cl-cc/javascript::%js-make-object
                     "left" (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2))
                     "right" (cl-cc/javascript::%js-vec-to-iter (%jr-arr 10))))
           (rows (cl-cc/javascript::%js-iterator-to-array
                  (cl-cc/javascript/iterators:%js-iterator-zip-keyed
                   sources
                   (cl-cc/javascript::%js-make-object
                    "mode" "longest"
                    "padding" (cl-cc/javascript::%js-make-object "left" 0 "right" 9)))))
           (first (aref rows 0))
           (second (aref rows 1)))
      (expect (cl-cc/javascript::%js-object-get-prototype-of first) :to-be cl-cc/javascript/objects:+js-null+)
      (expect (= 1 (gethash "left" first)) :to-be-truthy)
      (expect (= 10 (gethash "right" first)) :to-be-truthy)
      (expect (= 2 (gethash "left" second)) :to-be-truthy)
      (expect (= 9 (gethash "right" second)) :to-be-truthy)))
  (it-sequential "js-rt-iterator-zip-keyed-longest-missing-padding"
    (let* ((sources (cl-cc/javascript::%js-make-object
                     "left" (cl-cc/javascript::%js-vec-to-iter (%jr-arr 1 2))
                     "right" (cl-cc/javascript::%js-vec-to-iter (%jr-arr 10))))
           (rows (cl-cc/javascript::%js-iterator-to-array
                  (cl-cc/javascript/iterators:%js-iterator-zip-keyed
                   sources
                   (cl-cc/javascript::%js-make-object
                    "mode" "longest"
                    "padding" (cl-cc/javascript::%js-make-object "left" 0)))))
           (first (aref rows 0))
           (second (aref rows 1)))
      (expect (= 1 (gethash "left" first)) :to-be-truthy)
      (expect (= 10 (gethash "right" first)) :to-be-truthy)
      (expect (= 2 (gethash "left" second)) :to-be-truthy)
      (expect (gethash "right" second) :to-be-js-undefined)))
  (it-sequential "js-rt-iterator-zip-keyed-undefined-source"
    (expect-rejects
        (lambda ()
          (cl-cc/javascript/iterators:%js-iterator-zip-keyed
           (cl-cc/javascript::%js-make-object
            "left" cl-cc/javascript/objects:+js-undefined+
            "right" (cl-cc/javascript::%js-vec-to-iter (%jr-arr 10)))
           (cl-cc/javascript::%js-make-object "mode" "shortest")))
      :to-be-instance-of 'cl-cc/javascript:js-exception))
  (it-sequential "js-rt-iterator-zip-keyed-non-object"
    (expect-rejects
        (lambda ()
          (cl-cc/javascript/iterators:%js-iterator-zip-keyed
           42.0d0
           (cl-cc/javascript::%js-make-object "mode" "shortest")))
      :to-be-instance-of 'cl-cc/javascript:js-exception))
  (it-sequential "js-rt-iter-values-from-array"
    (let* ((arr    (%jr-arr 10 20 30))
           (values (cl-cc/javascript/iterators:%js-iter-values arr)))
      (expect values :to-equal '(10 20 30))))
  (it-sequential "js-rt-iter-values-from-string"
    (expect (cl-cc/javascript/iterators:%js-iter-values "abc") :to-equal '("a" "b" "c")))
  (it-sequential "js-rt-advance-iterator-drains-object"
    (let* ((items '(7 8 9))
           (idx   (list 0))
           (iter  (cl-cc/javascript/objects:%js-make-object
                   "next" (lambda ()
                             (if (< (car idx) (length items))
                                 (prog1 (cl-cc/javascript/objects:%js-make-object
                                         "value" (nth (car idx) items) "done" nil)
                                   (incf (car idx)))
                                 (cl-cc/javascript/objects:%js-make-object
                                  "value" cl-cc/javascript/objects:+js-undefined+ "done" t)))))
           (acc   nil))
      (cl-cc/javascript/iterators:%js-advance-iterator iter (lambda (v) (push v acc)))
      (expect acc :to-equal '(9 8 7))))
  (it-sequential "js-rt-generator-basic"
    (let* ((gen (cl-cc/javascript/iterators:%js-make-generator
                 (lambda ()
                   (cl-cc/javascript/iterators:%js-yield 10)
                   (cl-cc/javascript/iterators:%js-yield 20)
                   (cl-cc/javascript/iterators:%js-yield 30))))
           (arr (cl-cc/javascript/iterators:%js-iterator-to-array gen)))
      (expect (coerce arr (quote list)) :to-equal '(10 20 30))))
  (it-sequential "js-rt-generator-done-after-exhaust"
    (let* ((gen  (cl-cc/javascript/iterators:%js-make-generator
                  (lambda () (cl-cc/javascript/iterators:%js-yield 1))))
           (r1   (cl-cc/javascript/iterators:%js-generator-next gen))
           (r2   (cl-cc/javascript/iterators:%js-generator-next gen)))
      (expect (cl-cc/javascript/objects:%js-get-prop r1 "done") :to-be-falsy)
      (expect (cl-cc/javascript/objects:%js-get-prop r2 "done") :to-be-truthy)))
  (it-sequential "js-rt-map-keys-iterator"
    (let* ((m   (cl-cc/javascript/objects:%js-make-map))
           (acc nil))
      (cl-cc/javascript/objects:%js-map-set m "a" 1)
      (cl-cc/javascript/objects:%js-map-set m "b" 2)
      (cl-cc/javascript/iterators:%js-for-of
       (cl-cc/javascript/objects:%js-map-keys m)
       (lambda (k) (push k acc)))
      (expect acc :to-equal '("b" "a"))))
  (it-sequential "js-rt-map-values-iterator"
    (let* ((m   (cl-cc/javascript/objects:%js-make-map))
           (acc nil))
      (cl-cc/javascript/objects:%js-map-set m "x" 10)
      (cl-cc/javascript/objects:%js-map-set m "y" 20)
      (cl-cc/javascript/iterators:%js-for-of
       (cl-cc/javascript/objects:%js-map-values m)
       (lambda (v) (push v acc)))
      (expect acc :to-equal '(20 10))))
  (it-sequential "js-rt-map-entries-iterator"
    (let* ((m   (cl-cc/javascript/objects:%js-make-map))
           (acc nil))
      (cl-cc/javascript/objects:%js-map-set m "k" 99)
      (cl-cc/javascript/iterators:%js-for-of
       (cl-cc/javascript/objects:%js-map-entries m)
       (lambda (e) (push (list (aref e 0) (aref e 1)) acc)))
      (expect acc :to-equal '(("k" 99)))))
  (it-sequential "js-rt-iterator-from-array"
    (let* ((arr  (%jr-arr 1 2 3))
           (iter (cl-cc/javascript/iterators:%js-iterator-from-iterable arr))
           (acc  nil))
      (cl-cc/javascript/iterators:%js-for-of iter (lambda (v) (push v acc)))
      (expect acc :to-equal '(3 2 1))))
  (it-sequential "js-rt-iterator-from-set"
    (let* ((set (cl-cc/javascript/objects:%js-make-set))
           (_   (cl-cc/javascript/objects:%js-set-add set 3))
           (_   (cl-cc/javascript/objects:%js-set-add set 4))
           (iter (cl-cc/javascript/iterators:%js-iterator-from-iterable set))
           (acc nil))
      (declare (ignore _))
      (cl-cc/javascript/iterators:%js-for-of iter (lambda (v) (push v acc)))
      (expect acc :to-equal '(4 3))))
  (it-sequential "js-rt-iterator-from-map"
    (let* ((map (cl-cc/javascript/objects:%js-make-map))
           (_1  (cl-cc/javascript/objects:%js-map-set map "a" 1))
           (_2  (cl-cc/javascript/objects:%js-map-set map "b" 2))
           (iter (cl-cc/javascript/iterators:%js-iterator-from-iterable map))
           (acc nil))
      (declare (ignore _1 _2))
      (cl-cc/javascript/iterators:%js-for-of iter
                                    (lambda (entry)
                                      (push (%jr-list entry) acc)))
      (expect acc :to-equal '(("b" 2) ("a" 1)))))
  (it-sequential "js-rt-iterator-from-plain-next"
    (let* ((step 0)
           (iterable
             (cl-cc/javascript/objects:%js-make-object
              "next" (lambda ()
                       (prog1
                           (case step
                             (0 (cl-cc/javascript/objects:%js-make-object "value" "first" "done" nil))
                             (1 (cl-cc/javascript/objects:%js-make-object "value" "second" "done" nil))
                             (t (cl-cc/javascript/objects:%js-make-object "value" cl-cc/javascript/objects:+js-undefined+ "done" t)))
                         (incf step)))))
           (iter (cl-cc/javascript/iterators:%js-iterator-from-iterable iterable))
           (acc nil))
      (cl-cc/javascript/iterators:%js-for-of iter (lambda (v) (push v acc)))
      (expect acc :to-equal '("second" "first"))))
  (it-sequential "js-rt-iterator-from-@@iterator"
    (let* ((iterable
             (cl-cc/javascript/objects:%js-make-object
              "@@iterator" (lambda ()
                             (cl-cc/javascript/iterators:%js-vec-to-iter (%jr-arr 8 9)))))
           (iter (cl-cc/javascript/iterators:%js-iterator-from-iterable iterable))
           (acc nil))
      (cl-cc/javascript/iterators:%js-for-of iter (lambda (v) (push v acc)))
      (expect acc :to-equal '(9 8))))
  (it-sequential "js-rt-iterator-from-string"
    (let* ((iter (cl-cc/javascript/iterators:%js-iterator-from-iterable "ab"))
           (acc nil))
      (cl-cc/javascript/iterators:%js-for-of iter (lambda (v) (push v acc)))
      (expect acc :to-equal '("b" "a"))))
  (it-sequential "js-rt-iterator-from-non-iterable"
    (let ((iter (cl-cc/javascript/iterators:%js-iterator-from-iterable
                 (cl-cc/javascript/objects:%js-make-object))))
      (multiple-value-bind (value done) (cl-cc/javascript/iterators:%js-iter-next iter)
        (expect value :to-be-js-undefined)
        (expect done :to-be-truthy))))
  )

