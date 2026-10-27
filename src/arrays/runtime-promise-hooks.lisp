(in-package #:cl-cc/javascript/arrays)

(eval-when (:load-toplevel :execute)
  (%js-register-promise-input-array-converter #'%js-array-from))
