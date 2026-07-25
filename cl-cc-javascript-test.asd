;;;; cl-cc-javascript-test.asd — test suite for the JavaScript frontend

(asdf:defsystem :cl-cc-javascript-test
  :description "Tests for the CL-CC JavaScript frontend"
  :author "takeokunn"
  :license "MIT"
  :homepage "https://github.com/nerima-lisp/cl-cc-javascript"
  :version "0.2.0"
  :depends-on (:cl-cc :cl-weave :cl-cc-javascript)
  :pathname "tests"
  :serial t
  :components
  ((:file "package")
   (:file "js-lexer-tests")
   (:file "js-parser-decl-tests")
   (:file "js-parser-stmt-tests")
   (:file "js-e2e-core-tests")
   (:file "js-e2e-ast-tests")
   (:file "js-e2e-advanced-tests")
    (:file "js-e2e-modern-tests")
    (:file "js-runtime-core-tests")
    (:file "js-runtime-array-tests")
    (:file "js-runtime-string-number-tests")
    (:file "js-runtime-collections-tests")
    (:file "js-runtime-resolver-tests")
    (:file "js-runtime-date-json-tests")
    (:file "js-runtime-object-ops-tests")
    (:file "js-runtime-symbol-tests")
    (:file "js-runtime-typed-array-methods-tests")
    (:file "js-runtime-misc-tests")
    (:file "js-runtime-misc-platform-tests"))
  :perform (asdf:test-op (op system)
             (declare (ignore op system))
             (unless (uiop:symbol-call :cl-weave
                                       :run-all
                                       :reporter :spec
                                       :pass-with-no-tests nil)
               (error "cl-cc-javascript tests failed"))))
