;;;; t/runtime-core-test.lisp
;;;;
;;;; Core type coercion, equality, truthiness, for-of/in, try-catch, Object
;;;; basic operations, and bitwise operators.
;;;;
;;;; Helper functions (%jr-arr, %jr-list, %jr-set) are defined here
;;;; and available to all subsequently-loaded runtime-*-test files.

(in-package :cl-cc-javascript/test)

;;; ─── Shared helpers (used across all runtime-*-test files) ───────────────────

(defun %jr-arr (&rest els)
  "Build a JS array (adjustable vector) from ELS."
  (apply #'cl-cc/javascript::%js-make-array els))

(defun %jr-list (vec)
  "Coerce a JS array (vector) to a CL list for easy comparison."
  (coerce vec 'list))

(defun %jr-set (&rest vals)
  "Build a JS Set from VALS in insertion order."
  (let ((s (cl-cc/javascript::%js-make-set)))
    (dolist (v vals s)
      (cl-cc/javascript::%js-set-add s v))))

(defmatcher :to-be-js-undefined (actual expected)
  "Checks ACTUAL is EQ to +js-undefined+ -- the runtime's undefined sentinel,
identical for every call site (unlike NIL, which JS null/false/[] all also
coerce to at various points), so EQ is exact. Replaces the previous
'(expect ... :to-be cl-cc/javascript::+js-undefined+)' spelling repeated
across every runtime-*-test file."
  (declare (ignore expected))
  (eq actual cl-cc/javascript::+js-undefined+))

;;; ─── typeof ──────────────────────────────────────────────────────────────────

(it-sequential-each ((42 "number")
                     ("hi" "string")
                     (t "boolean")
                     (nil "boolean")
                     (:js-undefined "undefined")
                     (:js-null "object")
                     (#.(cl-cc/javascript::%js-make-array 1 2) "object"))
    "js-rt-typeof ~A"
    (value expected)
  (expect (cl-cc/javascript::%js-typeof value) :to-equal expected))

;;; ─── ToString ────────────────────────────────────────────────────────────────

(it-sequential-each ((42 "42")
                     (t "true")
                     (nil "false")
                     (:js-null "null")
                     (:js-undefined "undefined")
                     (:js-nan "NaN"))
    "js-rt-to-string ~A"
    (value expected)
  (expect (cl-cc/javascript::%js-to-string value) :to-equal expected))

;;; ─── Strict equality ────────────────────────────────────────────────────────

(it-sequential-each ((3 3 t)
                     (3 4 nil)
                     ("a" "a" t)
                     ("a" "b" nil))
    "js-rt-strict-eq ~A ~A"
    (a b expected)
  (expect (cl-cc/javascript::%js-strict-eq a b) :to-equal expected))

;;; ─── Truthiness ──────────────────────────────────────────────────────────────

(it-sequential-each ((1 t)
                     ("x" t)
                     (0 nil)
                     ("" nil)
                     (nil nil)
                     (:js-undefined nil)
                     (:js-null nil))
    "js-rt-truthy ~S"
    (value expected)
  (expect (cl-cc/javascript::%js-truthy value) :to-equal expected))

;;; ─── Loose equality ──────────────────────────────────────────────────────────

(it-sequential-each ((1 1 t)
                     (:js-null :js-undefined t)
                     (:js-undefined :js-null t)
                     (3 "3" t)
                     ("3" 3 t)
                     (t 1 t)
                     (:js-nan :js-nan nil)
                     (1 2 nil))
    "js-rt-loose-eq ~S ~S"
    (a b expected)
  (expect (cl-cc/javascript::%js-loose-eq a b) :to-equal expected))

;;; ─── Bitwise operators ───────────────────────────────────────────────────────

(it-sequential-each ((#b1010 #b1100 #b1110)
                     (-1 0 -1)
                     (0 0 0))
    "js-rt-bitwise-or ~A ~A"
    (a b expected)
  (expect (= expected (cl-cc/javascript::%js-bitwise-or a b)) :to-be-truthy))

(it-sequential-each ((#b1010 #b1100 #b1000)
                     (5 0 0)
                     (7 7 7))
    "js-rt-bitwise-and ~A ~A"
    (a b expected)
  (expect (= expected (cl-cc/javascript::%js-bitwise-and a b)) :to-be-truthy))

(it-sequential-each ((#b1010 #b1100 #b0110)
                     (7 7 0)
                     (0 5 5))
    "js-rt-bitwise-xor ~A ~A"
    (a b expected)
  (expect (= expected (cl-cc/javascript::%js-bitwise-xor a b)) :to-be-truthy))

(it-sequential-each ((0 -1)
                     (-1 0)
                     (1 -2))
    "js-rt-bitwise-not ~A"
    (x expected)
  (expect (= expected (cl-cc/javascript::%js-bitwise-not x)) :to-be-truthy))

(it-sequential-each (("shl-2" cl-cc/javascript::%js-shift-left 2 2 8)
                     ("shl-1" cl-cc/javascript::%js-shift-left 1 4 16)
                     ("shl-0" cl-cc/javascript::%js-shift-left 5 0 5)
                     ("shr-pos" cl-cc/javascript::%js-shift-right 8 2 2)
                     ("shr-neg" cl-cc/javascript::%js-shift-right -8 2 -2)
                     ("ushr-neg" cl-cc/javascript::%js-unsigned-shift-right -8 2 1073741822)
                     ("ushr-pos" cl-cc/javascript::%js-unsigned-shift-right 8 2 2))
    "js-rt-shift-ops-full ~A"
    (label fn a b expected)
  (declare (ignore label))
  (expect (= expected (funcall fn a b)) :to-be-truthy))

;;; ─── Object basic operations ─────────────────────────────────────────────────

(it-sequential "js-rt-object-make-access"
  (let ((o (cl-cc/javascript::%js-make-object "a" 1 "b" 2)))
    (expect (= 1 (cl-cc/javascript::%js-get-prop o "a")) :to-be-truthy)
    (expect (= 2 (cl-cc/javascript::%js-get-prop o "b")) :to-be-truthy)))

(it-sequential "js-rt-object-keys-values"
  (let* ((o  (cl-cc/javascript::%js-make-object "x" 10 "y" 20))
         (ks (sort (%jr-list (cl-cc/javascript::%js-object-keys   o)) #'string<))
         (vs (sort (%jr-list (cl-cc/javascript::%js-object-values o)) #'<)))
    (expect ks :to-equal '("x" "y"))
    (expect vs :to-equal '(10 20))))

(it-sequential "js-rt-get-prop-array"
  (let ((a (%jr-arr 10 20 30)))
    (expect (= 3 (cl-cc/javascript::%js-get-prop a "length")) :to-be-truthy)
    (expect (= 20 (cl-cc/javascript::%js-get-prop a 1)) :to-be-truthy)))

(it-sequential "js-rt-object-prop-false-value"
  (let ((obj (cl-cc/javascript::%js-make-object "flag" nil)))
    (expect (cl-cc/javascript::%js-get-prop obj "flag") :to-be-falsy)
    (expect (cl-cc/javascript::%js-get-prop obj "absent") :to-be-js-undefined)))

;;; ─── for-of / for-in ─────────────────────────────────────────────────────────

(it-sequential-each ((#.(cl-cc/javascript::%js-make-array 10 20 30) (10 20 30))
                     ("hi" ("h" "i")))
    "js-rt-for-of ~S"
    (iterable expected)
  (let ((seen nil))
    (cl-cc/javascript::%js-for-of
     iterable
     (lambda (x &rest _) (declare (ignore _)) (push x seen)))
    (expect (nreverse seen) :to-equal expected)))

(it-sequential "js-rt-for-in-object"
  (let ((o (cl-cc/javascript::%js-make-object "a" 1 "b" 2))
        (keys nil))
    (cl-cc/javascript::%js-for-in o (lambda (k &rest _) (declare (ignore _)) (push k keys)))
    (expect (sort keys #'string<) :to-equal '("a" "b"))))

(it-sequential "js-rt-for-in-includes-accessor-keys-under-their-real-name"
  ;; Renamed from "skips-accessor-keys" 2026-07-31 (later session) -- that
  ;; name locked in the WRONG (pre-fix) behavior. A getter/setter accessor
  ;; property is enumerable by default, exactly like a plain data property
  ;; (`{get foo(){}}` in real JS enumerates "foo" via for...in) -- what
  ;; for...in must actually skip is the internal __get_X/__set_X STORAGE
  ;; key itself (and other internal keys like __proto__), not the logical
  ;; property the accessor represents. See CHANGELOG.md.
  (let ((obj (cl-cc/javascript::%js-make-object "a" 1 "b" 2))
        (keys nil))
    (setf (gethash "__get_foo" obj) (lambda () 99))
    (setf (gethash "__set_foo" obj) (lambda (v) v))
    (setf (gethash "__proto__" obj) cl-cc/javascript::+js-undefined+)
    (cl-cc/javascript::%js-for-in
     obj (lambda (k &rest _) (declare (ignore _)) (push k keys)))
    (expect (sort keys #'string<) :to-equal '("a" "b" "foo"))))

;;; ─── ToNumber coercions ──────────────────────────────────────────────────────

(it-sequential-each ((42 42.0d0)
                     (t 1.0d0)
                     (nil 0.0d0)
                     (:js-null 0.0d0)
                     ("" 0.0d0)
                     ("3.14" 3.14d0)
                     ("42" 42.0d0)
                     ("  7  " 7.0d0))
    "js-rt-to-number ~S"
    (value expected)
  (expect (= expected (cl-cc/javascript::%js-to-number value)) :to-be-truthy))

(it-sequential "js-rt-to-number-nan-str"
  (expect (cl-cc/javascript::%js-nan-p (cl-cc/javascript::%js-to-number "abc")) :to-be-truthy))

;;; ─── typeof: extended types ──────────────────────────────────────────────────

;;; Not table-tested: each case constructs a genuinely different kind of
;;; runtime object (closure, hash-table, struct) that cl-weave's
;;; it-sequential-each cannot express — its case list is quoted at
;;; macro-expansion time, so entries must be dumpable literals, not live
;;; objects built by evaluating a constructor.
(it-sequential "js-rt-typeof-extended function"
  (expect (cl-cc/javascript::%js-typeof (lambda () nil)) :to-equal "function"))

(it-sequential "js-rt-typeof-extended object"
  (expect (cl-cc/javascript::%js-typeof (cl-cc/javascript::%js-make-ht)) :to-equal "object"))

(it-sequential "js-rt-typeof-extended bigint"
  (expect (cl-cc/javascript::%js-typeof (cl-cc/javascript::%make-js-bigint 5)) :to-equal "bigint"))

(it-sequential "js-rt-typeof-callable-object"
  (let ((fn-obj (cl-cc/javascript::%js-make-ht)))
    (setf (gethash "__call__" fn-obj) (lambda () nil))
    (expect (cl-cc/javascript::%js-typeof fn-obj) :to-equal "function")))

;;; ─── Relational operators ────────────────────────────────────────────────────

(it-sequential-each (("num-lt-true" cl-cc/javascript::%js-lt 1 2 t)
                     ("num-lt-false" cl-cc/javascript::%js-lt 2 1 nil)
                     ("num-gt-true" cl-cc/javascript::%js-gt 5 3 t)
                     ("num-gt-false" cl-cc/javascript::%js-gt 3 5 nil)
                     ("num-le-eq" cl-cc/javascript::%js-le 3 3 t)
                     ("num-le-less" cl-cc/javascript::%js-le 2 3 t)
                     ("num-ge-eq" cl-cc/javascript::%js-ge 3 3 t)
                     ("num-ge-more" cl-cc/javascript::%js-ge 4 3 t)
                     ("string-lt-abc" cl-cc/javascript::%js-lt "a" "b" t)
                     ("string-gt-abc" cl-cc/javascript::%js-gt "b" "a" t)
                     ("string-lt-same" cl-cc/javascript::%js-lt "a" "a" nil)
                     ("string-le-same" cl-cc/javascript::%js-le "a" "a" t))
    "js-rt-relational ~A"
    (label fn a b expected)
  (declare (ignore label))
  (expect (funcall fn a b) :to-equal expected))

(it-sequential "js-rt-relational-nan-always-false"
  (let ((nan cl-cc/javascript::+js-nan+))
    (expect (cl-cc/javascript::%js-lt nan 1) :to-be-falsy)
    (expect (cl-cc/javascript::%js-gt nan 1) :to-be-falsy)
    (expect (cl-cc/javascript::%js-le nan 1) :to-be-falsy)
    (expect (cl-cc/javascript::%js-ge nan 1) :to-be-falsy)))

;;; ─── instanceof ──────────────────────────────────────────────────────────────

(it-sequential "js-rt-instanceof-true"
  (let* ((klass (cl-cc/javascript::%js-make-class nil nil))
         (obj   (cl-cc/javascript::%js-new klass)))
    (expect (cl-cc/javascript::%js-instanceof obj klass) :to-be-truthy)))

(it-sequential "js-rt-instanceof-false"
  (let* ((klass-a (cl-cc/javascript::%js-make-class nil nil))
         (klass-b (cl-cc/javascript::%js-make-class nil nil))
         (obj     (cl-cc/javascript::%js-new klass-a)))
    (expect (cl-cc/javascript::%js-instanceof obj klass-b) :to-be-falsy)))

;;; ─── try-catch-finally ───────────────────────────────────────────────────────

(it-sequential "js-rt-try-catch"
  (let ((caught nil))
    (cl-cc/javascript::%js-try-catch-finally
     (lambda () (cl-cc/javascript::%js-throw "err"))
     (lambda (v) (setf caught v))
     nil)
    (expect caught :to-equal "err")))

(it-sequential "js-rt-try-finally-runs"
  (let ((ran nil))
    (cl-cc/javascript::%js-try-catch-finally
     (lambda () 42)
     nil
     (lambda () (setf ran t)))
    (expect ran :to-be-truthy)))

;;; ─── JS + operator (add / string-concat) ────────────────────────────────────

(it-sequential "js-rt-add-numeric"
  (expect (= 7 (cl-cc/javascript::%js-add 3 4)) :to-be-truthy))

(it-sequential-each (("a" "b" "ab")
                     (1 "x" "1x")
                     ("x" 1 "x1"))
    "js-rt-add-string-concat ~S ~S"
    (a b expected)
  (expect (cl-cc/javascript::%js-add a b) :to-equal expected))

;;; ─── JS /, %, ** arithmetic operators ───────────────────────────────────────

(it-sequential-each (("div-float" cl-cc/javascript::%js-divide 10 4 2.5d0)
                     ("mod-pos" cl-cc/javascript::%js-mod 10 3 1)
                     ("mod-neg" cl-cc/javascript::%js-mod -5 3 -2)
                     ("pow-two" cl-cc/javascript::%js-pow 2 10 1024))
    "js-rt-arithmetic-ops ~A"
    (label fn a b expected)
  (declare (ignore label))
  (expect (= expected (funcall fn a b)) :to-be-truthy))

(it-sequential "js-rt-divide-by-zero-infinity"
  (expect (cl-cc/javascript::%js-float-infinity-p (cl-cc/javascript::%js-divide 1 0)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-nan-p (cl-cc/javascript::%js-divide 0 0)) :to-be-truthy))

(it-sequential "js-rt-mod-zero-denominator-nan"
  (expect (cl-cc/javascript::%js-nan-p (cl-cc/javascript::%js-mod 5 0)) :to-be-truthy))

;;; ─── Property: delete / in / optional-chain ──────────────────────────────────

(it-sequential "js-rt-delete-property"
  (let ((o (cl-cc/javascript::%js-make-object "a" 1 "b" 2)))
    (cl-cc/javascript::%js-delete o "a")
    (expect (cl-cc/javascript::%js-get-prop o "a") :to-be-js-undefined)
    (expect (= 2 (cl-cc/javascript::%js-get-prop o "b")) :to-be-truthy)))

(it-sequential-each (("a" t)
                     ("z" nil))
    "js-rt-in-operator ~S"
    (key expected)
  (let ((o (cl-cc/javascript::%js-make-object "a" 1)))
    (expect (cl-cc/javascript::%js-in key o) :to-equal expected)))

(it-sequential "js-rt-optional-chain-present"
  (let ((o (cl-cc/javascript::%js-make-object "x" 42)))
    (expect (= 42 (cl-cc/javascript::%js-optional-chain o "x")) :to-be-truthy)))

(it-sequential "js-rt-optional-chain-null-undefined"
  (expect (cl-cc/javascript::%js-optional-chain cl-cc/javascript::+js-null+ "x") :to-be-js-undefined)
  (expect (cl-cc/javascript::%js-optional-chain cl-cc/javascript::+js-undefined+ "x") :to-be-js-undefined))
