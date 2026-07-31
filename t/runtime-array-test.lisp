;;;; t/runtime-array-test.lisp
;;;;
;;;; Array operations (push/pop/shift/map/filter/reduce/sort/flat/splice …)
;;;; and ES2023 non-mutating variants (toReversed/toSorted/with/toSpliced).
;;;; TypedArray construction/access and remaining array-method coverage split
;;;; out to runtime-array-coverage-test.lisp once this file passed the org's
;;;; 500-line cap.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list)

(in-package :cl-cc-javascript/test)

;;; ─── Array core ──────────────────────────────────────────────────────────────

(it-sequential "js-rt-array-make-and-index"
  (let ((a (%jr-arr 10 20 30)))
    (expect (= 3 (length a)) :to-be-truthy)
    (expect (= 10 (aref a 0)) :to-be-truthy)
    (expect (= 30 (aref a 2)) :to-be-truthy)))

(it-sequential "js-rt-array-push-pop"
  (let ((a (%jr-arr 1 2)))
    (expect (= 3 (cl-cc/javascript::%js-array-push a 3)) :to-be-truthy)
    (expect (= 3 (aref a 2)) :to-be-truthy)
    (expect (= 3 (cl-cc/javascript::%js-array-pop a)) :to-be-truthy)
    (expect (= 2 (length a)) :to-be-truthy)))

(it-sequential "js-rt-array-pop-empty-is-undefined"
  (expect (cl-cc/javascript::%js-array-pop (%jr-arr)) :to-be-js-undefined))

