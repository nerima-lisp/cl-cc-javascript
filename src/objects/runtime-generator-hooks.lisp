(in-package #:cl-cc/javascript/objects)

(defvar *js-object-generator-operation-handler* nil)

(defun %js-register-object-generator-operation-handler (handler)
  (setf *js-object-generator-operation-handler* handler))

(defun %js-call-object-generator-operation (operation &rest args)
  (unless *js-object-generator-operation-handler*
    (error "The iterators feature has not registered its generator operations."))
  (apply *js-object-generator-operation-handler* operation args))

(defun %js-object-make-async (fn)
  (%js-call-object-generator-operation :make-async fn))

(defun %js-object-make-generator (body-fn)
  (%js-call-object-generator-operation :make-generator body-fn))
