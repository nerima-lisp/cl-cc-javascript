(defpackage #:cl-cc/javascript/statements
  (:use #:cl)
  (:import-from #:cl-cc/ast
    #:ast-let-body #:ast-let-declarations #:ast-list #:ast-progn-forms #:ast-progn-p
    #:make-ast-block #:make-ast-call #:make-ast-go #:make-ast-if #:make-ast-let
    #:make-ast-progn #:make-ast-quote #:make-ast-return-from #:make-ast-setq
    #:make-ast-tagbody #:make-ast-var )
  (:import-from #:cl-cc/javascript/async
    #:%js-await )
  (:import-from #:cl-cc/javascript/errors
    #:js-exception #:js-exception-value )
  (:import-from #:cl-cc/javascript/iterators
    #:%js-iter-values )
  (:import-from #:cl-cc/javascript/objects
    #:%js-destructure-array #:%js-destructure-object #:%js-get-prop #:%js-internal-key-p
    #:%js-object-own-string-property-keys #:js-map #:js-set #:%js-ht-p #:%js-strict-eq
    #:%js-truthy #:%js-vec-p #:+js-undefined+ #:%js-object-funcall )
  (:import-from #:cl-cc/javascript/syntax #:%js-consume-then #:%js-finish-let-bindings #:js-at-eof-p #:js-consume #:js-expect
    #:js-peek #:js-peek-type #:js-peek-value #:js-tok-value #:with-js-parse-depth
    #:register-js-source-parser #:js-parser-handler #:js-call-parser-handler
    #:js-skip-semis
    #:register-js-parser-handler #:*js-contextual-keyword-token-types*)
  (:export #:%js-binding-sym #:%js-binding-to-sym #:%js-consume-expected #:%js-default-access #:%js-destructure-sub-bindings #:%js-emit-array-element-bindings #:%js-emit-array-pattern-bindings #:%js-emit-array-rest-binding #:%js-emit-destructure-bindings #:%js-emit-named-property-bindings #:%js-emit-object-pattern-bindings #:%js-emit-rest-property-binding #:%js-for-in #:%js-iter-keys #:%js-lower-do-while-with-tags #:%js-lower-for-c-style #:%js-lower-for-of-in #:%js-lower-switch #:%js-lower-while-with-tags #:%js-make-tagbody #:%js-parse-all-stmts #:%js-parse-array-binding-pattern #:%js-parse-binding-pattern #:%js-parse-for-c-style-declared-stmt #:%js-parse-for-in-of-stmt #:%js-parse-for-in-stmt #:%js-parse-for-of-stmt #:%js-parse-object-binding-pattern #:%js-parse-pattern-default #:%js-parse-stmt-body #:%js-parse-switch-body #:%js-truthy-call #:%js-try-catch-finally #:*js-break-targets* #:*js-continue-targets* #:*js-label-break-targets* #:*js-label-continue-targets* #:*js-loop-break-target* #:*js-loop-continue-target* #:*js-stmt-parsers* #:define-js-stmt-parser #:js-parse-block #:js-parse-for-stmt #:js-parse-stmt #:js-parse-stmt-list #:js-parse-switch-stmt #:js-parse-var-decl #:with-js-loop-tags #:*js-gdi-mode* #:*js-gdi-lower-var-declarations* #:*js-gdi-function-depth* #:*js-gdi-lexical-scope-depth* #:*js-gdi-collect-global-lexical-bindings* #:*js-gdi-global-lexical-bindings*))

