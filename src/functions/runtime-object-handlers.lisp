(in-package #:cl-cc/javascript/functions)

(defun %js-dispatch-object-function-operation (operation &rest args)
  (ecase operation
    (:funcall (apply #'%js-funcall args))
    (:apply (funcall *js-apply-fn* (first args) (second args)))
    (:call-with-this (apply #'%js-call-with-this args))
    (:callable-p (funcall *js-callable-p* (first args)))
    (:method-ref (apply #'%js-method-ref args))
    (:proto-accessor-lookup (apply #'%js-proto-accessor-lookup args))
    (:proto-method-lookup (apply #'%js-proto-method-lookup args))))
