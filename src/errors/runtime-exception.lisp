(in-package #:cl-cc/javascript/errors)

(defun %js-throw (value)
  (error 'js-exception :value value))

;;; -----------------------------------------------------------------------
;;;  Control flow / exceptions
;;; -----------------------------------------------------------------------

(define-condition js-exception ()
  ((value :initarg :value :reader js-exception-value)))
