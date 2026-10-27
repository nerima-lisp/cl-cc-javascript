;;; Object algorithms and structured clone live in runtime-object-ops.lisp.

(in-package #:cl-cc/javascript/objects)

(defconstant +js-undefined+ :js-undefined)

(defconstant +js-null+ :js-null)

(defconstant +js-nan+ :js-nan)

(defconstant +js-infinity+ :js-infinity)

(defconstant +js-neg-infinity+ :js-neg-infinity)

(declaim (type double-float *js-nan-float* *js-inf-float* *js-neg-inf-float*))

(defparameter *js-nan-float* (sb-kernel:make-double-float #x7FF80000 0))

(defparameter *js-inf-float* (sb-kernel:make-double-float #x7FF00000 0))

(defparameter *js-neg-inf-float* (sb-kernel:make-double-float -1048576 0))

(defun %js-make-ht (&optional (size 8))
  (make-hash-table :test #'equal :size size))

(defun %js-make-vec (&optional (size 0))
  (make-array size :element-type t :adjustable t :fill-pointer size))

(defun %js-vec-p (x)
  (and (vectorp x) (not (stringp x))))

(defun %js-ht-p (x)
  (hash-table-p x))

(defun %js-float-nan-p (x)
  "NaN test that inspects the bit pattern rather than comparing.

The self-comparison idiom is not portable here: comparing a NaN raises
FLOATING-POINT-INVALID-OPERATION wherever the :INVALID trap is enabled, which is
SBCL's default on x86-64. ARM64 does not take the trap, so (/= x x) looks correct
on macOS and turns every NaN-valued test into an error on Linux CI."
  (and (floatp x) (sb-ext:float-nan-p x)))

(defun %js-float-infinity-p (x)
  "Infinity test that inspects the bit pattern rather than comparing.

The magnitude comparison traps on a NaN argument for the reason given in
%JS-FLOAT-NAN-P, and callers do reach here with NaN."
  (and (floatp x) (not (sb-ext:float-nan-p x)) (sb-ext:float-infinity-p x)))

(defun %js-nan-p (x)
  (or (eq x :js-nan) (%js-float-nan-p x)))

(defstruct (js-bigint (:constructor %make-js-bigint (value))) (value 0 :type integer))

(defun %js-truthy (x)
  "JS truthiness: false, 0, NaN, \"\", null, undefined are falsy."
  (not (or (null x)
           (eq x +js-undefined+)
           (eq x +js-null+)
           ;; %js-nan-p, not (eq x :js-nan): the NaN literal is a float NaN
           ;; (*js-nan-float*), not the keyword sentinel, so a bare (eq x :js-nan)
           ;; missed it and `NaN ? a : b' / `if (NaN)' tested truthy.
           (%js-nan-p x)
           (eql x 0)
           (eql x 0.0d0)
           (eql x -0.0d0)
           (equal x ""))))

(defun %js-not-nullish (x)
  "True if X is not null or undefined."
  (not (or (eq x +js-null+) (eq x +js-undefined+))))

(defun %js-to-number (x)
  "JS ToNumber coercion."
  (cond
    ((numberp x)             (coerce x 'double-float))
    ((eq x +js-undefined+)  *js-nan-float*)
    ((eq x +js-null+)       0.0d0)
    ((eq x t)               1.0d0)
    ((null x)             0.0d0)
    ((eq x :js-nan)         *js-nan-float*)
    ((eq x :js-infinity)    *js-inf-float*)
    ((eq x :js-neg-infinity)*js-neg-inf-float*)
    ((stringp x)
     (let* ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return) x))
            (val (if (string= trimmed "")
                     0.0d0
                     ;; SECURITY: bind *read-eval* to nil so a string such as
                     ;; "#.(...)" cannot trigger read-time code execution, and
                     ;; require the parsed datum to be a real number (read can
                     ;; otherwise yield symbols/lists) — JS ToNumber must only
                     ;; ever produce a number or NaN.
                     (handler-case
                         ;; *read-default-float-format* double: "3.14" must read
                         ;; as 3.14d0, not a single-float (which loses precision:
                         ;; 3.14 -> 3.1400001…).
                         (let* ((*read-eval* nil)
                                (*read-default-float-format* 'double-float)
                                (datum (read-from-string trimmed)))
                           (if (realp datum)
                               (coerce datum 'double-float)
                               *js-nan-float*))
                       (error () *js-nan-float*)))))
       val))
    (t *js-nan-float*)))

(defun %js-int-arg-or-default (value default)
  "Coerce an optional integer argument: DEFAULT when VALUE is the JS
undefined sentinel (an omitted optional parameter), otherwise VALUE truncated
through JS ToNumber. Shared by every radix/digit-count-style optional integer
parameter (parseInt's radix, toFixed's digits, toString's radix, ...)."
  (if (eq value +js-undefined+) default
    (truncate (%js-to-number value))))

(defun %js-strict-eq (a b)
  "JS === strict equality, no coercion."
  (cond
    ;; Either operand being NaN makes === false, and neither may reach (=):
    ;; comparing a NaN raises FLOATING-POINT-INVALID-OPERATION where the
    ;; :INVALID trap is enabled. Testing for both operands being NaN is not
    ;; enough — (= NaN 5d0) traps exactly as (= NaN NaN) does.
    ((or (%js-nan-p a) (%js-nan-p b)) nil)  ; NaN !== anything, itself included
    ((and (numberp a) (numberp b)) (= a b))
    (t (equal a b))))

(defun %js-same-value-zero (a b)
  "ECMAScript SameValueZero equality for Map/Set-style key matching."
  (cond
    ((and (%js-nan-p a) (%js-nan-p b)) t)
    ;; Exactly one NaN: not the same value, and (=) must not see it. See
    ;; %JS-STRICT-EQ.
    ((or (%js-nan-p a) (%js-nan-p b)) nil)
    ((and (numberp a) (numberp b)) (= a b))
    (t (%js-strict-eq a b))))
