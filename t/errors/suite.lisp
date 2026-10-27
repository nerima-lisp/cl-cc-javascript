(in-package #:cl-cc/javascript/errors/test)
(defun %register-errors-runtime-builtins-tests ()
  (it-sequential "js-rt-error-is-error"
    (let ((with-message (cl-cc/javascript/classes:%js-make-error-instance
                         cl-cc/javascript/classes:*js-error-class* "oops"))
          (plain-obj    (cl-cc/javascript/objects:%js-make-object "x" 1)))
      (expect (cl-cc/javascript/errors:%js-error-is-error with-message) :to-be-truthy)
      (expect (cl-cc/javascript/errors:%js-error-is-error plain-obj) :to-be-falsy)
      (expect (cl-cc/javascript/errors:%js-error-is-error "error") :to-be-falsy))))

(describe-concurrent "JavaScript Errors" (%register-errors-runtime-builtins-tests))
