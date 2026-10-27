(in-package #:cl-cc/javascript/statements/test)

(describe-concurrent "JavaScript Statements"
  (%register-statements-parser-decl-tests)
  (%register-statements-parser-stmt-control-flow-tests)
  (%register-statements-parser-stmt-misc-part-1-tests)
  (it-sequential "js-rt-try-catch"
    (let ((caught nil))
      (%js-try-catch-finally
       (lambda () (%js-throw "err"))
       (lambda (v) (setf caught v))
       nil)
      (expect caught :to-equal "err")))
  (it-sequential "js-rt-try-finally-runs"
    (let ((ran nil))
      (%js-try-catch-finally
       (lambda () 42)
       nil
       (lambda () (setf ran t)))
      (expect ran :to-be-truthy)))
)