(it-sequential "js-rt-array-map-filter"
  (let ((doubled (cl-cc/javascript::%js-array-map
                  (%jr-arr 1 2 3)
                  (lambda (x &rest _) (declare (ignore _)) (* x 2))))
        (evens   (cl-cc/javascript::%js-array-filter
                  (%jr-arr 1 2 3 4)
                  (lambda (x &rest _) (declare (ignore _)) (evenp x)))))
    (expect (%jr-list doubled) :to-equal '(2 4 6))
    (expect (%jr-list evens) :to-equal '(2 4))))

(it-sequential "js-rt-array-reduce"
  (expect (= 10 (cl-cc/javascript::%js-array-reduce
             (%jr-arr 1 2 3 4)
             (lambda (acc x &rest _) (declare (ignore _)) (+ acc x))
             0)) :to-be-truthy))

(it-sequential-each ((2 t) (9 nil))
    "js-rt-array-includes ~A"
    (needle expected)
  (expect (cl-cc/javascript::%js-array-includes (%jr-arr 1 2 3) needle) :to-equal expected))

(it-sequential "js-rt-array-includes-same-value-zero"
  (let ((nan-a cl-cc/javascript::*js-nan-float*)
        (nan-b cl-cc/javascript::+js-nan+))
    (expect (cl-cc/javascript::%js-array-includes (%jr-arr nan-a) nan-b) :to-be-truthy)
    (expect (cl-cc/javascript::%js-array-includes (%jr-arr -0.0d0) 0.0d0) :to-be-truthy)))

(it-sequential-each ((6 1) (9 -1))
    "js-rt-array-index-of ~A"
    (needle expected)
  (expect (= expected (cl-cc/javascript::%js-array-index-of (%jr-arr 5 6 7) needle)) :to-be-truthy))

(it-sequential "js-rt-array-index-of-does-not-match-nan"
  (let ((nan-a cl-cc/javascript::*js-nan-float*)
        (nan-b cl-cc/javascript::+js-nan+))
    (expect (= -1 (cl-cc/javascript::%js-array-index-of (%jr-arr nan-a) nan-b)) :to-be-truthy)
    (expect (= -1 (cl-cc/javascript::%js-array-last-index-of (%jr-arr nan-a) nan-b)) :to-be-truthy)))

(it-sequential "js-rt-array-join"
  (expect (cl-cc/javascript::%js-array-join (%jr-arr 1 2 3)) :to-equal "1,2,3")
  (expect (cl-cc/javascript::%js-array-join (%jr-arr 1 2 3) "-") :to-equal "1-2-3"))

(it-sequential "js-rt-array-shift-unshift"
  (let ((a (%jr-arr 1 2 3)))
    (expect (= 1 (cl-cc/javascript::%js-array-shift a)) :to-be-truthy)
    (expect (%jr-list a) :to-equal '(2 3))
    (expect (= 4 (cl-cc/javascript::%js-array-unshift a 0 1)) :to-be-truthy)
    (expect (%jr-list a) :to-equal '(0 1 2 3))))

(it-sequential "js-rt-array-some-every"
  (let ((pred (lambda (x &rest _) (declare (ignore _)) (evenp x))))
    (expect (cl-cc/javascript::%js-array-some  (%jr-arr 1 2 3) pred) :to-be-truthy)
    (expect (cl-cc/javascript::%js-array-some  (%jr-arr 1 3 5) pred) :to-be-falsy)
    (expect (cl-cc/javascript::%js-array-every (%jr-arr 2 4 6) pred) :to-be-truthy)
    (expect (cl-cc/javascript::%js-array-every (%jr-arr 2 3 4) pred) :to-be-falsy)))

(it-sequential "js-rt-array-find-and-find-index"
  (let ((arr (%jr-arr 1 4 9 16)))
    (expect (= 4 (cl-cc/javascript::%js-array-find
                   arr (lambda (x &rest _) (declare (ignore _)) (> x 3)))) :to-be-truthy)
    (expect (= 1 (cl-cc/javascript::%js-array-find-index
                   arr (lambda (x &rest _) (declare (ignore _)) (> x 3)))) :to-be-truthy)
    (expect (cl-cc/javascript::%js-array-find
                arr (lambda (x &rest _) (declare (ignore _)) (> x 100))) :to-be-js-undefined)))

(it-sequential "js-rt-array-slice"
  (let* ((a   (%jr-arr 10 20 30 40))
         (s1  (cl-cc/javascript::%js-array-slice a 1 3))
         (s2  (cl-cc/javascript::%js-array-slice a 2)))
    (expect (%jr-list s1) :to-equal '(20 30))
    (expect (%jr-list s2) :to-equal '(30 40))
    (expect (= 4 (length a)) :to-be-truthy)))    ; original untouched

(it-sequential "js-rt-array-slice-coerces-relative-indices"
  (let* ((a (%jr-arr 10 20 30 40))
         (r (cl-cc/javascript::%js-array-slice a "-3" -1.2d0)))
    (expect (%jr-list r) :to-equal '(20 30))))

(it-sequential "js-rt-array-splice-delete-insert"
  (let ((a (%jr-arr 1 2 3 4 5)))
    (cl-cc/javascript::%js-array-splice a 1 2 9 9)
    (expect (%jr-list a) :to-equal '(1 9 9 4 5))))

(it-sequential "js-rt-array-splice-coerces-indices"
  (let* ((coerced (%jr-arr 1 2 3 4))
         (omitted (%jr-arr 1 2 3 4))
         (undefined-count (%jr-arr 1 2 3 4))
         (removed (cl-cc/javascript::%js-array-splice coerced "-3" 1.9d0 9))
         (removed-tail (cl-cc/javascript::%js-array-splice omitted "2"))
         (removed-none (cl-cc/javascript::%js-array-splice
                        undefined-count 1 cl-cc/javascript::+js-undefined+ 9)))
    (expect (%jr-list removed) :to-equal '(2))
    (expect (%jr-list coerced) :to-equal '(1 9 3 4))
    (expect (%jr-list removed-tail) :to-equal '(3 4))
    (expect (%jr-list omitted) :to-equal '(1 2))
    (expect (%jr-list removed-none) :to-equal '())
    (expect (%jr-list undefined-count) :to-equal '(1 9 2 3 4))))

(it-sequential "js-rt-array-concat"
  (let* ((a (%jr-arr 1 2))
         (b (%jr-arr 3 4))
         (r (cl-cc/javascript::%js-array-concat a b (%jr-arr 5))))
    (expect (%jr-list r) :to-equal '(1 2 3 4 5))
    (expect (= 2 (length a)) :to-be-truthy)))   ; originals untouched

(it-sequential "js-rt-array-reverse"
  (let ((a (%jr-arr 1 2 3)))
    (let ((r (cl-cc/javascript::%js-array-reverse a)))
      (expect (%jr-list r) :to-equal '(3 2 1))
      (expect r :to-be a))))         ; same object

(it-sequential "js-rt-array-sort-default"
  (let* ((a (%jr-arr 9 10 2))
         (r (cl-cc/javascript::%js-array-sort a)))
    (expect (%jr-list r) :to-equal '(10 2 9))   ; lexicographic
    (expect r :to-be a)))

(it-sequential "js-rt-array-sort-numeric"
  (let* ((a (%jr-arr 10 2 30))
         (r (cl-cc/javascript::%js-array-sort
             a (lambda (x y &rest _) (declare (ignore _)) (- x y)))))
    (expect (%jr-list r) :to-equal '(2 10 30))))

(it-sequential "js-rt-array-sort-undefined-always-last-default-comparator"
  ;; Real JS: `[undefined, "zebra", "apple"].sort()` -> ["apple", "zebra",
  ;; undefined] -- undefined elements are ALWAYS moved to the end,
  ;; unconditionally, never compared at all (ECMA-262 SortCompare). Chosen
  ;; deliberately so a "zebra" > "apple" > "undefined" (%js-to-string of
  ;; +js-undefined+) lexicographic sort would put undefined in the MIDDLE
  ;; instead of last, unlike a case (e.g. all-lowercase test strings after
  ;; 'u') where it would land last anyway and mask the bug.
  (let* ((a (%jr-arr cl-cc/javascript::+js-undefined+ "zebra" "apple"))
         (r (cl-cc/javascript::%js-array-sort a)))
    (expect (%jr-list r) :to-equal (list "apple" "zebra" cl-cc/javascript::+js-undefined+))))

(it-sequential "js-rt-array-sort-undefined-never-reaches-custom-comparator"
  ;; A custom compareFn must never be CALLED with undefined as either
  ;; argument (ECMA-262 SortCompare excludes undefined from comparison
  ;; entirely) -- a numeric comparator like (a,b)=>a-b would otherwise see
  ;; %js-to-number(undefined) = NaN and misbehave. Assert this by using a
  ;; comparator that ERRORS if ever called with +js-undefined+.
  (let* ((a (%jr-arr 3 cl-cc/javascript::+js-undefined+ 1 2))
         (r (cl-cc/javascript::%js-array-sort
             a (lambda (x y &rest _)
                 (declare (ignore _))
                 (when (or (eq x cl-cc/javascript::+js-undefined+)
                           (eq y cl-cc/javascript::+js-undefined+))
                   (error "comparator called with undefined"))
                 (- x y)))))
    (expect (%jr-list r) :to-equal (list 1 2 3 cl-cc/javascript::+js-undefined+))))

(it-sequential "js-rt-array-to-sorted-undefined-always-last"
  (let* ((a (%jr-arr cl-cc/javascript::+js-undefined+ "zebra" "apple"))
         (r (cl-cc/javascript::%js-array-to-sorted a)))
    (expect (%jr-list r) :to-equal (list "apple" "zebra" cl-cc/javascript::+js-undefined+))
    (expect-not r :to-be a)))          ; non-mutating: fresh array

(it-sequential "js-rt-array-flat"
  (let ((nested (%jr-arr 1 (%jr-arr 2 3) (%jr-arr 4 (%jr-arr 5)))))
    (expect (%jr-list (cl-cc/javascript::%js-array-flat nested 2)) :to-equal '(1 2 3 4 5))
    (let ((shallow (%jr-arr 1 (%jr-arr 2 3) (%jr-arr 4 (%jr-arr 5)))))
      ;; depth 1: [1, 2, 3, 4, [5]] — inner [5] stays nested
      (expect (= 5 (length (%jr-list (cl-cc/javascript::%js-array-flat shallow 1)))) :to-be-truthy))))

(it-sequential "js-rt-array-flat-infinity-depth"
  ;; `arr.flat(Infinity)` -- the idiomatic "flatten fully, however deep" call
  ;; -- passes JS's real `Infinity` value straight through as DEPTH (no
  ;; coercion at the "flat" method-table entry; see *JS-INF-FLOAT*, the real
  ;; IEEE-754 double-float bit pattern the global `Infinity` identifier
  ;; resolves to, NOT the separate :js-infinity keyword sentinel some other
  ;; code paths use). Never previously tested with anything but a small
  ;; integer depth -- confirms %JS-ARRAY-FLAT's (PLUSP D)/(1- D) countdown
  ;; genuinely works on a real double-float infinity (stays positive and
  ;; keeps recursing through every level, exactly "flatten fully").
  (let ((deep (%jr-arr 1 (%jr-arr 2 (%jr-arr 3 (%jr-arr 4 (%jr-arr 5)))))))
    (expect (%jr-list (cl-cc/javascript::%js-array-flat deep cl-cc/javascript::*js-inf-float*))
            :to-equal '(1 2 3 4 5))))

(it-sequential "js-rt-array-last-index-of"
  (let ((a (%jr-arr 1 2 3 2 1)))
    (expect (= 3 (cl-cc/javascript::%js-array-last-index-of a 2)) :to-be-truthy)
    (expect (= -1 (cl-cc/javascript::%js-array-last-index-of a 9)) :to-be-truthy)))

(it-sequential "js-rt-array-search-from-coerces-indices"
  (let ((a (%jr-arr 1 2 3 2 1)))
    (expect (cl-cc/javascript::%js-array-includes a 2 "-4") :to-be-truthy)
    (expect (= 3 (cl-cc/javascript::%js-array-index-of a 2 2.8d0)) :to-be-truthy)
    (expect (= 1 (cl-cc/javascript::%js-array-last-index-of a 2 -3.2d0)) :to-be-truthy)))

(it-sequential "js-rt-array-last-index-of-from-before-start"
  (let ((a (%jr-arr 1 2 1)))
    (expect (= -1 (cl-cc/javascript::%js-array-last-index-of a 1 -99)) :to-be-truthy)
    (expect (zerop (cl-cc/javascript::%js-array-last-index-of
                 a 1 cl-cc/javascript::+js-undefined+)) :to-be-truthy)))

(it-sequential "js-rt-array-fill"
  (let* ((a (%jr-arr 1 2 3 4 5))
         (r (cl-cc/javascript::%js-array-fill a 0 1 3)))
    (expect (%jr-list r) :to-equal '(1 0 0 4 5))
    (expect r :to-be a)))           ; mutated in place

(it-sequential "js-rt-array-fill-coerces-relative-indices"
  (let ((a (%jr-arr 1 2 3 4)))
    (cl-cc/javascript::%js-array-fill a "x" "-3" 3.8d0)
    (expect (%jr-list a) :to-equal '(1 "x" "x" 4))))

(it-sequential "js-rt-array-reduce-right"
  (let ((result (cl-cc/javascript::%js-array-reduce-right
                 (%jr-arr 1 2 3 4)
                 (lambda (acc x &rest _) (declare (ignore _)) (cons x acc))
                 nil)))
    (expect result :to-equal '(1 2 3 4))))

;;; ─── ES2023 non-mutating array methods ──────────────────────────────────────

(it-sequential "js-rt-array-to-reversed"
  (let* ((orig (%jr-arr 1 2 3))
         (rev  (cl-cc/javascript::%js-array-to-reversed orig)))
    (expect (%jr-list rev) :to-equal '(3 2 1))
    (expect (%jr-list orig) :to-equal '(1 2 3))))

(it-sequential "js-rt-array-to-sorted"
  (let* ((orig (%jr-arr 3 1 2))
         (srt  (cl-cc/javascript::%js-array-to-sorted orig)))
    (expect (%jr-list srt) :to-equal '(1 2 3))
    (expect (%jr-list orig) :to-equal '(3 1 2))))

(it-sequential-each ((1 99 (10 99 30))
                     (-1 99 (10 20 99))
                     ("1" 99 (10 99 30))
                     (-1.8d0 99 (10 20 99)))
    "js-rt-array-with ~A"
    (idx val expected)
  (expect (%jr-list (cl-cc/javascript::%js-array-with (%jr-arr 10 20 30) idx val)) :to-equal expected))

(it-sequential-each ((3) (-4))
    "js-rt-array-with-out-of-bounds ~A"
    (idx)
  (handler-case
      (progn
        (cl-cc/javascript::%js-array-with (%jr-arr 10 20 30) idx 99)
        (expect t :to-be-falsy))
    (cl-cc/javascript:js-exception (c)
      (let ((err (cl-cc/javascript:js-exception-value c)))
        (expect (gethash "name" err) :to-equal "RangeError")))))

(it-sequential-each ((1 20) (-1 30) ("1" 20) (-1.8d0 30))
    "js-rt-array-at ~A"
    (idx expected)
  (let ((a (%jr-arr 10 20 30))
      (undef cl-cc/javascript::+js-undefined+))
  (let ((got (cl-cc/javascript::%js-array-at a idx)))
    (if (eq expected :js-undefined)
        (expect got :to-be undef)
        (expect (= expected got) :to-be-truthy)))))

(it-sequential "js-rt-array-at oob"
  (destructuring-bind (idx expected) (list 9 :js-undefined)
    (let ((a (%jr-arr 10 20 30))
        (undef cl-cc/javascript::+js-undefined+))
    (let ((got (cl-cc/javascript::%js-array-at a idx)))
      (if (eq expected :js-undefined)
          (expect got :to-be undef)
          (expect (= expected got) :to-be-truthy))))))

(it-sequential "js-rt-array-find-last"
  (let ((result (cl-cc/javascript::%js-array-find-last
                 (%jr-arr 1 2 3 4)
                 (lambda (x &rest _) (declare (ignore _)) (evenp x)))))
    (expect (= 4 result) :to-be-truthy)))

(it-sequential "js-rt-array-find-last-index"
  (let ((result (cl-cc/javascript::%js-array-find-last-index
                 (%jr-arr 1 2 3 4)
                 (lambda (x &rest _) (declare (ignore _)) (evenp x)))))
    (expect (= 3 result) :to-be-truthy)))

(it-sequential "js-rt-array-to-spliced"
  (let* ((orig (%jr-arr 1 2 3 4))
         (result (cl-cc/javascript::%js-array-to-spliced orig 1 2 9 9)))
    (expect (%jr-list result) :to-equal '(1 9 9 4))
    (expect (%jr-list orig) :to-equal '(1 2 3 4))))

(it-sequential "js-rt-array-to-spliced-coerces-indices"
  (let* ((orig (%jr-arr 1 2 3 4))
         (coerced (cl-cc/javascript::%js-array-to-spliced orig "1" "2" 9))
         (omitted (cl-cc/javascript::%js-array-to-spliced orig "2")))
    (expect (%jr-list coerced) :to-equal '(1 9 4))
    (expect (%jr-list omitted) :to-equal '(1 2))
    (expect (%jr-list orig) :to-equal '(1 2 3 4))))

(it-sequential "js-rt-array-of"
  (expect (%jr-list (cl-cc/javascript::%js-array-of 5 6 7)) :to-equal '(5 6 7)))
