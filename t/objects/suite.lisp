(in-package #:cl-cc/javascript/objects/test)

(describe-concurrent "JavaScript Objects"
  ()
  (%register-objects-runtime-collections-set-tests)
  (%register-objects-runtime-collections-values-tests)
  (%register-objects-runtime-collections-weak-tests)
  (%register-objects-runtime-console-tests)
  (%register-objects-runtime-object-ops-tests)
  (%register-objects-runtime-symbol-tests)
  (%register-objects-runtime-structured-clone-tests))
