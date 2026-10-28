(in-package #:cl-cc/javascript/proxies/test)

(describe-concurrent "JavaScript Proxies"
  (%register-proxies-runtime-builtins-iterator-proxy-tests)
  (%register-proxies-runtime-object-property-tests)
  (%register-proxies-runtime-object-closure-integrity-tests)
  (%register-proxies-runtime-object-closure-empty-integrity-test))
