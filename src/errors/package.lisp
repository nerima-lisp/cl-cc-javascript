(defpackage #:cl-cc/javascript/errors
  (:use #:cl)
  (:import-from #:cl-cc/javascript/objects
    #:%js-ht-p #:%js-object-error-class #:%js-object-instanceof-p )
  (:export #:%js-error-is-error #:js-exception-value #:%js-throw #:js-exception))

