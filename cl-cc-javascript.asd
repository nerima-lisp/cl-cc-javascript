;;;; cl-cc-javascript.asd — JavaScript frontend: lexer, parser, runtime helpers
;;;;
;;;; Both the production system and its test system live in this one file:
;;;; the org does not use a separate cl-cc-javascript-test.asd.

(in-package #:asdf-user)

;;; System names use strings so loading this file does not depend on the
;;; current package. The source registry resolves component dependencies from
;;; their sibling repositories.
(defsystem "cl-cc-javascript"
  :description "CL-CC JavaScript frontend: lexer, parser, and runtime helpers"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.2.1"
  :homepage "https://github.com/nerima-lisp/cl-cc-javascript"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-javascript/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-javascript.git")
  :depends-on (:cl-cc-ast :cl-cc-bootstrap :cl-cc-parse :cl-cc-vm
               "cl-date-kit" "cl-json-kit" "cl-concurrent-kit" "cl-host-kit")
  :pathname "src"
  :serial t
  :components
  ((:file "syntax/package")
   (:file "objects/package")
   (:file "classes/package")
   (:file "numbers/package")
   (:file "dates/package")
   (:file "errors/package")
   (:file "async/package")
   (:file "iterators/package")
   (:file "statements/package")
   (:file "arrays/package")
   (:file "modules/package")
   (:file "strings/package")
   (:file "regex/package")
   (:file "expressions/package")
   (:file "functions/package")
   (:file "proxies/package")
   (:file "json/package")
   (:file "intl/package")
   (:file "disposables/package")

   (:file "backend/package")
   (:file "v8-objects/package")
   (:file "package")
   (:module "syntax" :serial t :components ((:file "macros") (:file "registry") (:file "lexer") (:file "lexer-string") (:file "lexer-operator") (:file "parser")))
   (:module "objects" :serial t :components ((:file "runtime-values") (:file "runtime-hooks") (:file "runtime-function-hooks") (:file "runtime-generator-hooks") (:file "runtime-collections") (:file "runtime-collections-set") (:file "runtime-map") (:file "runtime-object") (:file "runtime-object-vm") (:file "runtime-object-ops") (:file "runtime-property") (:file "runtime-coercion") (:file "runtime-symbol") (:file "runtime-weak-collections") (:file "runtime-console")))
   (:module "expressions" :serial t :components ((:file "parser-expr") (:file "parser-expr-literal") (:file "parser-expr-incdec") (:file "parser-expr-postfix") (:file "parser-expr-primary") (:file "parser-expr-unary") (:file "runtime-ops") (:file "runtime")))
   (:module "statements" :serial t :components ((:file "parser-stmt") (:file "parser-stmt-binding") (:file "parser-stmt-control") (:file "parser-stmt-switch") (:file "parser-stmt-dispatch") (:file "runtime-control")))
   (:module "functions" :serial t :components ((:file "parser-arrow-params") (:file "parser-arrow") (:file "parser-expr-args") (:file "parser-stmt-fn") (:file "runtime-call") (:file "runtime-object-handlers")))
   (:module "classes" :serial t :components ((:file "parser-class-member-syntax") (:file "parser-class-lower-classify") (:file "parser-class-lower") (:file "parser-class") (:file "runtime-class")))
   (:module "v8-objects" :serial t :components ((:file "runtime-vm-objects")))
   (:module "proxies" :serial t :components ((:file "runtime-builtins-object") (:file "runtime-object-hooks")))
   (:module "iterators" :serial t :components ((:file "runtime-collections-iterators") (:file "runtime-collections-zip") (:file "runtime-for-of") (:file "runtime-generator") (:file "runtime-builtins-platform-atomics") (:file "runtime-object-hooks") (:file "runtime-object-generator-hooks")))
   (:module "async" :serial t :components ((:file "runtime-hooks") (:file "runtime-promise") (:file "runtime-builtins-platform-abort")))
   (:module "modules" :serial t :components ((:file "parser-module") (:file "parser-module-export") (:file "runtime-module")))
   (:module "regex" :serial t :components ((:file "lexer-regex") (:file "runtime-regex-combinators") (:file "runtime-regex-api") (:file "runtime-regex-escape") (:file "runtime-regex") (:file "runtime-object-hooks")))
   (:module "numbers" :serial t :components ((:file "lexer-number") (:file "runtime-math")))
   (:module "arrays" :serial t :components ((:file "runtime-array") (:file "runtime-array-core") (:file "runtime-array-transforms") (:file "runtime-array-es2023") (:file "runtime-array-iterators") (:file "runtime-array-from") (:file "runtime-typed-arrays") (:file "runtime-typed-arrays-encoding") (:file "runtime-typed-arrays-methods") (:file "runtime-typed-arrays-methods-es2023") (:file "runtime-promise-hooks")))
   (:module "strings" :serial t :components ((:file "lexer-template") (:file "runtime-ops-encoding") (:file "runtime-string") (:file "runtime-builtins-platform-url")))
   (:module "json" :serial t :components ((:file "runtime-json")))
   (:module "dates" :serial t :components ((:file "runtime-date") (:file "runtime-date-setters") (:file "runtime-date-methods") (:file "runtime-temporal") (:file "runtime-temporal-datetime") (:file "runtime-temporal-duration") (:file "runtime-temporal-parse") (:file "runtime-temporal-global")))
   (:module "intl" :serial t :components ((:file "runtime-builtins-intl") (:file "runtime-builtins-intl-core") (:file "runtime-builtins-intl-number-format") (:file "runtime-builtins-intl-date-time-format") (:file "runtime-builtins-intl-collator") (:file "runtime-builtins-intl-list-format") (:file "runtime-builtins-intl-plural-rules")))
   (:module "errors" :serial t :components ((:file "runtime-exception") (:file "runtime-builtins")))
   (:module "disposables" :serial t :components ((:file "parser-stmt-flow")))

   (:module "backend" :serial t :components ((:file "runtime-function-hooks") (:file "runtime-builtins-globals") (:file "runtime-builtins-platform") (:file "runtime-builtins-platform-crypto") (:file "runtime-builtins-prelude") (:file "runtime-builtins-table-specs") (:file "runtime-builtins-table") (:file "runtime-builtins-table-globals") (:file "runtime-method-resolver") (:file "runtime-method-resolver-core") (:file "runtime-method-resolver-tables") (:file "runtime-method-resolver-dispatch") (:file "runtime-bridge-provider") (:file "vm-integration")))
   )
  :in-order-to ((test-op (test-op "cl-cc-javascript/test"))))

;;; The test system is `cl-cc-javascript/test` and uses the `t/` directory.
(defsystem "cl-cc-javascript/test"
  :description "Test system for cl-cc-javascript."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.2.1"
  :homepage "https://github.com/nerima-lisp/cl-cc-javascript"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-javascript/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-javascript.git")
  :depends-on (:cl-weave :cl-cc-javascript)
  :pathname "t"
  :serial t
  :components
  ((:file "package") (:file "test-support")
   (:file "syntax/package")
   (:file "expressions/package")
   (:file "statements/package")
   (:file "functions/package")
   (:file "classes/package")
   (:file "objects/package")
   (:file "proxies/package")
   (:file "iterators/package")
   (:file "async/package")
   (:file "modules/package")
   (:file "regex/package")
   (:file "strings/package")
   (:file "numbers/package")
   (:file "arrays/package")
   (:file "json/package")
   (:file "dates/package")
   (:file "intl/package")
   (:file "errors/package")
   (:file "disposables/package")

   (:file "backend/package")
   (:file "v8-objects/package")
   (:module "syntax" :serial t :components ( (:file "lexer-test") (:file "suite")))
   (:module "expressions" :serial t :components ((:file "e2e-ast-test") (:file "runtime-core-test") (:file "runtime-ops-test") (:file "suite")))
   (:module "statements" :serial t :components ((:file "parser-decl-test") (:file "parser-stmt-control-flow-test") (:file "parser-stmt-extended-forms-test") (:file "suite")))
   (:module "objects" :serial t :components ((:file "runtime-collections-set-test") (:file "runtime-collections-values-test") (:file "runtime-collections-weak-test") (:file "runtime-object-ops-test") (:file "runtime-symbol-test") (:file "runtime-console-test") (:file "runtime-builtins-platform-object-test") (:file "suite")))
   (:module "proxies" :serial t :components ( (:file "runtime-builtins-iterator-proxy-test") (:file "suite")))
   (:module "iterators" :serial t :components ( (:file "runtime-collections-iterators-test") (:file "suite")))
   (:module "async" :serial t :components ( (:file "runtime-builtins-promises-test") (:file "suite")))
   (:module "modules" :serial t :components ( (:file "parser-stmt-module-test") (:file "suite")))
   (:module "regex" :serial t :components ( (:file "runtime-regex-test") (:file "suite")))
   (:module "strings" :serial t :components ( (:file "runtime-string-number-test") (:file "suite")))
   (:module "arrays" :serial t :components ((:file "runtime-array-test") (:file "runtime-array-coverage-test") (:file "runtime-typed-arrays-methods-test") (:file "suite")))
   (:module "json" :serial t :components ( (:file "runtime-json-test") (:file "suite")))
   (:module "dates" :serial t :components ((:file "runtime-date-test") (:file "runtime-temporal-test") (:file "suite")))

   (:module "backend" :serial t :components ((:file "runtime-method-resolver-dispatch-test") (:file "runtime-builtins-platform-test") (:file "runtime-object-coercion-clone-test") (:file "suite")))
   (:module "v8-objects" :serial t :components ((:file "runtime-vm-objects-test") (:file "suite")))
   (:module "functions" :serial t :components ((:file "suite")))
   (:module "classes" :serial t :components ((:file "suite")))
   (:module "numbers" :serial t :components ((:file "suite")))
   (:module "intl" :serial t :components ((:file "suite")))
   (:module "errors" :serial t :components ((:file "suite")))
   (:module "disposables" :serial t :components ((:file "suite")))
   (:file "facade-exports-test")
   )
  :perform (asdf:test-op (op system)
             (declare (ignore op system))
             (unless (funcall (find-symbol "RUN-ALL" (find-package "CL-WEAVE"))
                              :reporter :spec
                              :pass-with-no-tests nil)
               (error "cl-cc-javascript tests failed"))))
