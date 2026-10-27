(in-package #:cl-cc/javascript/proxies)

(defun %js-dispatch-object-proxy-operation (operation &rest args)
  (ecase operation
    (:proxy-p (apply #'%js-proxy-object-p args))
    (:key-list (apply #'%js-proxy-key-list args))
    (:own-keys (apply #'%js-proxy-own-keys args))
    (:get (apply #'%js-proxy-get args))
    (:set (apply #'%js-proxy-set args))
    (:delete-property (apply #'%js-proxy-delete-property args))
    (:has (apply #'%js-proxy-has args))
    (:get-own-property-descriptor
     (apply #'%js-proxy-get-own-property-descriptor args))
    (:own-property-or-accessor-present-p
     (apply #'%js-object-own-property-or-accessor-present-p args))))

(eval-when (:load-toplevel :execute)
  (%js-register-object-proxy-operation-handler
   #'%js-dispatch-object-proxy-operation))
