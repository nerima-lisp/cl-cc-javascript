;;;; t/runtime-collections-set-test.lisp
;;;;
;;;; Split from runtime-collections-test.lisp: Set built-ins (add/has/delete/
;;;; clear, SameValueZero semantics, and the Set union/intersection/
;;;; difference/subset/superset/disjoint operations, including their
;;;; set-like-object overloads).
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list, %jr-set)

(in-package :cl-cc-javascript/test)

;;; ─── Set built-ins ───────────────────────────────────────────────────────────

(defun %jr-set-like (&rest values)
  (let ((entries (make-array (length values)
                             :element-type t
                             :adjustable t
                             :fill-pointer (length values)
                             :initial-contents values)))
    (cl-cc/javascript::%js-make-object
     "size" (length values)
     "has" (lambda (candidate &rest _)
             (declare (ignore _))
             (loop for value across entries
                   thereis (cl-cc/javascript::%js-same-value-zero value candidate)))
     "keys" (lambda (&rest _)
              (declare (ignore _))
              entries))))

(defmatcher :to-have-set-values (set expected)
  "Checks that SET (a JS Set, or set-like object exposing size/has) has
exactly the given membership: its size matches the expected value count, and
every expected value is present. Order-insensitive — see :to-equal on
%jr-list'd .keys() for an order-sensitive check."
  (let* ((expected-values (first expected))
         (actual-size (cl-cc/javascript::%js-set-size set)))
    (values (and (= actual-size (length expected-values))
                 (every (lambda (v) (cl-cc/javascript::%js-set-has set v)) expected-values))
            actual-size
            (length expected-values))))

(defun %jr-assert-set-keys (expected-values set)
  (expect (%jr-list (cl-cc/javascript::%js-set-keys set)) :to-equal expected-values))

(it-sequential "js-rt-set-basic"
  (let ((s (%jr-set 1 2 3)))
    (expect (= 3 (cl-cc/javascript::%js-set-size s)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-has s 2) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-has s 9) :to-be-falsy)
    (cl-cc/javascript::%js-set-delete s 2)
    (expect (= 2 (cl-cc/javascript::%js-set-size s)) :to-be-truthy)
    (cl-cc/javascript::%js-set-clear s)
    (expect (zerop (cl-cc/javascript::%js-set-size s)) :to-be-truthy)))

(it-sequential "js-rt-set-same-value-zero-values"
  (let ((nan-a cl-cc/javascript::*js-nan-float*)
        (nan-b cl-cc/javascript::+js-nan+)
        (s (cl-cc/javascript::%js-make-set)))
    (cl-cc/javascript::%js-set-add s nan-a)
    (expect (cl-cc/javascript::%js-set-has s nan-b) :to-be-truthy)
    (cl-cc/javascript::%js-set-add s nan-b)
    (expect (= 1 (cl-cc/javascript::%js-set-size s)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-delete s nan-b) :to-be-truthy)
    (expect (zerop (cl-cc/javascript::%js-set-size s)) :to-be-truthy)
    (cl-cc/javascript::%js-set-add s 0.0d0)
    (cl-cc/javascript::%js-set-add s -0.0d0)
    (expect (= 1 (cl-cc/javascript::%js-set-size s)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-has s 0.0d0) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-has s -0.0d0) :to-be-truthy)
    (let ((with-nan (%jr-set nan-b 1)))
      (cl-cc/javascript::%js-set-add s nan-a)
      (expect (cl-cc/javascript::%js-set-is-disjoint-from s with-nan) :to-be-falsy)
      (expect (cl-cc/javascript::%js-set-is-superset-of s (%jr-set nan-b -0.0d0)) :to-be-truthy))))

(it-sequential "js-rt-set-union"
  (let* ((a (%jr-set 1 2))
         (b (%jr-set 2 3))
         (u (cl-cc/javascript::%js-set-union a b)))
    (expect u :to-have-set-values '(1 2 3))))

(it-sequential "js-rt-set-union-set-like"
  (let* ((a (%jr-set 1 2))
         (b (%jr-set-like 2 3))
         (u (cl-cc/javascript::%js-set-union a b)))
    (%jr-assert-set-keys '(1 2 3) u)))

(it-sequential "js-rt-set-intersection"
  (let* ((a (%jr-set 1 2 3))
         (b (%jr-set 2 3 4))
         (i (cl-cc/javascript::%js-set-intersection a b)))
    (expect i :to-have-set-values '(2 3))
    (expect (cl-cc/javascript::%js-set-has i 1) :to-be-falsy)))

(it-sequential "js-rt-set-difference"
  (let* ((a (%jr-set 1 2 3))
         (b (%jr-set 2))
         (d (cl-cc/javascript::%js-set-difference a b)))
    (expect d :to-have-set-values '(1 3))
    (expect (cl-cc/javascript::%js-set-has d 2) :to-be-falsy)))

(it-sequential "js-rt-set-filter-ops-set-like"
  (let* ((a (%jr-set 1 2 3))
         (b (%jr-set-like 2 4))
         (intersection (cl-cc/javascript::%js-set-intersection a b))
         (difference (cl-cc/javascript::%js-set-difference a b))
         (symmetric (cl-cc/javascript::%js-set-symmetric-difference a b)))
    (%jr-assert-set-keys '(2) intersection)
    (%jr-assert-set-keys '(1 3) difference)
    (%jr-assert-set-keys '(1 3 4) symmetric)))

(it-sequential "js-rt-set-subset-disjoint"
  (let ((a (%jr-set 1 2))
        (b (%jr-set 1 2 3))
        (c (%jr-set 4 5)))
    (expect (cl-cc/javascript::%js-set-is-subset-of   a b) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-is-subset-of   b a) :to-be-falsy)
    (expect (cl-cc/javascript::%js-set-is-disjoint-from a c) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-is-disjoint-from a b) :to-be-falsy)))

(it-sequential "js-rt-set-predicates-set-like"
  (let ((a (%jr-set 1 2))
        (b (%jr-set-like 1 2 3))
        (c (%jr-set 1 2 3))
        (d (%jr-set-like 2 3))
        (e (%jr-set-like 4 5))
        (f (%jr-set-like 2 5)))
    (expect (cl-cc/javascript::%js-set-is-subset-of a b) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-is-superset-of c d) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-is-disjoint-from a e) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-is-disjoint-from a f) :to-be-falsy)))
