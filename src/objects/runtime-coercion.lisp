(in-package #:cl-cc/javascript/objects)

;;; -----------------------------------------------------------------------
;;;  String / Template
;;; -----------------------------------------------------------------------
(defun %js-add (a b)
  "JS `+' operator: string concatenation when either operand is a string,
otherwise numeric addition. Models the common ECMAScript number|string cases of
ToPrimitive + — `1 + 2' => 3, `\"a\" + \"b\"' => \"ab\", `\"n=\" + 5' => \"n=5\".
JS `+' is polymorphic, so it cannot lower to the numeric-only make-vm-add; it
routes here via *js-binop-runtime-helpers*."
  (if (or (stringp a) (stringp b)) (concatenate 'string (%js-to-string a) (%js-to-string b))
    (+ (%js-to-number a) (%js-to-number b))))

(defun %js-mod (a b)
  "JS `%' remainder operator. Like CL REM, the result takes the sign of the
dividend (5 % 3 => 2, -5 % 3 => -2), matching ECMAScript; division by zero => NaN."
  (if (and (numberp b) (zerop b)) :js-nan
    (rem a b)))

(defun %js-divide (a b)
  "JS `/' operator. JS numbers are IEEE doubles, so division always yields a float
(5/2 => 2.5, 6/2 => 3.0 which prints as `3'); the CL `/' alone would return the
rational 5/2. Division by zero gives +/-Infinity (or NaN for 0/0), per ECMAScript."
  (let ((na (%js-to-number a))
        (nb (%js-to-number b)))
    (cond
      ((not (and (numberp na) (numberp nb))) *js-nan-float*)
      ((zerop nb)
        (cond
          ((zerop na) *js-nan-float*)
          ((plusp na) *js-inf-float*)
          (t *js-neg-inf-float*)))
      (t (/ (coerce na 'double-float) (coerce nb 'double-float))))))

(defun %js-pow (a b)
  "JS `**' exponentiation operator (Math.pow / a ** b)."
  (expt a b))

(defun %js-to-string (x)
  "JS ToString coercion."
  (cond
    ((stringp x)             x)
    ((eq x +js-undefined+)  "undefined")
    ((eq x +js-null+)       "null")
    ((eq x t)               "true")
    ((null x)             "false")
    ((eq x :js-nan)         "NaN")
    ((eq x :js-infinity)    "Infinity")
    ((eq x :js-neg-infinity) "-Infinity")
    ((integerp x)           (format nil "~D" x))
    ((floatp x)
     (if (%js-float-nan-p x)
         "NaN"
         (if (%js-float-infinity-p x)
             (if (plusp x) "Infinity" "-Infinity")
             (let ((s (format nil "~F" x)))
               ;; JS prints an integer-valued float without a decimal: 7.0 -> "7".
               ;; Trim trailing zeros FIRST, then a now-trailing dot. (The reverse
               ;; order left "7." because "7.0" does not end in ".".)
               (string-right-trim "." (string-right-trim "0" s))))))
    ((numberp x)            (princ-to-string x))
    ((typep x 'js-symbol)   (%js-symbol-as-key x))
    ;; The dates feature registers Date conversion through the object handler.
    ((%js-object-date-operation :date-p x) (%js-object-date-operation :to-string x))
    ((%js-ht-p x)           "[object Object]")
    ((%js-vec-p x)
     (let ((parts (loop for i below (length x)
                        collect (%js-to-string (aref x i)))))
       (format nil "~{~A~^,~}" parts)))
    ;; BigInt — defined in runtime-ops.lisp (loaded later)
    ((typep x 'js-bigint)   (format nil "~D" (js-bigint-value x)))
    (t (princ-to-string x))))

(defun %js-template-string (parts)
  "Concatenate template literal parts (already evaluated)."
  (apply #'concatenate 'string (mapcar #'%js-to-string parts)))
