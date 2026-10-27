(in-package #:cl-cc/javascript/v8-objects/test)

(describe-concurrent "JavaScript V8 objects"
  ()
  (%register-v8-objects-runtime-tests))
