(defpackage #:cl-cc/javascript/proxies
  (:use #:cl)
  (:import-from #:cl-cc/javascript/classes
    #:%js-new )
  (:import-from #:cl-cc/javascript/functions
    #:%js-call-with-this #:%js-funcall #:*js-callable-p* )
  (:import-from #:cl-cc/javascript/objects
    #:%js-delete #:%js-get-prop #:%js-in #:%js-internal-key-p #:%js-make-object
    #:%js-object-accessor-property-name #:%js-object-extensible-p #:%js-object-frozen-p
    #:%js-object-get-prototype-of #:%js-object-own-keys #:%js-object-prevent-extensions
    #:%js-object-sealed-p #:%js-object-set-prototype-of #:%js-set-prop
    #:%js-to-property-key #:%js-to-string #:%js-ht-p #:%js-make-ht #:%js-truthy
    #:%js-vec-p
    #:%js-vm-closure-p #:+js-undefined+ #:%js-register-object-proxy-operation-handler )
  (:export #:%js-make-proxy-object #:%js-object-accessor-property-descriptor #:%js-object-apply-property-descriptor #:%js-object-data-property-descriptor #:%js-object-define-properties #:%js-object-define-property #:%js-object-define-property-allowed-p #:%js-object-descriptor-slot-key #:%js-object-get-own-property-descriptor #:%js-object-get-own-property-descriptors #:%js-object-own-property-or-accessor-present-p #:%js-proxy-call-trap #:%js-proxy-define-property #:%js-proxy-delete-property #:%js-proxy-get #:%js-proxy-get-own-property-descriptor #:%js-proxy-handler #:%js-proxy-has #:%js-proxy-key-list #:%js-proxy-object-p #:%js-proxy-own-keys #:%js-proxy-set #:%js-proxy-target #:%js-proxy-trap #:%js-reflect-apply #:%js-reflect-construct #:%js-reflect-define-property #:%js-reflect-delete-property #:%js-reflect-get #:%js-reflect-get-own-property-descriptor #:%js-reflect-has #:%js-reflect-prevent-extensions #:%js-reflect-set #:%js-reflect-set-prototype-of))

