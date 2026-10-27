(in-package #:cl-cc/javascript/objects)

(defvar *js-object-function-operation-handler* nil)

(defun %js-register-object-function-operation-handler (handler)
  (setf *js-object-function-operation-handler* handler))

(defun %js-call-object-function-operation (operation &rest args)
  (unless *js-object-function-operation-handler*
    (error "The functions feature has not registered its object operations."))
  (apply *js-object-function-operation-handler* operation args))

(defun %js-object-funcall (fn &rest args)
  (apply #'%js-call-object-function-operation :funcall fn args))

(defun %js-object-apply-fn (fn args)
  (%js-call-object-function-operation :apply fn args))

(defun %js-object-call-with-this (this fn args)
  (%js-call-object-function-operation :call-with-this this fn args))

(defun %js-object-callable-p (value)
  (%js-call-object-function-operation :callable-p value))

(defun %js-object-method-ref (object key)
  (%js-call-object-function-operation :method-ref object key))

(defun %js-object-proto-accessor-lookup (object key)
  (%js-call-object-function-operation :proto-accessor-lookup object key))

(defun %js-object-proto-method-lookup (object key)
  (%js-call-object-function-operation :proto-method-lookup object key))
