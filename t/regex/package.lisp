(defpackage #:cl-cc/javascript/regex/test
  (:use #:cl)
  (:import-from #:cl-cc/javascript/objects #:+js-null+)
  (:import-from #:cl-cc/javascript/regex #:%js-make-regex #:%js-regex-exec #:%js-regex-test #:%js-regexp-escape #:%js-string-match-regex #:%js-string-replace-all-regex #:%js-string-replace-regex #:%js-string-search-regex #:%js-string-split-regex)
  (:import-from #:cl-weave #:describe-concurrent #:describe-sequential #:expect #:gen-string #:it #:it-fuzz #:it-property #:it-sequential #:it-sequential-each)
  (:import-from #:cl-cc-javascript/test #:%jr-list))
