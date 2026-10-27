;;;; packages/javascript/src/runtime.lisp — JavaScript runtime builtins
;;;;
;;;; Implements JS semantics in Common Lisp.
;;;; JS objects  => CL hash tables (:test #'equal), key is string
;;;; JS arrays   => CL adjustable vectors (element-type t)
;;;; JS null     => :js-null
;;;; JS undefined=> :js-undefined
;;;; JS NaN      => :js-nan
;;;; JS Infinity => :js-infinity / :js-neg-infinity
;;;;
;;;; Private class fields  => stored in a nested HT under key "__private__"
(in-package #:cl-cc/javascript/expressions)

;;; -----------------------------------------------------------------------
;;;  Type constants
;;; -----------------------------------------------------------------------
;;; Real IEEE-754 double specials, built from raw bit patterns so SBCL never
;;; constant-folds a literal (/ 0.0d0 0.0d0) — which would trap at compile time
;;; with FLOATING-POINT-INVALID-OPERATION. make-double-float does no FP math.
; quiet NaN

; +Infinity

;;; -1048576 is #xFFF00000 read as a signed 32-bit high word.
; -Infinity

;;; -----------------------------------------------------------------------
;;;  Internal helpers
;;; -----------------------------------------------------------------------
;;; -----------------------------------------------------------------------
;;;  Type system
;;; -----------------------------------------------------------------------
;;; ─── BigInt struct (declared early so typeof/to-string can reference it) ─────
(defun %js-typeof (x)
  "Return JS typeof string for X."
  (cond
    ((eq x +js-undefined+)   "undefined")
    ((eq x +js-null+)        "object")       ; historic quirk
    ((eq x t)                "boolean")
    ((null x)              "boolean")
    ((stringp x)             "string")
    ((numberp x)             "number")
    ((eq x :js-nan)          "number")
    ((eq x :js-infinity)     "number")
    ((eq x :js-neg-infinity) "number")
    ((%js-vec-p x)           "object")
    ((%js-ht-p x)
     (let ((callable (gethash "__call__" x)))
       (if callable "function" "object")))
    ((functionp x)           "function")
    ;; Compiled JS functions are vm-closure-objects (not CL functions and not
    ;; hash-tables with __call__), so without this they fell through to the
    ;; default "object" — breaking the ubiquitous `typeof f === "function"`
    ;; feature-detection idiom.
    ((%js-vm-closure-p x)    "function")
    ;; Symbol — must come before the default "object" case
    ;; js-symbol-p is defined in runtime-symbol.lisp (loaded later), so use typep
    ((typep x 'js-symbol)    "symbol")
    ;; BigInt — defined in runtime-ops.lisp (loaded later), so use typep
    ((typep x 'js-bigint)    "bigint")
    (t                       "object")))

(defun %js-loose-eq (a b)
  "JS == with type coercion."
  (cond
    ;; NaN never equals anything — must be checked BEFORE (equal a b)
    ;; because (equal :js-nan :js-nan) is t for keyword sentinels.
    ((%js-nan-p a) nil)
    ((%js-nan-p b) nil)
    ;; strict identity first
    ((equal a b) t)
    ;; null == undefined
    ((and (eq a +js-null+) (eq b +js-undefined+)) t)
    ((and (eq a +js-undefined+) (eq b +js-null+)) t)
    ;; number == string  => coerce string to number
    ((and (numberp a) (stringp b))
     (%js-loose-eq a (%js-to-number b)))
    ((and (stringp a) (numberp b))
     (%js-loose-eq (%js-to-number a) b))
    ;; boolean => number
    ((eq a t)  (%js-loose-eq 1.0d0 b))
    ((null a) (%js-loose-eq 0.0d0 b))
    ((eq b t)  (%js-loose-eq a 1.0d0))
    ((null b) (%js-loose-eq a 0.0d0))
    ;; numeric comparison
    ((and (numberp a) (numberp b)) (= a b))
    (t nil)))

(defun %js-relational (a b num-op str-op)
  "JS Abstract Relational Comparison core, returning a JS boolean (t/nil).
When both operands are strings they compare lexicographically by code unit
(STR-OP); otherwise both coerce to number (ToNumber) and compare with NUM-OP,
except that a NaN operand makes every relational comparison false. This is why
JS relational operators must NOT lower to the VM's CL <,>,<=,>= directly: those
return 1/0 and mishandle strings/NaN/coercion."
  (if (and (stringp a) (stringp b)) (and (funcall str-op a b) t)
    (let ((na (%js-to-number a))
          (nb (%js-to-number b)))
      (unless (or (%js-nan-p na) (%js-nan-p nb))
        (and (funcall num-op na nb) t)))))

(defmacro define-js-relational-op (name num-op str-op doc)
  "Emit a JS relational comparison that delegates to %js-relational."
  `(defun ,name (a b)
    ,doc
    (%js-relational a b #',num-op #',str-op)))

(define-js-relational-op %js-lt < string< "JS a < b.")

(define-js-relational-op %js-gt > string> "JS a > b.")

(define-js-relational-op %js-le <= string<= "JS a <= b.")

(define-js-relational-op %js-ge >= string>= "JS a >= b.")

;;; Property access and string/arithmetic ops
;;; -> see runtime-property.lisp

(defun %js-instanceof (obj constructor) "JS instanceof. constructor must be a hash-table with __prototype__." (%js-object-instanceof-p obj constructor))
