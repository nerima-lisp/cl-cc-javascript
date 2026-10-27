(in-package #:cl-cc/javascript/expressions/test)

(describe-concurrent "JavaScript Expressions"
  (%register-expressions-e2e-ast-tests)
  (%register-expressions-runtime-core-tests)
  (%register-expressions-runtime-ops-tests)
)
