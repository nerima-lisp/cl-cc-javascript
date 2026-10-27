(in-package #:cl-cc/javascript/arrays/test)

(describe-concurrent "JavaScript Arrays"
  (%register-arrays-runtime-array-coverage-tests)
  (%register-arrays-runtime-array-tests)
  (%register-arrays-runtime-typed-arrays-methods-part-1-tests)
  (%register-arrays-runtime-typed-arrays-methods-part-2-tests)
  (%register-arrays-runtime-builtins-platform-typed-array-tests)
  (%register-arrays-runtime-array-object-integrity-tests))
