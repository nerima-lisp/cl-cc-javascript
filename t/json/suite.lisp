(in-package #:cl-cc/javascript/json/test)

(describe-concurrent "JavaScript Json"
  (%register-json-runtime-json-part-1-tests)
  (%register-json-runtime-json-part-2-tests)
)
