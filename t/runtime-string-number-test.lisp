;;;; t/runtime-string-number-test.lisp
;;;;
;;;; String prototype methods, Math (basic and transcendental), Number.prototype
;;;; methods, number format helpers, predicates (isNaN/isFinite/isInteger),
;;;; and parseInt/parseFloat.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr)

(in-package :cl-cc-javascript/test)

;;; ─── String ──────────────────────────────────────────────────────────────────

(it-sequential "js-rt-string-slice"
  (expect (cl-cc/javascript::%js-string-slice "hello" 1 4) :to-equal "ell")
  (expect (cl-cc/javascript::%js-string-slice "hello" -2) :to-equal "lo"))

(it-sequential "js-rt-string-search"
  (expect (cl-cc/javascript::%js-string-includes  "hello" "ell") :to-be-truthy)
  (expect (cl-cc/javascript::%js-string-includes  "hello" "xyz") :to-be-falsy)
  (expect (= 2 (cl-cc/javascript::%js-string-index-of  "hello" "l")) :to-be-truthy)
  (expect (= -1 (cl-cc/javascript::%js-string-index-of  "hello" "z")) :to-be-truthy))

(it-sequential "js-rt-string-index-of-position-coercion"
  (expect (= 2 (cl-cc/javascript::%js-string-index-of "ababa" "a" "2")) :to-be-truthy)
  (expect (= 3 (cl-cc/javascript::%js-string-index-of "abcabc" "a" 2.8d0)) :to-be-truthy)
  (expect (zerop (cl-cc/javascript::%js-string-index-of
               "abc" "a" cl-cc/javascript::+js-undefined+)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-string-includes "abc" "a" 1) :to-be-falsy))

(it-sequential-each ((cl-cc/javascript::%js-string-to-upper-case "hello" "HELLO")
                     (cl-cc/javascript::%js-string-to-lower-case "HELLO" "hello"))
    "js-rt-string-case ~A"
    (fn input expected)
  (expect (funcall (symbol-function fn) input) :to-equal expected))

(it-sequential-each (("ab" 3 "ababab") ("ab" 0 ""))
    "js-rt-string-repeat ~A ~A"
    (s n expected)
  (expect (cl-cc/javascript::%js-string-repeat s n) :to-equal expected))

