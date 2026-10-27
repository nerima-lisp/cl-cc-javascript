(in-package #:cl-cc/javascript/async/test)

(describe-concurrent "JavaScript Async" (%register-async-runtime-builtins-promises-tests) (%register-async-runtime-collections-values-tests) (%register-async-runtime-builtins-platform-object-tests))
