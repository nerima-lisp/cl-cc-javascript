;;;; cl-cc-javascript.asd — JavaScript frontend: lexer, parser, runtime helpers
;;;;
;;;; Both the production system and its test system live in this one file:
;;;; the org does not use a separate cl-cc-javascript-test.asd.

(in-package #:asdf-user)

;;; System names are written as STRINGS, not #:symbols or :keywords. A string
;;; does not depend on the reader's current package state.
;;;
;;; The :depends-on designators below are deliberately left as keywords. They
;;; name systems owned by other repositories (cl-cc's packages/ tree), and
;;; rewriting them is out of scope for this migration.
(defsystem "cl-cc-javascript"
  :description "CL-CC JavaScript frontend: lexer, parser, and runtime helpers"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  ;; Single source of truth for the version: flake.nix reads this form, and
  ;; release.yml refuses to publish a tag that disagrees with it.
  :version "0.2.0"
  :homepage "https://github.com/nerima-lisp/cl-cc-javascript"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-javascript/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-javascript.git")
  ;; cl-date-kit/cl-json-kit/cl-concurrent-kit are strings, not keywords: they
  ;; are plain nerima-lisp sibling systems consumed directly (no adapter), not
  ;; one of cl-cc's own packages/*/ components, so they do not need the
  ;; eval-when trick that :cl-cc-ast and friends rely on -- ASDF finds them on
  ;; the source registry like any other dependency.
  :depends-on
  (:cl-cc-ast
   :cl-cc-bootstrap
   :cl-cc-parse
   :cl-cc-vm
   "cl-date-kit"
   "cl-json-kit"
   "cl-concurrent-kit")
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "macros")
   (:file "lexer")
   (:file "lexer-operator")
   (:file "lexer-number")
   (:file "lexer-template")
   (:file "lexer-regex")
   (:file "parser")
   (:file "parser-stmt-binding")
   (:file "parser-expr")
   (:file "parser-expr-args")
   (:file "parser-expr-literal")
   (:file "parser-expr-postfix")
   (:file "parser-expr-unary")
   (:file "parser-expr-primary")
   (:file "parser-arrow")
   (:file "parser-stmt")
   (:file "parser-stmt-fn")
   (:file "parser-stmt-control")
   (:file "parser-class-helpers")
   (:file "parser-stmt-flow")
   (:file "parser-stmt-dispatch")
   (:file "parser-class")
   (:file "parser-class-lower-classify")
   (:file "parser-class-lower")
   (:file "parser-module")
   (:file "parser-module-export")
   ;; NOTE: there is intentionally no separate ast-lower pass. The parser lowers
   ;; JS-specific forms inline (e.g. %js-lower-assignment for &&=/||=/??=, %js-this
   ;; emitted directly), matching the PHP frontend's inline-lowering model. The
   ;; former ast-lower.lisp was dead, uncalled, and inconsistent — removed.
   (:file "runtime")
   (:file "runtime-call")
   (:file "runtime-property")
   (:file "runtime-symbol")
   (:file "runtime-control")
   (:file "runtime-array")
   (:file "runtime-array-core")
   (:file "runtime-array-transforms")
   (:file "runtime-array-es2023")
   (:file "runtime-array-iterators")
   (:file "runtime-array-from")
   (:file "runtime-object")
   (:file "runtime-object-ops")
   (:file "runtime-json")
   (:file "runtime-string")
   (:file "runtime-math")
   (:file "runtime-collections")
   (:file "runtime-collections-set")
   (:file "runtime-collections-zip")
   (:file "runtime-collections-iterators")
   (:file "runtime-console")
   (:file "runtime-promise")
   (:file "runtime-generator")
   (:file "runtime-map")
   (:file "runtime-weak-collections")
   (:file "runtime-date")
   (:file "runtime-date-methods")
   (:file "runtime-regex-combinators")
   (:file "runtime-regex")
   (:file "runtime-regex-api")
   (:file "runtime-typed-arrays")
   (:file "runtime-typed-arrays-encoding")
   (:file "runtime-typed-arrays-methods")
   (:file "runtime-typed-arrays-methods-es2023")
   (:file "runtime-class")
   (:file "runtime-module")
   (:file "runtime-ops")
   (:file "runtime-ops-encoding")
   (:file "runtime-temporal")
   (:file "runtime-temporal-datetime")
   (:file "runtime-temporal-duration")
   (:file "runtime-temporal-parse")
   (:file "runtime-temporal-global")
   (:file "runtime-builtins")
   (:file "runtime-builtins-globals")
   (:file "runtime-builtins-intl")
   (:file "runtime-builtins-intl-core")
   (:file "runtime-builtins-intl-number-format")
   (:file "runtime-builtins-intl-date-time-format")
   (:file "runtime-builtins-intl-collator")
   (:file "runtime-builtins-intl-list-format")
   (:file "runtime-builtins-intl-plural-rules")
   (:file "runtime-builtins-platform")
   (:file "runtime-builtins-platform-abort")
   (:file "runtime-builtins-platform-url")
   (:file "runtime-builtins-platform-crypto")
   (:file "runtime-builtins-platform-atomics")
   (:file "runtime-builtins-object")
   (:file "runtime-builtins-table-specs")
   (:file "runtime-builtins-table")
   (:file "runtime-builtins-table-globals")
   (:file "runtime-builtins-prelude")
   (:file "runtime-method-resolver")
   (:file "runtime-method-resolver-core")
   (:file "runtime-method-resolver-tables")
   (:file "runtime-method-resolver-dispatch")
   ;; Registers JS's %JS-* helpers as a backend bridge provider. Must load
   ;; last, after every %JS-* function is defined.
   (:file "runtime-bridge-provider")
   ;; Installs the JS↔VM closure integration + prelude-global seeder, and
   ;; self-registers with cl-cc/bootstrap. Depends on the runtime specials
   ;; (*js-apply-fn* etc.) so it loads after runtime-call.
   (:file "vm-integration"))
  :in-order-to ((test-op (test-op "cl-cc-javascript/test"))))

