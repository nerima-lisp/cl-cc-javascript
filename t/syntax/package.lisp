(defpackage #:cl-cc/javascript/syntax/test
  (:use #:cl)
  (:import-from #:cl-cc/javascript/syntax #:js-lexer-extension-handler #:lex-js-string #:register-js-lexer-extension #:tokenize-js-source)
  (:import-from #:cl-weave #:describe-concurrent #:describe-sequential #:expect #:it #:it-sequential #:it-sequential-each))
