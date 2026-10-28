(defpackage #:cl-cc/javascript/proxies/test
  (:use #:cl)
  (:import-from #:cl-weave #:describe-concurrent #:describe-sequential #:expect #:it #:it-sequential #:it-sequential-each #:signals)
  (:import-from #:cl-cc/javascript/objects
                #:%js-get-prop #:%js-make-object #:%js-object-extensible-p
                #:%js-object-freeze #:%js-object-frozen-p #:%js-object-prevent-extensions
                #:%js-object-seal #:%js-object-sealed-p)
  (:import-from #:cl-cc-javascript/test #:%jr-arr))
