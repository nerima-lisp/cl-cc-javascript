(defpackage #:cl-cc/javascript/modules/test
  (:use #:cl)
  (:import-from #:cl-cc/javascript/syntax #:parse-js-module)
  (:import-from #:cl-weave #:describe-concurrent #:describe-sequential #:expect #:it #:it-sequential #:it-sequential-each #:signals)
  (:import-from #:cl-cc-javascript/test #:%js-first #:%js-call-name))
