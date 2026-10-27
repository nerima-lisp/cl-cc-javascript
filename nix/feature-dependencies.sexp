( (:feature "syntax"
  :source-dirs ("src/syntax")
  :test-dir "t/syntax"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/syntax"
  :infra-package nil
  :depends-on ())
 (:feature "expressions"
  :source-dirs ("src/expressions")
  :test-dir "t/expressions"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/expressions"
  :infra-package nil
  :depends-on ("arrays" "async" "classes" "iterators" "numbers" "objects" "regex" "statements" "strings" "syntax"))
 (:feature "statements"
  :source-dirs ("src/statements")
  :test-dir "t/statements"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/statements"
  :infra-package nil
  :depends-on ("async" "errors" "iterators" "objects" "syntax"))
 (:feature "functions" :source-dirs ("src/functions") :test-dir "t/functions" :facade-packages ("cl-cc/javascript") :domain-package "cl-cc/javascript/functions" :infra-package nil :depends-on ("arrays" "async" "classes" "expressions" "modules" "objects" "statements" "syntax"))
 (:feature "classes" :source-dirs ("src/classes") :test-dir "t/classes" :facade-packages ("cl-cc/javascript") :domain-package "cl-cc/javascript/classes" :infra-package nil :depends-on ("objects" "syntax"))
 (:feature "objects" :source-dirs ("src/objects") :test-dir "t/objects" :facade-packages ("cl-cc/javascript") :domain-package "cl-cc/javascript/objects" :infra-package nil :depends-on ())
 (:feature "proxies"
  :source-dirs ("src/proxies")
  :test-dir "t/proxies"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/proxies"
  :infra-package nil
  :depends-on ("classes" "functions" "objects"))
 (:feature "iterators" :source-dirs ("src/iterators") :test-dir "t/iterators" :facade-packages ("cl-cc/javascript") :domain-package "cl-cc/javascript/iterators" :infra-package nil :depends-on ("async" "errors" "objects"))
 (:feature "async" :source-dirs ("src/async") :test-dir "t/async" :facade-packages ("cl-cc/javascript") :domain-package "cl-cc/javascript/async" :infra-package nil :depends-on ("classes" "errors" "objects"))
 (:feature "modules"
  :source-dirs ("src/modules")
  :test-dir "t/modules"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/modules"
  :infra-package nil
  :depends-on ("arrays" "async" "objects" "syntax"))
 (:feature "regex"
  :source-dirs ("src/regex")
  :test-dir "t/regex"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/regex"
  :infra-package nil
  :depends-on ("arrays" "objects" "strings" "syntax"))
 (:feature "strings"
  :source-dirs ("src/strings")
  :test-dir "t/strings"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/strings"
  :infra-package nil
  :depends-on ("arrays" "objects" "syntax"))
 (:feature "numbers"
  :source-dirs ("src/numbers")
  :test-dir "t/numbers"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/numbers"
  :infra-package nil
  :depends-on ("objects" "syntax"))
 (:feature "arrays"
  :source-dirs ("src/arrays")
  :test-dir "t/arrays"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/arrays"
  :infra-package nil
  :depends-on ("async" "classes" "errors" "iterators" "numbers" "objects"))
 (:feature "json"
  :source-dirs ("src/json")
  :test-dir "t/json"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/json"
  :infra-package nil
  :depends-on ("arrays" "classes" "errors" "expressions" "objects" "proxies" "strings"))
 (:feature "dates"
  :source-dirs ("src/dates")
  :test-dir "t/dates"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/dates"
  :infra-package nil
  :depends-on ("objects"))
 (:feature "intl"
  :source-dirs ("src/intl")
  :test-dir "t/intl"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/intl"
  :infra-package nil
  :depends-on ("arrays" "dates" "objects"))
 (:feature "errors"
  :source-dirs ("src/errors")
  :test-dir "t/errors"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/errors"
  :infra-package nil
  :depends-on ("classes" "objects"))
 (:feature "disposables"
  :source-dirs ("src/disposables")
  :test-dir "t/disposables"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/disposables"
  :infra-package nil
  :depends-on ("classes" "errors" "expressions" "statements" "syntax"))

 (:feature "v8-objects"
  :source-dirs ("src/v8-objects")
  :test-dir "t/v8-objects"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/v8-objects"
  :infra-package nil
  :depends-on ())

 (:feature "backend"
  :source-dirs ("src/backend")
  :test-dir "t/backend"
  :facade-packages ("cl-cc/javascript")
  :domain-package "cl-cc/javascript/backend"
  :infra-package nil
  :depends-on ("arrays" "async" "classes" "dates" "errors" "expressions" "functions" "intl" "iterators" "json" "numbers" "objects" "proxies" "regex" "strings" "syntax")))
