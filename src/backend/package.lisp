(defpackage #:cl-cc/javascript/backend
  (:use #:cl)
  (:import-from #:cl-cc/ast
    #:make-ast-defvar #:make-ast-function #:make-ast-quote #:make-ast-var )
  (:import-from #:cl-cc/bootstrap
    #:register-backend-bridge-provider #:register-backend-global-seeder
    #:register-backend-parser #:register-backend-vm-integration-installer )
  (:import-from #:cl-cc/javascript/arrays #:%js-array-at #:%js-array-concat #:%js-array-copy-within #:%js-array-entries
    #:%js-array-every #:%js-array-fill #:%js-array-filter #:%js-array-find
    #:%js-array-find-index #:%js-array-find-last #:%js-array-find-last-index
    #:%js-array-flat #:%js-array-flat-map #:%js-array-for-each #:%js-array-from
    #:%js-array-from-async #:%js-array-group #:%js-array-group-to-map
    #:%js-array-includes #:%js-array-index-of #:%js-array-is-array #:%js-array-join
    #:%js-array-keys #:%js-array-last-index-of #:%js-array-map #:%js-array-of
    #:%js-array-pop #:%js-array-push #:%js-array-reduce #:%js-array-reduce-right
    #:%js-array-reverse #:%js-array-shift #:%js-array-slice #:%js-array-some
    #:%js-array-sort #:%js-array-splice #:%js-array-to-reversed #:%js-array-to-sorted
    #:%js-array-to-spliced #:%js-array-unshift #:%js-array-with #:%js-make-array
    #:%js-make-typed-array #:%js-ta-coerce-element #:%js-ta-spec-by-tag
    #:%js-ta-type-tag #:%js-uint8-from-base64 #:%js-uint8-from-hex
    #:*js-typed-array-method-table* #:%js-make-typed-array-ctor #:js-typed-array-p #:js-ta-buffer #:js-ta-byte-offset #:js-ta-element-size #:js-ta-length #:js-ta-type-name)
  (:import-from #:cl-cc/javascript/async
    #:%js-queue-microtask #:%js-make-abort-controller-constructor
    #:%js-make-abort-signal-constructor #:%js-promise-all #:%js-promise-all-settled
    #:%js-promise-any #:%js-promise-race #:%js-promise-reject #:%js-promise-resolve
    #:%js-promise-then #:%js-promise-with-resolvers #:js-promise-p #:%js-promise-try )
  (:import-from #:cl-cc/javascript/classes
    #:*js-error-class* #:*js-type-error-class* #:*js-range-error-class*
    #:*js-reference-error-class* #:*js-syntax-error-class* #:*js-eval-error-class*
    #:*js-uri-error-class* #:*js-aggregate-error-class* )
  (:import-from #:cl-cc/javascript/dates
    #:%js-date-now #:%js-date-parse-string #:%js-date-to-string #:%js-date-utc
    #:%js-make-date #:*js-date-method-table* #:*js-temporal-global* #:js-date-p )
  (:import-from #:cl-cc/javascript/errors #:%js-error-is-error #:js-exception #:js-exception-value)
  (:import-from #:cl-cc/javascript/expressions
    #:%js-bigint #:%js-bigint-to-string #:%js-bigint-val #:%js-instanceof #:%js-typeof )
  (:import-from #:cl-cc/javascript/functions
    #:%js-funcall #:*js-apply-fn* #:*js-apply-with-this-fn* #:*js-callable-p*
    #:*js-method-resolver* #:%js-dispatch-object-function-operation )
  (:import-from #:cl-cc/javascript/intl
    #:%js-make-intl-collator #:%js-make-intl-date-time-format
    #:%js-make-intl-list-format #:%js-make-intl-number-format
    #:%js-make-intl-plural-rules )
  (:import-from #:cl-cc/javascript/iterators
    #:%js-for-of #:%js-iterator-from-iterable #:%js-add-iterator-helpers!
    #:%js-iterator-concat #:%js-iterator-zip #:%js-iterator-zip-keyed #:%js-make-atomics
    #:%js-make-cl-iterator #:%js-make-generator #:%js-vec-to-iter #:%js-yield )
  (:import-from #:cl-cc/javascript/json
    #:%js-json-is-raw-json #:%js-json-parse #:%js-json-raw-json #:%js-json-stringify )
  (:import-from #:cl-cc/javascript/numbers
    #:%js-is-finite #:%js-is-nan #:%js-parse-float #:%js-parse-int #:%js-math-abs
    #:%js-math-acos #:%js-math-asin #:%js-math-atan #:%js-math-atan2 #:%js-math-ceil
    #:%js-math-clz32 #:%js-math-cos #:%js-math-exp #:%js-math-f16round #:%js-math-floor
    #:%js-math-fround #:%js-math-hypot #:%js-math-imul #:%js-math-log #:%js-math-log10
    #:%js-math-log2 #:%js-math-max #:%js-math-min #:%js-math-pow #:%js-math-random
    #:%js-math-round #:%js-math-sign #:%js-math-sin #:%js-math-sqrt #:%js-math-tan
    #:%js-math-trunc #:%js-math-sum-precise )
  (:import-from #:cl-cc/javascript/objects #:%js-structured-clone #:%js-deep-clone #:%js-finreg-register
    #:%js-finreg-unregister #:%js-make-console #:%js-make-finalization-registry
    #:%js-make-map #:%js-make-object #:%js-make-weak-map #:%js-make-weak-ref
    #:%js-make-weak-set #:%js-map-clear #:%js-map-delete #:%js-map-entries
    #:%js-map-for-each #:%js-map-get #:%js-map-get-or-insert #:%js-map-has
    #:%js-map-keys #:%js-map-set #:%js-map-size #:%js-map-values #:%js-object-assign
    #:%js-object-create #:%js-object-entries #:%js-object-extensible-p
    #:%js-object-freeze #:%js-object-from-entries #:%js-object-frozen-p
    #:%js-object-get-own-property-names #:%js-object-get-own-property-symbols
    #:%js-object-get-prototype-of #:%js-object-group-by #:%js-object-has-own
    #:%js-object-is #:%js-object-keys #:%js-object-own-keys
    #:%js-object-prevent-extensions #:%js-object-seal #:%js-object-sealed-p
    #:%js-object-set-prototype-of #:%js-object-values #:%js-set-add #:%js-set-clear
    #:%js-set-delete #:%js-set-difference #:%js-set-entries #:%js-set-for-each
    #:%js-set-has #:%js-set-intersection #:%js-set-is-disjoint-from
    #:%js-set-is-subset-of #:%js-set-is-superset-of #:%js-set-keys #:%js-set-size
    #:%js-set-symmetric-difference #:%js-set-union #:%js-symbol-description
    #:%js-symbol-for #:%js-symbol-key-for #:%js-symbol-to-string #:%js-to-string
    #:%js-weak-map-delete #:%js-weak-map-get #:%js-weak-map-get-or-insert
    #:%js-weak-map-has #:%js-weak-map-set #:%js-weak-ref-deref #:%js-weak-set-add
    #:%js-weak-set-delete #:%js-weak-set-has #:*js-symbol-global* #:js-map #:js-set
    #:js-set-p #:%js-float-infinity-p #:%js-float-nan-p #:%js-ht-p
    #:%js-int-arg-or-default #:%js-make-vec #:%js-nan-p #:%js-to-number #:%js-truthy
    #:%js-vec-p #:+js-undefined+ #:%js-this
    #:%js-register-object-function-operation-handler #:%js-make-set-from-iterable
    #:%js-object-group-into #:%js-map-get-or-insert-computed
    #:%js-weak-map-get-or-insert-computed #:js-map-p #:js-weak-map-p #:js-weak-set-p
    #:js-weak-ref-p #:js-finalization-registry-p #:js-symbol-p #:js-bigint-p #:%js-object-for-of #:%make-js-bigint #:*js-inf-float* #:*js-neg-inf-float* #:*js-nan-float*)
  (:import-from #:cl-cc/javascript/proxies
    #:%js-make-proxy-object #:%js-object-define-properties #:%js-object-define-property
    #:%js-object-get-own-property-descriptor #:%js-object-get-own-property-descriptors
    #:%js-reflect-apply #:%js-reflect-construct #:%js-reflect-define-property
    #:%js-reflect-delete-property #:%js-reflect-get
    #:%js-reflect-get-own-property-descriptor #:%js-reflect-has
    #:%js-reflect-prevent-extensions #:%js-reflect-set #:%js-reflect-set-prototype-of )
  (:import-from #:cl-cc/javascript/regex #:%js-make-regex #:%js-regex-exec #:%js-regex-test #:%js-string-match-all-regex
    #:%js-string-match-regex #:%js-string-replace-all-regex #:%js-string-replace-regex
    #:%js-string-search-regex #:%js-string-split-regex #:%js-regexp-escape #:js-regexp-p #:js-regexp-flags #:js-regexp-global-p #:js-regexp-ignore-case-p #:js-regexp-last-index #:js-regexp-multiline-p #:js-regexp-source)
  (:import-from #:cl-cc/javascript/strings
    #:%js-atob #:%js-btoa #:%js-decode-uri #:%js-decode-uri-component #:%js-encode-uri
    #:%js-encode-uri-component #:%js-make-text-decoder #:%js-make-text-encoder
    #:%js-make-url #:%js-make-url-search-params #:%js-string-at #:%js-string-char-at
    #:%js-string-char-code-at #:%js-string-code-point-at #:%js-string-concat
    #:%js-string-ends-with #:%js-string-from-char-code #:%js-string-from-code-point
    #:%js-string-includes #:%js-string-index-of #:%js-string-is-well-formed
    #:%js-string-last-index-of #:%js-string-locale-compare #:%js-string-normalize
    #:%js-string-pad-end #:%js-string-pad-start #:%js-string-raw #:%js-string-repeat
    #:%js-string-slice #:%js-string-starts-with #:%js-string-substring
    #:%js-string-to-locale-lower-case #:%js-string-to-locale-upper-case
    #:%js-string-to-lower-case #:%js-string-to-upper-case #:%js-string-to-well-formed
    #:%js-string-trim #:%js-string-trim-end #:%js-string-trim-start )
  (:import-from #:cl-cc/javascript/syntax
    #:%js-call #:define-builder-table #:js-ident-sym #:parse-js-source )
  (:export #:%build-js-builtin-map #:%install-js-vm-integration #:%js-bigint-as-int-n #:%js-bigint-as-uint-n #:%js-bound-method #:%js-builtin-ref #:%js-crypto-get-random-values #:%js-crypto-integer-typed-array-p #:%js-crypto-random-bytes #:%js-crypto-random-raw-integer #:%js-crypto-random-uuid #:%js-host-bridge-entries #:%js-make-crypto #:%js-make-namespace-object #:%js-map-group-by #:%js-math-acosh #:%js-math-asinh #:%js-math-atanh #:%js-math-cbrt #:%js-math-cosh #:%js-math-expm1 #:%js-math-log1p #:%js-math-sinh #:%js-math-tanh #:%js-number-is-finite #:%js-number-is-integer #:%js-number-is-nan #:%js-number-to-precision #:%js-prelude-form #:%js-resolve-array-method #:%js-resolve-bigint-method #:%js-resolve-date-method #:%js-resolve-finalization-registry-method #:%js-resolve-function-method #:%js-resolve-map-method #:%js-resolve-method #:%js-resolve-number-method #:%js-resolve-object-method #:%js-resolve-promise-method #:%js-resolve-regexp-method #:%js-resolve-set-method #:%js-resolve-string-method #:%js-resolve-symbol-method #:%js-resolve-typed-array-method #:%js-resolve-via-factory-table #:%js-resolve-weak-map-method #:%js-resolve-weak-ref-method #:%js-resolve-weak-set-method #:%js-runtime-global-symbols #:%js-string-char-iter #:%js-strip-pre-exp-dot #:%js-strip-trailing-dot #:%seed-js-globals #:*js-builtin-map* #:*js-map-global* #:*js-regexp-global* #:define-js-math-coerce-unary #:define-js-type-resolver #:js-program-forms))

