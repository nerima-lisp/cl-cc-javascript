(in-package #:cl-cc/javascript/async)

(defvar *js-promise-input-array-converter* nil)

(defun %js-register-promise-input-array-converter (converter)
  (setf *js-promise-input-array-converter* converter))

(defun %js-promise-input-as-array (value)
  (unless *js-promise-input-array-converter*
    (error "The arrays feature has not registered its promise input converter."))
  (funcall *js-promise-input-array-converter* value))
