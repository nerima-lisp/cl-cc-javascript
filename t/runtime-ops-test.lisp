;;;; t/runtime-ops-test.lisp
;;;;
;;;; Split from runtime-object-ops-test.lisp once that file passed the org's
;;;; 500-line cap. Unit tests for runtime-ops.lisp (32-bit integer coercion,
;;;; bitwise ops, shifts, unary/increment ops, BigInt extras, URI encoding,
;;;; accessor/misc stubs) and the accessor-descriptor-p/put-entry/optional-call
;;;; slice of runtime-property.lisp.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list)

(in-package :cl-cc-javascript/test)

;;; ─── 32-bit integer coercion ─────────────────────────────────────────────────

(it-sequential-each ((5 5) (3.7d0 3) (#x100000001 1))
    "js-rt-to-int32 ~A"
    (x expected)
  (expect (= expected (cl-cc/javascript::%js-to-int32 x)) :to-be-truthy))

(it-sequential-each ((5 5) (#x7FFFFFFF 2147483647) (#x80000000 -2147483648))
    "js-rt-sign-extend32 ~A"
    (n expected)
  (expect (= expected (cl-cc/javascript::%js-sign-extend32 n)) :to-be-truthy))

;;; ─── Bitwise operators ───────────────────────────────────────────────────────

(it-sequential "js-rt-bitwise-binops and"
  (destructuring-bind (fn a b expected) (list #'cl-cc/javascript::%js-bitwise-and #b1010 #b1100 #b1000)
    (expect (= expected (funcall fn a b)) :to-be-truthy)))

(it-sequential "js-rt-bitwise-binops or"
  (destructuring-bind (fn a b expected) (list #'cl-cc/javascript::%js-bitwise-or #b1010 #b1100 #b1110)
    (expect (= expected (funcall fn a b)) :to-be-truthy)))

(it-sequential "js-rt-bitwise-binops xor"
  (destructuring-bind (fn a b expected) (list #'cl-cc/javascript::%js-bitwise-xor #b1010 #b1100 #b0110)
    (expect (= expected (funcall fn a b)) :to-be-truthy)))

(it-sequential "js-rt-bitwise-not"
  (expect (= -1 (cl-cc/javascript::%js-bitwise-not 0)) :to-be-truthy)
  (expect (= -6 (cl-cc/javascript::%js-bitwise-not 5)) :to-be-truthy))

;;; ─── Shift operators ─────────────────────────────────────────────────────────

(it-sequential "js-rt-shift-ops shl"
  (destructuring-bind (fn a b expected) (list #'cl-cc/javascript::%js-shift-left 1 4 16)
    (expect (= expected (funcall fn a b)) :to-be-truthy)))

(it-sequential "js-rt-shift-ops shr"
  (destructuring-bind (fn a b expected) (list #'cl-cc/javascript::%js-shift-right -8 1 -4)
    (expect (= expected (funcall fn a b)) :to-be-truthy)))

(it-sequential "js-rt-shift-ops ushr"
  (destructuring-bind (fn a b expected) (list #'cl-cc/javascript::%js-unsigned-shift-right -1 28 15)
    (expect (= expected (funcall fn a b)) :to-be-truthy)))

;;; ─── Unary / increment ops ───────────────────────────────────────────────────

(it-sequential "js-rt-unary-plus"
  (expect (= 42 (cl-cc/javascript::%js-unary-plus "42")) :to-be-truthy)
  (expect (zerop (cl-cc/javascript::%js-unary-plus nil)) :to-be-truthy))

(it-sequential "js-rt-inc-dec-ops prefix-inc"
  (destructuring-bind (fn val expected) (list #'cl-cc/javascript::%js-prefix-inc 5 6)
    (expect (= expected (funcall fn val)) :to-be-truthy)))

(it-sequential "js-rt-inc-dec-ops prefix-dec"
  (destructuring-bind (fn val expected) (list #'cl-cc/javascript::%js-prefix-dec 5 4)
    (expect (= expected (funcall fn val)) :to-be-truthy)))

(it-sequential "js-rt-inc-dec-ops postfix-inc"
  (destructuring-bind (fn val expected) (list #'cl-cc/javascript::%js-postfix-inc 5 5)
    (expect (= expected (funcall fn val)) :to-be-truthy)))

(it-sequential "js-rt-inc-dec-ops postfix-dec"
  (destructuring-bind (fn val expected) (list #'cl-cc/javascript::%js-postfix-dec 5 5)
    (expect (= expected (funcall fn val)) :to-be-truthy)))

;;; ─── BigInt extras ───────────────────────────────────────────────────────────

(it-sequential-each ((42 42) (3.9d0 3) ("100" 100))
    "js-rt-bigint-constructor ~S"
    (x expected)
  (let ((bi (cl-cc/javascript::%js-bigint x)))
    (expect (cl-cc/javascript::js-bigint-p bi) :to-be-truthy)
    (expect (= expected (cl-cc/javascript::js-bigint-value bi)) :to-be-truthy)))

(it-sequential-each ((255 10 "255") (255 16 "ff") (5 2 "101"))
    "js-rt-bigint-to-string-radix ~A/~A"
    (n radix expected)
  (let ((bi (cl-cc/javascript::%make-js-bigint n)))
    (expect (cl-cc/javascript::%js-bigint-to-string bi radix) :to-equal expected)))

(it-sequential "js-rt-bigint-div-mod div"
  (destructuring-bind (fn a b expected) (list #'cl-cc/javascript::%js-bigint-div 10 3 3)
    (let ((result (funcall fn a b)))
    (expect (= expected (cl-cc/javascript::js-bigint-value result)) :to-be-truthy))))

(it-sequential "js-rt-bigint-div-mod mod"
  (destructuring-bind (fn a b expected) (list #'cl-cc/javascript::%js-bigint-mod 10 3 1)
    (let ((result (funcall fn a b)))
    (expect (= expected (cl-cc/javascript::js-bigint-value result)) :to-be-truthy))))

(it-sequential-each ((3 5 -1) (5 5 0) (7 5 1))
    "js-rt-bigint-compare ~A/~A"
    (a b expected)
  (expect (= expected (cl-cc/javascript::%js-bigint-compare a b)) :to-be-truthy))

(it-sequential "js-rt-bigint-shift lshift"
  (destructuring-bind (fn a n expected) (list #'cl-cc/javascript::%js-bigint-lshift 1 3 8)
    (let ((result (funcall fn a n)))
    (expect (= expected (cl-cc/javascript::js-bigint-value result)) :to-be-truthy))))

(it-sequential "js-rt-bigint-shift rshift"
  (destructuring-bind (fn a n expected) (list #'cl-cc/javascript::%js-bigint-rshift 8 2 2)
    (let ((result (funcall fn a n)))
    (expect (= expected (cl-cc/javascript::js-bigint-value result)) :to-be-truthy))))

(it-sequential "js-rt-bigint-negate"
  (expect (= -42 (cl-cc/javascript::js-bigint-value
                 (cl-cc/javascript::%js-bigint-negate 42))) :to-be-truthy)
  (expect (= 7 (cl-cc/javascript::js-bigint-value
                 (cl-cc/javascript::%js-bigint-negate -7))) :to-be-truthy))

;;; ─── URI encoding ────────────────────────────────────────────────────────────

(it-sequential "js-rt-encode-uri-component"
  (expect (cl-cc/javascript::%js-encode-uri-component "hello world") :to-equal "hello%20world")
  (expect (cl-cc/javascript::%js-encode-uri-component "abc") :to-equal "abc"))

(it-sequential "js-rt-decode-uri-component"
  (expect (cl-cc/javascript::%js-decode-uri-component "hello%20world") :to-equal "hello world"))

;;; ─── Accessor / misc stubs ───────────────────────────────────────────────────

(it-sequential "js-rt-accessor-descriptor"
  (let* ((fn   (lambda () 42))
         (desc (cl-cc/javascript::%js-accessor "get" fn)))
    (expect (gethash "__accessor__" desc) :to-be-truthy)
    (expect (gethash "kind" desc) :to-equal "get")
    (expect (gethash "fn" desc) :to-be fn)))

(it-sequential "js-rt-new-target-returns-undefined"
  (expect (cl-cc/javascript::%js-new-target) :to-be-js-undefined))

(it-sequential "js-rt-using-register-identity"
  (let ((r (list 1 2)))
    (expect (cl-cc/javascript::%js-using-register r) :to-be r)))

;;; ─── runtime-property.lisp: accessor-descriptor-p, put-entry, optional ops ──

(it-sequential "js-rt-accessor-descriptor-p get-accessor"
  (destructuring-bind (val expected) (list (cl-cc/javascript::%js-accessor "get" (lambda () 1)) t)
    (expect (cl-cc/javascript::%js-accessor-descriptor-p val) :to-equal expected)))

(it-sequential "js-rt-accessor-descriptor-p set-accessor"
  (destructuring-bind (val expected) (list (cl-cc/javascript::%js-accessor "set" (lambda (v) v)) t)
    (expect (cl-cc/javascript::%js-accessor-descriptor-p val) :to-equal expected)))

(it-sequential "js-rt-accessor-descriptor-p plain-ht"
  (destructuring-bind (val expected) (list (cl-cc/javascript::%js-make-object "x" 1) nil)
    (expect (cl-cc/javascript::%js-accessor-descriptor-p val) :to-equal expected)))

(it-sequential "js-rt-accessor-descriptor-p string"
  (destructuring-bind (val expected) (list "not-an-accessor" nil)
    (expect (cl-cc/javascript::%js-accessor-descriptor-p val) :to-equal expected)))

(it-sequential "js-rt-object-put-entry-accessor-routing"
  (let* ((ht  (cl-cc/javascript::%js-make-ht))
         (fn  (lambda () 42))
         (desc (cl-cc/javascript::%js-accessor "get" fn)))
    (cl-cc/javascript::%js-object-put-entry ht "foo" desc)
    (expect (gethash "__get_foo" ht) :to-be fn)
    (expect (nth-value 1 (gethash "foo" ht)) :to-be-falsy)))

(it-sequential "js-rt-optional-call real-fn"
  (destructuring-bind (func expected) (list (lambda () 99) 99)
    (let ((result (cl-cc/javascript::%js-optional-call func)))
    (if (eq expected :undef)
        (expect result :to-be-js-undefined)
        (expect (= expected result) :to-be-truthy)))))

(it-sequential "js-rt-optional-call undefined"
  (destructuring-bind (func expected) (list cl-cc/javascript::+js-undefined+ :undef)
    (let ((result (cl-cc/javascript::%js-optional-call func)))
    (if (eq expected :undef)
        (expect result :to-be-js-undefined)
        (expect (= expected result) :to-be-truthy)))))

(it-sequential "js-rt-optional-call null"
  (destructuring-bind (func expected) (list cl-cc/javascript::+js-null+ :undef)
    (let ((result (cl-cc/javascript::%js-optional-call func)))
    (if (eq expected :undef)
        (expect result :to-be-js-undefined)
        (expect (= expected result) :to-be-truthy)))))

(it-sequential "js-rt-optional-method-call-present"
  (let* ((obj    (cl-cc/javascript::%js-make-object "double" (lambda (n) (* 2 n))))
         (result (cl-cc/javascript::%js-optional-method-call obj "double" 5)))
    (expect (= 10 result) :to-be-truthy)))

(it-sequential "js-rt-optional-method-call-null"
  (expect (cl-cc/javascript::%js-optional-method-call cl-cc/javascript::+js-null+ "double" 5) :to-be-js-undefined))

(it-sequential "js-rt-add-string-coercion"
  (expect (cl-cc/javascript::%js-add 4 "2") :to-equal "42")
  (expect (cl-cc/javascript::%js-add "a" "b") :to-equal "ab")
  (expect (= 6.0d0 (cl-cc/javascript::%js-add 4 2)) :to-be-truthy))
