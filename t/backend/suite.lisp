(in-package #:cl-cc/javascript/backend/test)

(describe-concurrent "JavaScript Backend"
  (%register-backend-runtime-builtins-platform-tests)
  (%register-backend-runtime-method-resolver-dispatch-tests)
  (%register-backend-runtime-misc-tests)
  (%register-backend-runtime-absent-builtins-tests)
  (%register-backend-runtime-objects-builtin-tests)
  (it-sequential-each ((cl-cc/javascript/backend:%js-math-sinh 0 0.0d0)
                       (cl-cc/javascript/backend:%js-math-cosh 0 1.0d0)
                       (cl-cc/javascript/backend:%js-math-tanh 0 0.0d0)
                       (cl-cc/javascript/backend:%js-math-cbrt 8 2.0d0)
                       (cl-cc/javascript/backend:%js-math-expm1 0 0.0d0)
                       (cl-cc/javascript/backend:%js-math-log1p 0 0.0d0))
      "js-rt-math-extended-unary ~A"
      (fn x expected)
    (expect (< (abs (- expected (funcall (symbol-function fn) x))) 1.0d-10) :to-be-truthy))
  (it-sequential-each ((3.14159d0 0 "3") (3.14159d0 2 "3.14") (42.0d0 0 "42"))
      "js-rt-number-to-fixed ~A ~A"
      (n digits expected)
    (let* ((method (cl-cc/javascript/backend:%js-resolve-number-method n "toFixed"))
           (result (funcall method digits)))
      (expect result :to-equal expected)))
  (it-sequential-each ((255 10 "255") (255 16 "ff") (8 2 "1000"))
      "js-rt-number-to-string-radix ~A ~A"
      (n radix expected)
    (let* ((method (cl-cc/javascript/backend:%js-resolve-number-method n "toString"))
           (result (funcall method radix)))
      (expect result :to-equal expected)))
  (it-sequential-each ((123.456d0 1 "1e+2") (123.456d0 3 "123")
                       (3.14159d0 6 "3.14159") (0.0d0 3 "0.00"))
      "js-rt-number-to-precision ~A ~A"
      (n prec expected)
    (expect (cl-cc/javascript/backend:%js-number-to-precision n prec) :to-equal expected))
  (it-sequential-each (("8." "8") ("3.14" "3.14") ("" "") ("." ""))
      "js-rt-strip-trailing-dot ~S"
      (input expected)
    (expect (cl-cc/javascript/backend:%js-strip-trailing-dot input) :to-equal expected))
  (it-sequential-each (("1.e+2" "1e+2") ("2.E+3" "2E+3")
                       ("1.2e+3" "1.2e+3") ("3.14" "3.14"))
      "js-rt-strip-pre-exp-dot ~S"
      (input expected)
    (expect (cl-cc/javascript/backend:%js-strip-pre-exp-dot input) :to-equal expected))
  (it-sequential "js-rt-number-is-nan nan"
    (destructuring-bind (val expected) (list cl-cc/javascript/objects:*js-nan-float* t)
      (expect (cl-cc/javascript/backend:%js-number-is-nan val) :to-equal expected)))
  (it-sequential "js-rt-number-is-nan string"
    (destructuring-bind (val expected) (list "NaN" nil)
      (expect (cl-cc/javascript/backend:%js-number-is-nan val) :to-equal expected)))
  (it-sequential "js-rt-number-is-nan number"
    (destructuring-bind (val expected) (list 42 nil)
      (expect (cl-cc/javascript/backend:%js-number-is-nan val) :to-equal expected)))
  (it-sequential "js-rt-number-is-finite int"
    (destructuring-bind (val expected) (list 42 t)
      (expect (cl-cc/javascript/backend:%js-number-is-finite val) :to-equal expected)))
  (it-sequential "js-rt-number-is-finite float"
    (destructuring-bind (val expected) (list 3.14d0 t)
      (expect (cl-cc/javascript/backend:%js-number-is-finite val) :to-equal expected)))
  (it-sequential "js-rt-number-is-finite nan"
    (destructuring-bind (val expected) (list cl-cc/javascript/objects:*js-nan-float* nil)
      (expect (cl-cc/javascript/backend:%js-number-is-finite val) :to-equal expected)))
  (it-sequential "js-rt-number-is-finite inf"
    (destructuring-bind (val expected) (list cl-cc/javascript/objects:*js-inf-float* nil)
      (expect (cl-cc/javascript/backend:%js-number-is-finite val) :to-equal expected)))
  (it-sequential "js-rt-number-is-finite string"
    (destructuring-bind (val expected) (list "42" nil)
      (expect (cl-cc/javascript/backend:%js-number-is-finite val) :to-equal expected)))
  (it-sequential-each ((42 t) (3.0d0 t) (3.5d0 nil) ("3" nil))
      "js-rt-number-is-integer ~S"
      (val expected)
    (expect (cl-cc/javascript/backend:%js-number-is-integer val) :to-equal expected))
)
