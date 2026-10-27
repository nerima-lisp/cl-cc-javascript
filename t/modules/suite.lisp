(in-package #:cl-cc/javascript/modules/test)

(describe-concurrent "JavaScript Modules"
  (progn (%register-modules-parser-stmt-module-tests) (%register-modules-module-registration-tests))
)