;;; The test system is `cl-cc-javascript/test` (singular, slash-separated) with
;;; :pathname "t". It is NOT `cl-cc-javascript-test` and NOT
;;; `cl-cc-javascript/tests`.
(defsystem "cl-cc-javascript/test"
  :description "Test system for cl-cc-javascript."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.2.0"
  :homepage "https://github.com/nerima-lisp/cl-cc-javascript"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-javascript/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-javascript.git")
  ;; cl-weave is the org's test framework everywhere.
  :depends-on (:cl-cc :cl-weave :cl-cc-javascript)
  :pathname "t"
  :serial t
  :components
  ((:file "package")
   (:file "lexer-test")
   (:file "parser-decl-test")
   (:file "parser-stmt-control-flow-test")
   (:file "parser-stmt-module-test")
   (:file "parser-stmt-misc-test")
   (:file "e2e-core-test")
   (:file "e2e-ast-test")
   (:file "e2e-advanced-test")
   (:file "e2e-advanced-builtins-test")
   (:file "e2e-modern-test")
   (:file "runtime-core-test")
   (:file "runtime-array-test")
   (:file "runtime-array-coverage-test")
   (:file "runtime-string-number-test")
   (:file "runtime-collections-set-test")
   (:file "runtime-collections-iterators-test")
   (:file "runtime-collections-values-test")
   (:file "runtime-collections-weak-test")
   (:file "runtime-regex-test")
   (:file "runtime-method-resolver-dispatch-test")
   (:file "runtime-misc-test")
   (:file "runtime-temporal-test")
   (:file "runtime-date-test")
   (:file "runtime-json-test")
   (:file "runtime-object-ops-test")
   (:file "runtime-ops-test")
   (:file "runtime-symbol-test")
   (:file "runtime-typed-arrays-methods-test")
   (:file "runtime-builtins-promises-test")
   (:file "runtime-builtins-iterator-proxy-test")
   (:file "runtime-builtins-platform-object-test")
   (:file "runtime-console-test")
   (:file "runtime-builtins-platform-test"))
  :perform (asdf:test-op (op system)
             (declare (ignore op system))
             (unless (uiop:symbol-call :cl-weave
                                       :run-all
                                       :reporter :spec
                                       :pass-with-no-tests nil)
               (error "cl-cc-javascript tests failed"))))
