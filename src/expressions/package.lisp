(defpackage #:cl-cc/javascript/expressions
  (:use #:cl)
  (:import-from #:cl-cc/ast
    #:ast-call-args #:ast-call-func #:ast-call-p #:ast-int-p #:ast-int-value
    #:ast-var-name #:ast-var-p #:make-ast-apply #:make-ast-binop #:make-ast-call
    #:make-ast-if #:make-ast-int #:make-ast-lambda #:make-ast-let #:make-ast-progn
    #:make-ast-quote #:make-ast-setq #:make-ast-var )
  (:import-from #:cl-cc/javascript/arrays
    #:%js-make-array #:%js-make-tagged-template-strings )
  (:import-from #:cl-cc/javascript/async
    #:%js-await #:%js-queue-microtask )
  (:import-from #:cl-cc/javascript/classes
    #:%js-class-private-field-get #:%js-class-private-field-set #:%js-has-private-field
    #:%js-new #:%js-spread )
  (:import-from #:cl-cc/javascript/iterators
    #:%js-make-async #:%js-make-async-generator #:%js-wrap-generator-body #:%js-yield
    #:%js-yield-from )
  (:import-from #:cl-cc/javascript/numbers
    #:%js-is-finite #:%js-is-nan #:%js-parse-float #:%js-parse-int )
  (:import-from #:cl-cc/javascript/objects
    #:%js-vm-closure-p #:%js-structured-clone #:+js-undefined+ #:+js-null+ #:+js-nan+
    #:+js-infinity+ #:+js-neg-infinity+ #:*js-nan-float* #:*js-inf-float*
    #:*js-neg-inf-float* #:%js-make-ht #:%js-make-vec #:%js-vec-p #:%js-ht-p
    #:%js-float-nan-p #:%js-float-infinity-p #:%js-nan-p #:js-bigint #:js-bigint-p
    #:js-bigint-value #:%make-js-bigint #:%js-truthy #:%js-not-nullish #:%js-to-number
    #:%js-int-arg-or-default #:%js-strict-eq #:%js-same-value-zero #:%js-this #:%js-add
    #:%js-delete #:%js-divide #:%js-get-prop #:%js-in #:%js-make-object
    #:%js-make-symbol #:%js-mod #:%js-object-assign #:%js-object-spread-set
    #:%js-optional-call #:%js-optional-chain #:%js-optional-method-call #:%js-pow
    #:%js-set-prop #:%js-to-string #:js-symbol #:%js-object-instanceof-p )
  (:import-from #:cl-cc/javascript/regex
    #:%js-make-regex )
  (:import-from #:cl-cc/javascript/statements
    #:%js-truthy-call )
  (:import-from #:cl-cc/javascript/strings
    #:%js-atob #:%js-btoa #:%js-decode-uri #:%js-decode-uri-component #:%js-encode-uri
    #:%js-encode-uri-component )
  (:import-from #:cl-cc/javascript/syntax #:%js-call #:%js-callable-body #:%js-consume-then #:define-builder-table
    #:js-at-eof-p #:js-at-op-p #:js-consume #:js-expect #:js-ident-sym #:js-peek
    #:js-peek-type #:js-peek-value #:js-tok-type #:js-tok-value #:with-js-parse-depth
    #:register-js-parser-handler #:js-call-parser-handler #:*js-contextual-keyword-token-types*)
  (:export #:%js-accessor #:%js-assign-pattern #:%js-bigint #:%js-bigint-add #:%js-bigint-bitwise-and #:%js-bigint-bitwise-or #:%js-bigint-bitwise-xor #:%js-bigint-compare #:%js-bigint-div #:%js-bigint-lshift #:%js-bigint-mod #:%js-bigint-mul #:%js-bigint-negate #:%js-bigint-pow #:%js-bigint-rshift #:%js-bigint-sub #:%js-bigint-to-string #:%js-bigint-val #:%js-bitwise-and #:%js-bitwise-not #:%js-bitwise-or #:%js-bitwise-xor #:%js-build-function-expr-ast #:%js-chain-step #:%js-compound-rhs   #:%js-ge #:%js-gt  #:%js-incdec-setq #:%js-instanceof  #:%js-items-have-spread-p #:%js-le #:%js-logical-assign-short-circuit-p #:%js-loose-eq #:%js-lower-assignment #:%js-lower-binary #:%js-lower-coercion-call #:%js-lower-incdec #:%js-lower-logical-and #:%js-lower-logical-assign #:%js-lower-logical-or #:%js-lower-nullish-coalesce #:%js-lower-place-incdec #:%js-lower-short-circuit #:%js-lt    #:%js-new-target #:%js-not  #:%js-parse-member-dot #:%js-parse-member-optional-chain #:%js-parse-object-property #:%js-parse-object-property-accessor #:%js-parse-object-property-async-method #:%js-parse-object-property-computed #:%js-parse-object-property-generator-method #:%js-parse-object-property-shorthand-or-method-or-kv #:%js-parse-object-property-spread #:%js-parse-postfix-call #:%js-parse-postfix-computed-member #:%js-parse-postfix-dot #:%js-parse-postfix-optional-chain #:%js-parse-tagged-template #:%js-parse-template-literal #:%js-parse-yield-expr #:%js-place-get-prop-p #:%js-postfix-dec #:%js-postfix-inc #:%js-prefix-dec #:%js-prefix-inc #:%js-private-field-in-check-name #:%js-relational  #:%js-shift-left #:%js-shift-right #:%js-sign-extend32 #:%js-spread-list-expr #:%js-spread-marker-p  #:%js-template-parts-and-rest #:%js-to-int32   #:%js-typeof #:%js-unary-plus #:%js-unsigned-shift-right #:%js-using-register  #:*js-binop-runtime-helpers* #:*js-coercion-call-helpers* #:*js-direct-binop-keywords* #:*js-op-infix-prec* #:*js-primary-constant-builders* #:*js-unary-kw-builders* #:*js-unary-op-builders*      #:define-js-bigint-binop #:define-js-bigint-dividing-op #:define-js-bitwise-binop #:define-js-relational-op  #:js-infix-prec #:js-parse-array-literal #:js-parse-assignment-expr #:js-parse-expr #:js-parse-function-body #:js-parse-function-expr #:js-parse-member-expr #:js-parse-new-expr #:js-parse-object-literal #:js-parse-postfix #:js-parse-primary #:js-parse-unary ))

