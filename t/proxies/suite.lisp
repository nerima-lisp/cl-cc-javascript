(in-package #:cl-cc/javascript/proxies/test)

(describe-concurrent "JavaScript Proxies"
  (%register-proxies-runtime-builtins-iterator-proxy-tests)
  (%register-proxies-runtime-object-property-tests)
)
