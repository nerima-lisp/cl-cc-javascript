;;;; packages/javascript/src/runtime-builtins-globals.lisp — JS global function implementations
;;;;
;;;; Global built-in functions: parseInt, parseFloat, isNaN, isFinite,
;;;; extended Math (sinh/cosh/tanh/cbrt/expm1/log1p),
;;;; Number strict predicates (Number.isNaN/isFinite/isInteger),
;;;; structuredClone / queueMicrotask globals,
;;;; BigInt helpers, Iterator.from, and Map.groupBy.
;;;; (String.raw itself lives in runtime-string.lisp -- this file used to
;;;; also define it, a duplicate defun that silently shadowed the real one
;;;; since this file loads later; removed 2026-07-31, see CHANGELOG.md.)
;;;;
;;;; Load order: after runtime-builtins.lisp (needs %js-to-number, %js-funcall,
;;;; %js-nan-p, %js-float-nan-p, %js-float-infinity-p, %js-to-string, etc.)
(in-package :cl-cc/javascript)

;;; -----------------------------------------------------------------------
;;;  Global function helpers (referenced in *js-builtin-specs* and js-program-forms)
;;; -----------------------------------------------------------------------
(defun %js-parse-int (s &optional (radix +js-undefined+))
  "JS parseInt(string, radix): parse a leading, optionally-signed integer
literal in RADIX. When RADIX is omitted (or explicitly 16), a \"0x\"/\"0X\"
prefix right after any sign is stripped and the effective radix becomes 16
-- auto hex detection, per spec; any OTHER explicit RADIX does NOT strip
it (parseInt(\"0x1F\", 10) stops at \"0\", per spec, not 31). Returns NaN
when no valid digit is found in the resulting radix."
  (handler-case
      (let* ((str (string-trim '(#\Space #\Tab #\Newline #\Return) (%js-to-string s)))
             (len (length str))
             (pos 0)
             (sign 1)
             (given-radix (%js-int-arg-or-default radix 0)))
        (when (and (< pos len) (member (char str pos) '(#\+ #\-)))
          (when (char= (char str pos) #\-) (setf sign -1))
          (incf pos))
        (let* ((strip-prefix-p (or (zerop given-radix) (= given-radix 16)))
               (r (if (zerop given-radix) 10 given-radix)))
          (when (and strip-prefix-p
                     (<= (+ pos 2) len)
                     (char= (char str pos) #\0)
                     (member (char str (1+ pos)) '(#\x #\X)))
            (incf pos 2)
            (setf r 16))
          (let ((val (parse-integer str :start pos :radix r :junk-allowed t)))
            (if val (* sign val) *js-nan-float*))))
    (error ()
      *js-nan-float*)))

(defun %js-parse-float (s)
  "JS parseFloat: parse the LONGEST leading numeric prefix of S (so \"3.14abc\"
-> 3.14), or NaN when there is no leading number."
  (let* ((str (string-trim '(#\Space #\Tab #\Newline #\Return) (%js-to-string s)))
         (len (length str)) (i 0) (saw-digit nil))
    (labels ((eat-digits ()
               (loop while (and (< i len) (digit-char-p (char str i)))
                     do (setf saw-digit t) (incf i))))
      (when (and (< i len) (member (char str i) '(#\+ #\-))) (incf i))
      (eat-digits)
      (when (and (< i len) (char= (char str i) #\.)) (incf i) (eat-digits))
      (unless saw-digit (return-from %js-parse-float *js-nan-float*))
      ;; optional exponent: e[+/-]digits — only consumed if well-formed
      (when (and (< i len) (member (char str i) '(#\e #\E)))
        (let ((save i))
          (incf i)
          (when (and (< i len) (member (char str i) '(#\+ #\-))) (incf i))
          (if (and (< i len) (digit-char-p (char str i)))
              (loop while (and (< i len) (digit-char-p (char str i))) do (incf i))
              (setf i save))))
      (handler-case
          (let ((*read-eval* nil)
                (*read-default-float-format* 'double-float))
            (let ((v (read-from-string (subseq str 0 i) nil *js-nan-float*)))
              (if (realp v) (coerce v 'double-float) *js-nan-float*)))
        (error () *js-nan-float*)))))

(defun %js-is-nan (x)
  "Return true if X converts to NaN."
  (%js-nan-p (%js-to-number x)))

(defun %js-is-finite (x)
  "Return true if X is finite (not NaN, not Infinity)."
  (let ((n (%js-to-number x)))
    (not (or (%js-float-nan-p n) (%js-float-infinity-p n)))))

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
;;;  Standalone global-builtin helpers (referenced in *js-builtin-specs*)
;;; -----------------------------------------------------------------------
(defun %js-structured-clone (val &rest _opts)
  "structuredClone(value[, options]): deep clone VAL (options ignored)."
  (declare (ignore _opts))
  (%js-deep-clone val))

(defun %js-queue-microtask (fn &rest _)
  "queueMicrotask(fn): synchronous in our single-threaded model."
  (declare (ignore _))
  (%js-funcall fn)
  +js-undefined+)

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

(defun %js-iterator-from-iterable (iterable)
  "Iterator.from(iterable): wrap any iterable/iterator in the Iterator protocol."
  (%js-add-iterator-helpers!
    (cond
      ((typep iterable 'js-map) (%js-map-entries iterable))
      ((typep iterable 'js-set)
        (%js-vec-to-iter (coerce (%js-set-keys iterable) 'vector)))
      ((and (%js-ht-p iterable) (gethash "next" iterable)) iterable)
      ((and (%js-ht-p iterable) (gethash "@@iterator" iterable))
        (%js-funcall (gethash "@@iterator" iterable)))
      ((%js-vec-p iterable)
        (%js-make-generator
          (lambda ()
            (loop for i below (length iterable)
                  do (%js-yield (aref iterable i))))))
      ((stringp iterable)
        (%js-make-generator
          (lambda ()
            (loop for ch across iterable
                  do (%js-yield (string ch))))))
      (t
        (%js-make-object
          "next"
          (lambda ()
            (%js-make-object "value" +js-undefined+ "done" t)))))))

(defun %js-map-group-by (iterable key-fn)
  "Map.groupBy(iterable, keyFn): group ITERABLE elements by KEY-FN result."
  (let ((result (%js-make-map)))
    (%js-group-into
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

