(in-package #:cl-cc/javascript/iterators)

(eval-when (:load-toplevel :execute)
  (%js-register-object-iterator-factory #'%js-make-cl-iterator)
  (%js-register-object-for-of-handler #'%js-for-of))
