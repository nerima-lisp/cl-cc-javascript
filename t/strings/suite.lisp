(in-package #:cl-cc/javascript/strings/test)

(describe-concurrent "JavaScript Strings"
  (%register-strings-runtime-string-number-tests)
  (%register-strings-runtime-builtins-platform-url-tests))
