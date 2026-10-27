;;;; packages/javascript/src/runtime-builtins-intl-core.lisp -- Intl shared helpers

(in-package :cl-cc/javascript)

(defun %js-intl-option (options name default)
  (if (hash-table-p options)
      (multiple-value-bind (value present-p) (gethash name options)
        (if present-p value default))
      default))

(defun %js-intl-coerced-option (options name default coerce-fn)
  "Read OPTIONS[NAME] via %JS-INTL-OPTION and, when present, pass it through
COERCE-FN — the shared shape behind every per-formatter option-string/
option-integer/... accessor (%js-date-time-format-option-string,
%js-number-format-option-integer, and friends), which otherwise each repeat
the same \"missing means DEFAULT, present means coerce\" branch."
  (let ((value (%js-intl-option options name +js-undefined+)))
    (if (eq value +js-undefined+)
        default
        (funcall coerce-fn value))))
