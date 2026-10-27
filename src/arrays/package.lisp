(defpackage #:cl-cc/javascript/arrays
  (:use #:cl)
  (:import-from #:cl-cc/javascript/async
    #:%js-await #:%js-promise-reject #:%js-promise-resolve
    #:%js-register-promise-input-array-converter )
  (:import-from #:cl-cc/javascript/classes
    #:%js-make-error-instance #:*js-range-error-class* )
  (:import-from #:cl-cc/javascript/errors
    #:%js-throw #:js-exception #:js-exception-value )
  (:import-from #:cl-cc/javascript/iterators
    #:%js-make-cl-iterator )
  (:import-from #:cl-cc/javascript/numbers
    #:%js-f16round-number )
  (:import-from #:cl-cc/javascript/objects #:%js-array-extra-prop-set #:%js-get-prop #:%js-make-map #:%js-make-object
    #:%js-map-get #:%js-map-set #:%js-object-extensible-p #:%js-object-frozen-p
    #:%js-object-sealed-p #:%js-to-string #:js-map #:js-set #:%js-float-infinity-p
    #:%js-ht-p #:%js-make-ht #:%js-make-vec #:%js-nan-p #:%js-same-value-zero
    #:%js-strict-eq #:%js-to-number #:%js-truthy #:%js-vec-p #:+js-null+
    #:+js-undefined+ #:%js-object-for-of #:%js-object-call-with-this
    #:%js-object-funcall #:%js-object-group-into #:%js-register-object-array-factory #:js-bigint-p #:js-bigint-value)
  (:export #:%js-array-at #:%js-array-callback #:%js-array-concat #:%js-array-copy-within #:%js-array-entries #:%js-array-every #:%js-array-fill #:%js-array-filter #:%js-array-find #:%js-array-find-index #:%js-array-find-last #:%js-array-find-last-index #:%js-array-flat #:%js-array-flat-map #:%js-array-for-each #:%js-array-from #:%js-array-from-async #:%js-array-from-map-fn-p #:%js-array-from-map-value #:%js-array-group #:%js-array-group-to-map #:%js-array-includes #:%js-array-index-of #:%js-array-is-array #:%js-array-iterable-p #:%js-array-join #:%js-array-keys #:%js-array-last-index-of #:%js-array-map #:%js-array-of #:%js-array-pop #:%js-array-push #:%js-array-reduce #:%js-array-reduce-right #:%js-array-relative-end #:%js-array-relative-start #:%js-array-reverse #:%js-array-shift #:%js-array-slice #:%js-array-some #:%js-array-sort #:%js-array-splice #:%js-array-stable-sort-undefined-last #:%js-array-to-integer #:%js-array-to-length #:%js-array-to-reversed #:%js-array-to-sorted #:%js-array-to-spliced #:%js-array-unshift #:%js-array-with #:%js-base64-decode-bytes #:%js-base64-encode-bytes #:%js-do-array-elements #:%js-list-to-array #:%js-make-array #:%js-make-tagged-template-strings #:%js-make-typed-array #:%js-make-typed-array-ctor #:%js-sort-comparator #:%js-ta-at #:%js-ta-clamp #:%js-ta-clone-with-buffer #:%js-ta-coerce-element #:%js-ta-copy-within #:%js-ta-entries #:%js-ta-every #:%js-ta-fill #:%js-ta-filter #:%js-ta-find #:%js-ta-find-index #:%js-ta-find-last #:%js-ta-find-last-index #:%js-ta-for-each #:%js-ta-get #:%js-ta-includes #:%js-ta-index-of #:%js-ta-integer-number #:%js-ta-join #:%js-ta-keys #:%js-ta-last-index-of #:%js-ta-map #:%js-ta-reduce #:%js-ta-reverse #:%js-ta-set #:%js-ta-set-from #:%js-ta-slice #:%js-ta-some #:%js-ta-sort #:%js-ta-spec-by-tag #:%js-ta-subarray #:%js-ta-to-array #:%js-ta-to-reversed #:%js-ta-to-sorted #:%js-ta-type-tag #:%js-ta-values #:%js-ta-with #:%js-uint8-copy-decoded-into #:%js-uint8-from-base64 #:%js-uint8-from-hex #:%js-uint8-set-from-base64 #:%js-uint8-set-from-hex #:%js-uint8-to-base64 #:%js-uint8-to-hex #:*js-typed-array-method-table* #:define-js-array-find-index #:define-js-array-iterator #:define-js-array-predicate-test #:define-js-array-reducer #:define-js-ta-find #:define-js-ta-iterator #:define-js-ta-predicate-test #:js-typed-array #:js-typed-array-p #:js-ta-buffer #:js-ta-byte-offset #:js-ta-element-size #:js-ta-length #:js-ta-type-name))

