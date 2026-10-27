(defpackage #:cl-cc/javascript/regex
  (:use #:cl)
  (:import-from #:cl-cc/javascript/arrays
    #:%js-make-array )
  (:import-from #:cl-cc/javascript/objects
    #:%js-make-object #:%js-object-create #:%js-to-string #:%js-ht-p #:+js-null+
    #:+js-undefined+ #:%js-register-object-regex-clone-handler #:%js-object-funcall )
  (:import-from #:cl-cc/javascript/strings
    #:%js-string-match #:%js-string-match-all #:%js-string-replace
    #:%js-string-replace-all #:%js-string-search #:%js-string-split )
  (:import-from #:cl-cc/javascript/syntax
    #:register-js-lexer-extension )
  (:export #:%js-char-class-match-p #:%js-collect-regex-matches #:%js-compile-char-class #:%js-compile-pattern #:%js-make-regex #:%js-regex-bounded-repeat-matcher #:%js-regex-build-match-groups-object #:%js-regex-build-match-object #:%js-regex-capture-substring #:%js-regex-capturing-group-matcher #:%js-regex-char-at #:%js-regex-dollar-escape-text #:%js-regex-escape-literal #:%js-regex-escape-predicate #:%js-regex-exec #:%js-regex-greedy-match #:%js-regex-hex-escape-char #:%js-regex-named-escape-text #:%js-regex-numbered-escape-text #:%js-regex-numbered-group-value #:%js-regex-parse-brace-quantifier #:%js-regex-test #:%js-regex-word-boundary-p #:%js-regex-word-char-p #:%js-regexp-escape #:%js-string-match-all-regex #:%js-string-match-regex #:%js-string-replace-all-regex #:%js-string-replace-regex #:%js-string-search-regex #:%js-string-split-regex #:js-lex-regex #:js-regexp #:js-regexp-p #:js-valid-regex-flag-p #:js-validate-regex-flags #:regex-replace-placeholders #:js-regexp-flags #:js-regexp-global-p #:js-regexp-ignore-case-p #:js-regexp-last-index #:js-regexp-multiline-p #:js-regexp-source))

