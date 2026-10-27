(in-package #:cl-cc/javascript/iterators)

(defun %js-dispatch-object-generator-operation (operation &rest args)
  (ecase operation
    (:make-async (apply #'%js-make-async args))
    (:make-generator (apply #'%js-make-generator args))))

(eval-when (:load-toplevel :execute)
  (%js-register-object-generator-operation-handler
   #'%js-dispatch-object-generator-operation))
