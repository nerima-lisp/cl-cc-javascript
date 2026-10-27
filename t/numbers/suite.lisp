(in-package #:cl-cc/javascript/numbers/test)

(defun %register-numbers-runtime-builtins-tests ()
  (it-sequential-each ((#.cl-cc/javascript/objects::*js-nan-float* t) ("NaN" t)
                         ("42" nil) (5 nil))
        "js-rt-global-is-nan ~A"
        (val expected)
      (expect (cl-cc/javascript/numbers:%js-is-nan val) :to-equal expected))
  (it-sequential-each ((42 t) ("3.14" t)
                         (#.cl-cc/javascript/objects::*js-nan-float* nil)
                         (#.cl-cc/javascript/objects::*js-inf-float* nil))
        "js-rt-global-is-finite ~A"
        (val expected)
      (expect (cl-cc/javascript/numbers:%js-is-finite val) :to-equal expected))
  (it-sequential "js-rt-math-sum-precise"
    (let ((result (cl-cc/javascript/numbers:%js-math-sum-precise (%jr-arr 1 2 3 4))))
      (expect (= 10.0d0 result) :to-be-truthy)))
  (it-sequential-each ((cl-cc/javascript/numbers:%js-math-abs (-5) 5)
                       (cl-cc/javascript/numbers:%js-math-floor (3.7d0) 3)
                       (cl-cc/javascript/numbers:%js-math-ceil (3.2d0) 4)
                       (cl-cc/javascript/numbers:%js-math-sign (-7) -1)
                       (cl-cc/javascript/numbers:%js-math-sign (0) 0)
                       (cl-cc/javascript/numbers:%js-math-sign (7) 1))
      "js-rt-math-unary ~A ~S"
      (fn args expected)
    (expect (= expected (apply (symbol-function fn) args)) :to-be-truthy))
  (it-sequential-each ((cl-cc/javascript/numbers:%js-math-max (3 9 1) 9)
                       (cl-cc/javascript/numbers:%js-math-min (3 9 1) 1)
                       (cl-cc/javascript/numbers:%js-math-pow (2 3) 8)
                       (cl-cc/javascript/numbers:%js-math-sqrt (9) 3.0d0))
      "js-rt-math-binary ~A"
      (fn args expected)
    (expect (= expected (apply (symbol-function fn) args)) :to-be-truthy))
  (it-sequential "js-rt-math-max-min-empty"
    (expect (%js-float-infinity-p
                  (cl-cc/javascript/numbers:%js-math-min)) :to-be-truthy)
    (expect (%js-float-infinity-p
                  (cl-cc/javascript/numbers:%js-math-max)) :to-be-truthy)
    (expect (plusp (cl-cc/javascript/numbers:%js-math-min)) :to-be-truthy)
    (expect (minusp (cl-cc/javascript/numbers:%js-math-max)) :to-be-truthy))
  (it-sequential "js-rt-math-negative-and-special-inputs"
    (expect (%js-float-nan-p
                  (cl-cc/javascript/numbers:%js-math-sqrt -1.0d0)) :to-be-truthy)
    (expect (%js-float-nan-p
                  (cl-cc/javascript/numbers:%js-math-log -1.0d0)) :to-be-truthy)
    (expect (%js-float-nan-p
                  (cl-cc/javascript/numbers:%js-math-log2 -1.0d0)) :to-be-truthy)
    (expect (%js-float-nan-p
                  (cl-cc/javascript/numbers:%js-math-log10 -1.0d0)) :to-be-truthy)
    (expect (%js-float-nan-p
                  (cl-cc/javascript/numbers:%js-math-f16round *js-nan-float*)) :to-be-truthy)
    (expect (%js-float-infinity-p
                  (cl-cc/javascript/numbers:%js-math-f16round *js-inf-float*)) :to-be-truthy)
    (expect (= 0.0d0 (cl-cc/javascript/numbers:%js-math-f16round 0.0d0)) :to-be-truthy)
    (expect (= 0.0d0 (cl-cc/javascript/numbers:%js-math-f16round 1.0d-8)) :to-be-truthy)
    (expect (%js-float-infinity-p
                  (cl-cc/javascript/numbers:%js-math-f16round 65520.0d0)) :to-be-truthy))
  (it-sequential "js-rt-math-special-value-branches"
    (expect (%js-float-nan-p
                  (cl-cc/javascript/numbers:%js-math-abs *js-nan-float*)) :to-be-truthy)
    (expect (%js-float-nan-p
                  (cl-cc/javascript/numbers:%js-math-sign *js-nan-float*)) :to-be-truthy)
    (dolist (fn (list #'cl-cc/javascript/numbers:%js-math-floor
                      #'cl-cc/javascript/numbers:%js-math-ceil
                      #'cl-cc/javascript/numbers:%js-math-trunc
                      #'cl-cc/javascript/numbers:%js-math-round))
      (expect (%js-float-nan-p
                    (funcall fn *js-nan-float*)) :to-be-truthy)
      (expect (%js-float-infinity-p
                    (funcall fn *js-inf-float*)) :to-be-truthy))
    (expect (%js-float-nan-p
                  (cl-cc/javascript/numbers:%js-math-max 1 *js-nan-float* 3)) :to-be-truthy)
    (expect (%js-float-nan-p
                  (cl-cc/javascript/numbers:%js-math-min 1 *js-nan-float* 3)) :to-be-truthy))
  (it-sequential "js-rt-math-f16round"
    (expect (= 1.3369140625d0 (cl-cc/javascript/numbers:%js-math-f16round 1.337d0)) :to-be-truthy)
    (expect (= 5.05078125d0 (cl-cc/javascript/numbers:%js-math-f16round 5.05d0)) :to-be-truthy)
    (expect (= 0.0d0 (cl-cc/javascript/numbers:%js-math-f16round -1.0d-8)) :to-be-truthy)
    (expect (%js-float-infinity-p
      (cl-cc/javascript/numbers:%js-math-f16round -65520.0d0)) :to-be-truthy)
    (expect (%js-float-infinity-p
      (cl-cc/javascript/numbers:%js-math-f16round 65520.0d0)) :to-be-truthy))
  (it-sequential "js-rt-math-round-half-even"
    (expect (= 2 (cl-cc/javascript/numbers:%js-round-half-even 2.5d0)) :to-be-truthy)
    (expect (= 4 (cl-cc/javascript/numbers:%js-round-half-even 3.5d0)) :to-be-truthy)
    (expect (= -2 (cl-cc/javascript/numbers:%js-round-half-even -2.5d0)) :to-be-truthy)
    (expect (= -4 (cl-cc/javascript/numbers:%js-round-half-even -3.5d0)) :to-be-truthy))
  (it-sequential-each ((cl-cc/javascript/numbers:%js-math-round 1.5d0 2.0d0)
                       (cl-cc/javascript/numbers:%js-math-trunc 3.7d0 3.0d0))
      "js-rt-math-round-trunc ~A"
      (fn x expected)
    (expect (= expected (funcall (symbol-function fn) x)) :to-be-truthy))
  (it-sequential-each ((cl-cc/javascript/numbers:%js-math-sin 0.0d0 0.0d0)
                       (cl-cc/javascript/numbers:%js-math-cos 0.0d0 1.0d0)
                       (cl-cc/javascript/numbers:%js-math-tan 0.0d0 0.0d0)
                       (cl-cc/javascript/numbers:%js-math-asin 0.0d0 0.0d0)
                       (cl-cc/javascript/numbers:%js-math-acos 1.0d0 0.0d0)
                       (cl-cc/javascript/numbers:%js-math-atan 0.0d0 0.0d0))
      "js-rt-math-trig-basics ~A"
      (fn x expected)
    (expect (< (abs (- expected (funcall (symbol-function fn) x))) 1.0d-10) :to-be-truthy))
  (it-sequential "js-rt-math-atan2"
    (let ((result (cl-cc/javascript/numbers:%js-math-atan2 1.0d0 1.0d0)))
      (expect (< (abs (- result (atan 1.0d0))) 1.0d-10) :to-be-truthy)))
  (it-sequential-each ((cl-cc/javascript/numbers:%js-math-exp 0.0d0 1.0d0)
                       (cl-cc/javascript/numbers:%js-math-log 1.0d0 0.0d0)
                       (cl-cc/javascript/numbers:%js-math-log2 8.0d0 3.0d0)
                       (cl-cc/javascript/numbers:%js-math-log10 1000.0d0 3.0d0))
      "js-rt-math-exp-log ~A"
      (fn x expected)
    (expect (< (abs (- expected (funcall (symbol-function fn) x))) 1.0d-10) :to-be-truthy))
  (it-sequential "js-rt-math-clz32-zero"
    (expect (= 32 (cl-cc/javascript/numbers:%js-math-clz32 0)) :to-be-truthy))
  (it-sequential "js-rt-math-imul-sign-extension"
    (expect (= -2 (cl-cc/javascript/numbers:%js-math-imul -1 2)) :to-be-truthy))
  (it-sequential-each ((cl-cc/javascript/numbers:%js-math-hypot (3.0d0 4.0d0) 5.0d0)
                       (cl-cc/javascript/numbers:%js-math-clz32 (1.0d0) 31.0d0)
                       (cl-cc/javascript/numbers:%js-math-imul (3.0d0 4.0d0) 12.0d0))
      "js-rt-math-hypot-clz32-fround-imul ~A"
      (fn args expected)
    (expect (= expected (apply (symbol-function fn) args)) :to-be-truthy))
  (it-sequential "js-rt-math-fround"
    (let* ((input 1.337d0)
           (expected (coerce (coerce input 'single-float) 'double-float)))
      (expect (< (abs (- expected (cl-cc/javascript/numbers:%js-math-fround input))) 1.0d-10) :to-be-truthy)))
  (it-sequential "js-rt-math-random-range"
    (let ((value (cl-cc/javascript/numbers:%js-math-random)))
      (expect (<= 0.0d0 value) :to-be-truthy)
      (expect (< value 1.0d0) :to-be-truthy)))
  (it-sequential-each (("42" 10 42) ("ff" 16 255) ("101" 2 5))
      "js-rt-parse-int ~S"
      (str radix expected)
    (expect (= expected (cl-cc/javascript/numbers:%js-parse-int str radix)) :to-be-truthy))
  (it-sequential "js-rt-parse-int \"abc\""
    (expect (%js-nan-p (cl-cc/javascript/numbers:%js-parse-int "abc" 10)) :to-be-truthy))
  (it-sequential-each (("3.14" 3.14d0) ("3.14abc" 3.14d0) ("42" 42.0d0))
      "js-rt-parse-float ~S"
      (str expected)
    (expect (< (abs (- expected (cl-cc/javascript/numbers:%js-parse-float str))) 1.0d-10) :to-be-truthy))
  (it-sequential "js-rt-parse-float \"abc\""
    (expect (%js-nan-p (cl-cc/javascript/numbers:%js-parse-float "abc")) :to-be-truthy))
)

(describe-concurrent "JavaScript Numbers" (%register-numbers-runtime-builtins-tests))