(it-sequential "js-rt-string-split-empty-sep"
  (expect (%jr-list (cl-cc/javascript::%js-string-split "abc" "")) :to-equal '("a" "b" "c")))

(it-sequential-each ((cl-cc/javascript::%js-string-starts-with "hello" "hel" t)
                     (cl-cc/javascript::%js-string-starts-with "hello" "ell" nil)
                     (cl-cc/javascript::%js-string-ends-with "hello" "llo" t)
                     (cl-cc/javascript::%js-string-ends-with "hello" "hel" nil))
    "js-rt-string-starts-ends-with ~A ~*~S"
    (fn s sub expected)
  (expect (funcall (symbol-function fn) s sub) :to-equal expected))

(it-sequential-each ((cl-cc/javascript::%js-string-pad-start "5" 3 "005")
                     (cl-cc/javascript::%js-string-pad-end "5" 3 "500"))
    "js-rt-string-pad ~A"
    (fn s len expected)
  (expect (funcall (symbol-function fn) s len "0") :to-equal expected))

(it-sequential "js-rt-string-trim"
  (expect (cl-cc/javascript::%js-string-trim       "  hello  ") :to-equal "hello")
  (expect (cl-cc/javascript::%js-string-trim-start "  hello  ") :to-equal "hello  ")
  (expect (cl-cc/javascript::%js-string-trim-end   "  hello  ") :to-equal "  hello"))

(it-sequential-each ((0 "h") (-1 "o") (2 "l"))
    "js-rt-string-at ~A"
    (idx expected)
  (expect (cl-cc/javascript::%js-string-at "hello" idx) :to-equal expected))

(it-sequential "js-rt-string-char-at-code-at"
  (expect (cl-cc/javascript::%js-string-char-at      "hello" 1) :to-equal "e")
  (expect (= 101 (cl-cc/javascript::%js-string-char-code-at "hello" 1)) :to-be-truthy))

(it-sequential-each (("abcabc" "b" 4) ("aabb" "b" 3) ("abc" "z" -1))
    "js-rt-string-last-index-of ~A ~A"
    (s sub expected)
  (expect (= expected (cl-cc/javascript::%js-string-last-index-of s sub)) :to-be-truthy))

(it-sequential "js-rt-string-last-index-of-position-bounds"
  (expect (= 4 (cl-cc/javascript::%js-string-last-index-of "ababa" "a" cl-cc/javascript::+js-undefined+)) :to-be-truthy)
  (expect (= 2 (cl-cc/javascript::%js-string-last-index-of "ababa" "a" "2")) :to-be-truthy)
  (expect (zerop (cl-cc/javascript::%js-string-last-index-of "abcabc" "a" 2.8d0)) :to-be-truthy)
  (expect (zerop (cl-cc/javascript::%js-string-last-index-of "ababa" "a" -99)) :to-be-truthy)
  (expect (= -1 (cl-cc/javascript::%js-string-last-index-of "ababa" "b" -99)) :to-be-truthy)
  (expect (= 5 (cl-cc/javascript::%js-string-last-index-of "ababa" "" 99)) :to-be-truthy))

(it-sequential "js-rt-string-concat"
  (expect (cl-cc/javascript::%js-string-concat "hello" " " "world") :to-equal "hello world"))

(it-sequential "js-rt-string-from-char-code-and-code-point"
  (expect (cl-cc/javascript::%js-string-from-char-code  65) :to-equal "A")
  (expect (cl-cc/javascript::%js-string-from-code-point 65) :to-equal "A"))

(it-sequential "js-rt-string-code-point-at"
  (expect (= 72 (cl-cc/javascript::%js-string-code-point-at "Hello" 0)) :to-be-truthy)
  (expect (= 101 (cl-cc/javascript::%js-string-code-point-at "Hello" 1)) :to-be-truthy))

(it-sequential "js-rt-string-is-well-formed"
  (let ((wf "hello"))
    (expect (cl-cc/javascript::%js-string-is-well-formed wf) :to-be-truthy)
    (expect (cl-cc/javascript::%js-string-to-well-formed wf) :to-equal wf)))

(it-sequential-each ((cl-cc/javascript::%js-string-replace "aaa" "a" "b" "baa")
                     (cl-cc/javascript::%js-string-replace-all "aaa" "a" "b" "bbb"))
    "js-rt-string-replace ~A"
    (fn s pat rep expected)
  (expect (funcall (symbol-function fn) s pat rep) :to-equal expected))

(it-sequential "js-rt-method-resolution-string"
  (let* ((s "hello")
         (upper-fn (cl-cc/javascript::%js-get-prop s "toUpperCase")))
    (expect (functionp upper-fn) :to-be-truthy)
    (expect (funcall upper-fn) :to-equal "HELLO")))

;;; ─── Math ────────────────────────────────────────────────────────────────────

(it-sequential-each ((cl-cc/javascript::%js-math-abs (-5) 5)
                     (cl-cc/javascript::%js-math-floor (3.7d0) 3)
                     (cl-cc/javascript::%js-math-ceil (3.2d0) 4)
                     (cl-cc/javascript::%js-math-sign (-7) -1)
                     (cl-cc/javascript::%js-math-sign (0) 0)
                     (cl-cc/javascript::%js-math-sign (7) 1))
    "js-rt-math-unary ~A ~S"
    (fn args expected)
  (expect (= expected (apply (symbol-function fn) args)) :to-be-truthy))

(it-sequential-each ((cl-cc/javascript::%js-math-max (3 9 1) 9)
                     (cl-cc/javascript::%js-math-min (3 9 1) 1)
                     (cl-cc/javascript::%js-math-pow (2 3) 8)
                     (cl-cc/javascript::%js-math-sqrt (9) 3.0d0))
    "js-rt-math-binary ~A"
    (fn args expected)
  (expect (= expected (apply (symbol-function fn) args)) :to-be-truthy))

(it-sequential "js-rt-math-max-min-empty"
  (expect (cl-cc/javascript::%js-float-infinity-p
                (cl-cc/javascript::%js-math-min)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-infinity-p
                (cl-cc/javascript::%js-math-max)) :to-be-truthy)
  (expect (plusp (cl-cc/javascript::%js-math-min)) :to-be-truthy)
  (expect (minusp (cl-cc/javascript::%js-math-max)) :to-be-truthy))

(it-sequential "js-rt-math-negative-and-special-inputs"
  (expect (cl-cc/javascript::%js-float-nan-p
                (cl-cc/javascript::%js-math-sqrt -1.0d0)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-nan-p
                (cl-cc/javascript::%js-math-log -1.0d0)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-nan-p
                (cl-cc/javascript::%js-math-log2 -1.0d0)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-nan-p
                (cl-cc/javascript::%js-math-log10 -1.0d0)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-nan-p
                (cl-cc/javascript::%js-math-f16round cl-cc/javascript::*js-nan-float*)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-infinity-p
                (cl-cc/javascript::%js-math-f16round cl-cc/javascript::*js-inf-float*)) :to-be-truthy)
  (expect (= 0.0d0 (cl-cc/javascript::%js-math-f16round 0.0d0)) :to-be-truthy)
  (expect (= 0.0d0 (cl-cc/javascript::%js-math-f16round 1.0d-8)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-infinity-p
                (cl-cc/javascript::%js-math-f16round 65520.0d0)) :to-be-truthy))

(it-sequential "js-rt-math-special-value-branches"
  (expect (cl-cc/javascript::%js-float-nan-p
                (cl-cc/javascript::%js-math-abs cl-cc/javascript::*js-nan-float*)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-nan-p
                (cl-cc/javascript::%js-math-sign cl-cc/javascript::*js-nan-float*)) :to-be-truthy)
  (dolist (fn (list #'cl-cc/javascript::%js-math-floor
                    #'cl-cc/javascript::%js-math-ceil
                    #'cl-cc/javascript::%js-math-trunc
                    #'cl-cc/javascript::%js-math-round))
    (expect (cl-cc/javascript::%js-float-nan-p
                  (funcall fn cl-cc/javascript::*js-nan-float*)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-float-infinity-p
                  (funcall fn cl-cc/javascript::*js-inf-float*)) :to-be-truthy))
  (expect (cl-cc/javascript::%js-float-nan-p
                (cl-cc/javascript::%js-math-max 1 cl-cc/javascript::*js-nan-float* 3)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-nan-p
                (cl-cc/javascript::%js-math-min 1 cl-cc/javascript::*js-nan-float* 3)) :to-be-truthy))

(it-sequential "js-rt-math-f16round"
  (expect (= 1.3369140625d0 (cl-cc/javascript::%js-math-f16round 1.337d0)) :to-be-truthy)
  (expect (= 5.05078125d0 (cl-cc/javascript::%js-math-f16round 5.05d0)) :to-be-truthy)
  (expect (= 0.0d0 (cl-cc/javascript::%js-math-f16round -1.0d-8)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-infinity-p
    (cl-cc/javascript::%js-math-f16round -65520.0d0)) :to-be-truthy)
  (expect (cl-cc/javascript::%js-float-infinity-p
    (cl-cc/javascript::%js-math-f16round 65520.0d0)) :to-be-truthy))

(it-sequential "js-rt-math-round-half-even"
  (expect (= 2 (cl-cc/javascript::%js-round-half-even 2.5d0)) :to-be-truthy)
  (expect (= 4 (cl-cc/javascript::%js-round-half-even 3.5d0)) :to-be-truthy)
  (expect (= -2 (cl-cc/javascript::%js-round-half-even -2.5d0)) :to-be-truthy)
  (expect (= -4 (cl-cc/javascript::%js-round-half-even -3.5d0)) :to-be-truthy))

(it-sequential-each ((cl-cc/javascript::%js-math-sinh 0 0.0d0)
                     (cl-cc/javascript::%js-math-cosh 0 1.0d0)
                     (cl-cc/javascript::%js-math-tanh 0 0.0d0)
                     (cl-cc/javascript::%js-math-cbrt 8 2.0d0)
                     (cl-cc/javascript::%js-math-expm1 0 0.0d0)
                     (cl-cc/javascript::%js-math-log1p 0 0.0d0))
    "js-rt-math-extended-unary ~A"
    (fn x expected)
  (expect (< (abs (- expected (funcall (symbol-function fn) x))) 1.0d-10) :to-be-truthy))

(it-sequential-each ((cl-cc/javascript::%js-math-round 1.5d0 2.0d0)
                     (cl-cc/javascript::%js-math-trunc 3.7d0 3.0d0))
    "js-rt-math-round-trunc ~A"
    (fn x expected)
  (expect (= expected (funcall (symbol-function fn) x)) :to-be-truthy))

(it-sequential-each ((cl-cc/javascript::%js-math-sin 0.0d0 0.0d0)
                     (cl-cc/javascript::%js-math-cos 0.0d0 1.0d0)
                     (cl-cc/javascript::%js-math-tan 0.0d0 0.0d0)
                     (cl-cc/javascript::%js-math-asin 0.0d0 0.0d0)
                     (cl-cc/javascript::%js-math-acos 1.0d0 0.0d0)
                     (cl-cc/javascript::%js-math-atan 0.0d0 0.0d0))
    "js-rt-math-trig-basics ~A"
    (fn x expected)
  (expect (< (abs (- expected (funcall (symbol-function fn) x))) 1.0d-10) :to-be-truthy))

(it-sequential "js-rt-math-atan2"
  (let ((result (cl-cc/javascript::%js-math-atan2 1.0d0 1.0d0)))
    (expect (< (abs (- result (atan 1.0d0))) 1.0d-10) :to-be-truthy)))

(it-sequential-each ((cl-cc/javascript::%js-math-exp 0.0d0 1.0d0)
                     (cl-cc/javascript::%js-math-log 1.0d0 0.0d0)
                     (cl-cc/javascript::%js-math-log2 8.0d0 3.0d0)
                     (cl-cc/javascript::%js-math-log10 1000.0d0 3.0d0))
    "js-rt-math-exp-log ~A"
    (fn x expected)
  (expect (< (abs (- expected (funcall (symbol-function fn) x))) 1.0d-10) :to-be-truthy))

(it-sequential "js-rt-math-clz32-zero"
  (expect (= 32 (cl-cc/javascript::%js-math-clz32 0)) :to-be-truthy))

(it-sequential "js-rt-math-imul-sign-extension"
  (expect (= -2 (cl-cc/javascript::%js-math-imul -1 2)) :to-be-truthy))

(it-sequential-each ((cl-cc/javascript::%js-math-hypot (3.0d0 4.0d0) 5.0d0)
                     (cl-cc/javascript::%js-math-clz32 (1.0d0) 31.0d0)
                     (cl-cc/javascript::%js-math-imul (3.0d0 4.0d0) 12.0d0))
    "js-rt-math-hypot-clz32-fround-imul ~A"
    (fn args expected)
  (expect (= expected (apply (symbol-function fn) args)) :to-be-truthy))

(it-sequential "js-rt-math-fround"
  (let* ((input 1.337d0)
         (expected (coerce (coerce input 'single-float) 'double-float)))
    (expect (< (abs (- expected (cl-cc/javascript::%js-math-fround input))) 1.0d-10) :to-be-truthy)))

(it-sequential "js-rt-math-random-range"
  (let ((value (cl-cc/javascript::%js-math-random)))
    (expect (<= 0.0d0 value) :to-be-truthy)
    (expect (< value 1.0d0) :to-be-truthy)))

;;; ─── Number.prototype methods ────────────────────────────────────────────────

(it-sequential-each ((3.14159d0 0 "3") (3.14159d0 2 "3.14") (42.0d0 0 "42"))
    "js-rt-number-to-fixed ~A ~A"
    (n digits expected)
  (let* ((method (cl-cc/javascript::%js-resolve-number-method n "toFixed"))
         (result (funcall method digits)))
    (expect result :to-equal expected)))

(it-sequential-each ((255 10 "255") (255 16 "ff") (8 2 "1000"))
    "js-rt-number-to-string-radix ~A ~A"
    (n radix expected)
  (let* ((method (cl-cc/javascript::%js-resolve-number-method n "toString"))
         (result (funcall method radix)))
    (expect result :to-equal expected)))

(it-sequential-each ((123.456d0 1 "1e+2") (123.456d0 3 "123")
                     (3.14159d0 6 "3.14159") (0.0d0 3 "0.00"))
    "js-rt-number-to-precision ~A ~A"
    (n prec expected)
  (expect (cl-cc/javascript::%js-number-to-precision n prec) :to-equal expected))

;;; ─── Number format helpers ───────────────────────────────────────────────────

(it-sequential-each (("8." "8") ("3.14" "3.14") ("" "") ("." ""))
    "js-rt-strip-trailing-dot ~S"
    (input expected)
  (expect (cl-cc/javascript::%js-strip-trailing-dot input) :to-equal expected))

(it-sequential-each (("1.e+2" "1e+2") ("2.E+3" "2E+3")
                     ("1.2e+3" "1.2e+3") ("3.14" "3.14"))
    "js-rt-strip-pre-exp-dot ~S"
    (input expected)
  (expect (cl-cc/javascript::%js-strip-pre-exp-dot input) :to-equal expected))

;;; ─── Number strict predicates ────────────────────────────────────────────────

(it-sequential "js-rt-number-is-nan nan"
  (destructuring-bind (val expected) (list cl-cc/javascript::*js-nan-float* t)
    (expect (cl-cc/javascript::%js-number-is-nan val) :to-equal expected)))

(it-sequential "js-rt-number-is-nan string"
  (destructuring-bind (val expected) (list "NaN" nil)
    (expect (cl-cc/javascript::%js-number-is-nan val) :to-equal expected)))

(it-sequential "js-rt-number-is-nan number"
  (destructuring-bind (val expected) (list 42 nil)
    (expect (cl-cc/javascript::%js-number-is-nan val) :to-equal expected)))

(it-sequential "js-rt-number-is-finite int"
  (destructuring-bind (val expected) (list 42 t)
    (expect (cl-cc/javascript::%js-number-is-finite val) :to-equal expected)))

(it-sequential "js-rt-number-is-finite float"
  (destructuring-bind (val expected) (list 3.14d0 t)
    (expect (cl-cc/javascript::%js-number-is-finite val) :to-equal expected)))

(it-sequential "js-rt-number-is-finite nan"
  (destructuring-bind (val expected) (list cl-cc/javascript::*js-nan-float* nil)
    (expect (cl-cc/javascript::%js-number-is-finite val) :to-equal expected)))

(it-sequential "js-rt-number-is-finite inf"
  (destructuring-bind (val expected) (list cl-cc/javascript::*js-inf-float* nil)
    (expect (cl-cc/javascript::%js-number-is-finite val) :to-equal expected)))

(it-sequential "js-rt-number-is-finite string"
  (destructuring-bind (val expected) (list "42" nil)
    (expect (cl-cc/javascript::%js-number-is-finite val) :to-equal expected)))

(it-sequential-each ((42 t) (3.0d0 t) (3.5d0 nil) ("3" nil))
    "js-rt-number-is-integer ~S"
    (val expected)
  (expect (cl-cc/javascript::%js-number-is-integer val) :to-equal expected))

;;; ─── parseInt / parseFloat ───────────────────────────────────────────────────

;;; The NaN cases below are kept as separate it-sequential forms rather than
;;; joining the numeric table: mixing a :nan keyword sentinel into a case
;;; list otherwise typed NUMBER makes SBCL derive a NUMBER/KEYWORD union type
;;; for the shared body's arithmetic, which it cannot narrow back down
;;; through the (eq expected :nan) guard — a real compile-time type error,
;;; not just a style nit.

(it-sequential-each (("42" 10 42) ("ff" 16 255) ("101" 2 5))
    "js-rt-parse-int ~S"
    (str radix expected)
  (expect (= expected (cl-cc/javascript::%js-parse-int str radix)) :to-be-truthy))

(it-sequential "js-rt-parse-int \"abc\""
  (expect (cl-cc/javascript::%js-nan-p (cl-cc/javascript::%js-parse-int "abc" 10)) :to-be-truthy))

(it-sequential-each (("3.14" 3.14d0) ("3.14abc" 3.14d0) ("42" 42.0d0))
    "js-rt-parse-float ~S"
    (str expected)
  (expect (< (abs (- expected (cl-cc/javascript::%js-parse-float str))) 1.0d-10) :to-be-truthy))

(it-sequential "js-rt-parse-float \"abc\""
  (expect (cl-cc/javascript::%js-nan-p (cl-cc/javascript::%js-parse-float "abc")) :to-be-truthy))

;;; ─── String coverage — uncovered functions ───────────────────────────────────

(it-sequential "js-rt-string-length"
  (expect (zerop (cl-cc/javascript::%js-string-length "")) :to-be-truthy)
  (expect (= 5 (cl-cc/javascript::%js-string-length "hello")) :to-be-truthy))

(it-sequential-each (("a,b,c" "," ("a" "b" "c"))
                     ("a,,b" "," ("a" "" "b"))
                     ("abc" "," ("abc")))
    "js-rt-string-split-separator ~S"
    (s sep expected)
  (expect (%jr-list (cl-cc/javascript::%js-string-split s sep)) :to-equal expected))

(it-sequential "js-rt-string-split-limit"
  (let ((parts (%jr-list (cl-cc/javascript::%js-string-split "a,b,c,d" "," 2))))
    (expect (= 2 (length parts)) :to-be-truthy)
    (expect (first parts) :to-equal "a")
    (expect (second parts) :to-equal "b")))

(it-sequential-each (("hello world" "world" "world") ("hello" "xyz" :null))
    "js-rt-string-match-cases ~S"
    (s pat expected)
  (let ((result (cl-cc/javascript::%js-string-match s pat)))
    (if (eq expected :null)
        (expect result :to-be cl-cc/javascript::+js-null+)
        (expect (aref result 0) :to-equal expected))))

(it-sequential "js-rt-string-match-all-multiple"
  (let ((all (cl-cc/javascript::%js-string-match-all "abab" "ab")))
    (expect (= 2 (length all)) :to-be-truthy)
    (expect (aref (aref all 0) 0) :to-equal "ab")
    (expect (aref (aref all 1) 0) :to-equal "ab")))

(it-sequential-each (("hello" "ll" 2) ("hello" "xyz" -1))
    "js-rt-string-search-index ~A ~A"
    (s pat expected)
  (expect (= expected (cl-cc/javascript::%js-string-search s pat)) :to-be-truthy))

(it-sequential "js-rt-string-normalize"
  (let* ((acute (string (code-char #x0301)))
         (composed-e (string (code-char #x00E9)))
         (decomposed-e (concatenate 'string "e" acute))
         (angstrom-sign (string (code-char #x212B)))
         (angstrom-letter (string (code-char #x00C5)))
         (fi-ligature (string (code-char #xFB01))))
    (expect (cl-cc/javascript::%js-string-normalize decomposed-e) :to-equal composed-e)
    (expect (cl-cc/javascript::%js-string-normalize composed-e "NFD") :to-equal decomposed-e)
    (expect (cl-cc/javascript::%js-string-normalize angstrom-sign "NFKC") :to-equal angstrom-letter)
    (expect (cl-cc/javascript::%js-string-normalize fi-ligature "NFKD") :to-equal "fi")
    (signals error (cl-cc/javascript::%js-string-normalize "cafe" "BAD"))))

(it-sequential-each (("a" "b" -1.0d0) ("x" "x" 0.0d0) ("b" "a" 1.0d0))
    "js-rt-string-locale-compare-order ~A ~A"
    (a b expected)
  (expect (= expected (cl-cc/javascript::%js-string-locale-compare a b)) :to-be-truthy))

(it-sequential "js-rt-string-raw-tag"
  (let* ((raw    (%jr-arr "hello " " world"))
         (result (cl-cc/javascript::%js-string-raw raw "JS")))
    (expect result :to-equal "hello JS world")))

(it-sequential-each (("hello" 1 3 "el") ("hello" 0 100 "hello") ("hello" 3 1 "el"))
    "js-rt-string-substring-cases ~*~A ~A"
    (s a b expected)
  (expect (cl-cc/javascript::%js-string-substring s a b) :to-equal expected))

(it-sequential-each ((cl-cc/javascript::%js-string-to-locale-upper-case "hello" "HELLO")
                     (cl-cc/javascript::%js-string-to-locale-lower-case "HELLO" "hello"))
    "js-rt-string-locale-case ~A"
    (fn input expected)
  (expect (funcall (symbol-function fn) input) :to-equal expected))
