(in-package #:cl-cc/javascript/backend)

(eval-when (:load-toplevel :execute)
  (%js-register-object-function-operation-handler
   #'%js-dispatch-object-function-operation))
