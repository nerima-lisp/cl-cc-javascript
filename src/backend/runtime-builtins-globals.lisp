;;;; packages/javascript/src/runtime-builtins-globals.lisp — JS global function implementations
;;;;
;;;; Global built-in functions: parseInt, parseFloat, isNaN, isFinite,
;;;; extended Math (sinh/cosh/tanh/cbrt/expm1/log1p),
;;;; Number strict predicates (Number.isNaN/isFinite/isInteger),
;;;; structuredClone / queueMicrotask globals,
;;;; BigInt helpers, Iterator.from, and Map.groupBy.
;;;; (String.raw itself lives in runtime-string.lisp -- this file used to
;;;; also define it, a duplicate defun that silently shadowed the real one
;;;; since this file loads later; removed 2026-07-31, see the release notes.)
;;;;
;;;; Load order: after runtime-builtins.lisp (needs %js-to-number, %js-funcall,
;;;; %js-nan-p, %js-float-nan-p, %js-float-infinity-p, %js-to-string, etc.)
(in-package #:cl-cc/javascript/backend)

;;; -----------------------------------------------------------------------
;;;  Math coerce-unary helpers
;;; -----------------------------------------------------------------------
(defmacro define-js-math-coerce-unary (name cl-fn)
  "Define a unary JS Math helper that coerces its argument to double-float."
  `(defun ,name (x)
    (,cl-fn (coerce (%js-to-number x) 'double-float))))

(define-js-math-coerce-unary %js-math-sinh sinh)

(define-js-math-coerce-unary %js-math-cosh cosh)

(define-js-math-coerce-unary %js-math-tanh tanh)

(define-js-math-coerce-unary %js-math-asinh asinh)

(define-js-math-coerce-unary %js-math-acosh acosh)

(define-js-math-coerce-unary %js-math-atanh atanh)

(defun %js-math-cbrt (x)
  (let ((v (coerce (%js-to-number x) 'double-float)))
    (if (minusp v) (- (expt (- v) (/ 1.0d0 3.0d0)))
      (expt v (/ 1.0d0 3.0d0)))))

(defun %js-math-expm1 (x)
  (- (exp (coerce (%js-to-number x) 'double-float)) 1.0d0))

(defun %js-math-log1p (x)
  (log (+ 1.0d0 (coerce (%js-to-number x) 'double-float))))

;;; -----------------------------------------------------------------------
;;;  Number.isNaN / isFinite / isInteger strict predicates
;;; -----------------------------------------------------------------------
(defun %js-number-is-nan (x)
  (%js-float-nan-p x))

(defun %js-number-is-finite (x)
  (and (numberp x) (not (%js-float-nan-p x)) (not (%js-float-infinity-p x))))

(defun %js-number-is-integer (x)
  (and (numberp x) (not (%js-float-nan-p x)) (= x (truncate x))))

;;; -----------------------------------------------------------------------
;;;  Complex built-in helpers
;;; -----------------------------------------------------------------------
(defun %js-bigint-as-int-n (width bigint)
  "BigInt.asIntN(width, bigint): mask BIGINT to WIDTH-bit signed integer."
  (let* ((w (truncate (%js-to-number width)))
         (modulus (expt 2 w))
         (masked (mod (%js-bigint-val bigint) modulus)))
    (%make-js-bigint
      (if (>= masked (expt 2 (1- w))) (- masked modulus)
        masked))))

(defun %js-bigint-as-uint-n (width bigint)
  "BigInt.asUintN(width, bigint): mask BIGINT to WIDTH-bit unsigned integer."
  (%make-js-bigint
    (mod (%js-bigint-val bigint) (expt 2 (truncate (%js-to-number width))))))

(defun %js-map-group-by (iterable key-fn)
  "Map.groupBy(iterable, keyFn): group ITERABLE elements by KEY-FN result."
  (let ((result (%js-make-map)))
    (%js-object-group-into
      (lambda (visit)
        (%js-for-of
          iterable
          (lambda (item)
            (funcall visit (%js-funcall key-fn item) item))))
      (lambda (key)
        (let ((bucket (%js-map-get result key)))
          (if (eq bucket +js-undefined+) (let ((fresh (%js-make-vec 0)))
              (%js-map-set result key fresh)
              fresh)
            bucket))))
    result))

