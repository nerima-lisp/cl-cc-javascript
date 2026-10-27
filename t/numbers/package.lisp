(defpackage #:cl-cc/javascript/numbers/test
  (:use #:cl)
  (:import-from #:cl-cc/javascript/objects #:%js-float-infinity-p #:%js-float-nan-p #:%js-nan-p #:*js-inf-float* #:*js-nan-float*)
  (:import-from #:cl-weave #:describe-concurrent #:describe-sequential #:expect #:it #:it-sequential #:it-sequential-each)
  (:import-from #:cl-cc-javascript/test #:%jr-arr))
