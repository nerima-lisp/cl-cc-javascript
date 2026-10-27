(defpackage #:cl-cc/javascript/functions
  (:use #:cl)
  (:import-from #:cl-cc/ast
    #:ast-apply-args #:ast-apply-func #:ast-apply-p #:ast-call-args #:ast-call-func
    #:ast-call-p #:ast-list #:ast-progn-forms #:ast-progn-p #:ast-quote-p
    #:ast-quote-value #:ast-var-name #:ast-var-p #:make-ast-call #:make-ast-defun
    #:make-ast-if #:make-ast-lambda #:make-ast-let #:make-ast-progn #:make-ast-quote
    #:make-ast-setq #:make-ast-var )
  (:import-from #:cl-cc/javascript/arrays
    #:%js-list-to-array #:%js-make-array )
  (:import-from #:cl-cc/javascript/async
    #:%js-async )
  (:import-from #:cl-cc/javascript/classes
    #:%js-spread )
  (:import-from #:cl-cc/javascript/expressions
    #:%js-spread-marker-p #:js-parse-function-body #:js-parse-function-expr
    #:js-parse-postfix )
  (:import-from #:cl-cc/javascript/modules
    #:%js-import #:%js-import-meta )
  (:import-from #:cl-cc/javascript/objects
    #:%js-make-object #:%js-object-assign #:%js-object-spread-set #:%js-ht-p
    #:+js-undefined+ #:%js-this #:%js-object-make-async #:%js-object-make-generator )
  (:import-from #:cl-cc/javascript/statements
    #:%js-binding-sym #:%js-binding-to-sym #:%js-consume-expected
    #:%js-emit-destructure-bindings #:%js-lower-do-while-with-tags
    #:%js-lower-while-with-tags #:%js-parse-binding-pattern #:%js-parse-stmt-body
    #:%js-truthy-call #:js-parse-block #:with-js-loop-tags )
  (:import-from #:cl-cc/javascript/syntax
    #:%js-call #:%js-callable-body #:%js-consume-then #:%js-finish-let-bindings
    #:js-at-eof-p #:js-at-op-p #:js-consume #:js-expect #:js-ident-sym #:js-peek
    #:js-peek-type #:js-peek-value #:js-tok-value #:register-js-parser-handler #:js-call-parser-handler
    #:js-skip-semis )
  (:export #:%js-call-callee-name #:%js-call-with-this #:%js-comma-list-step #:%js-expr-to-binding-pattern #:%js-finish-arrow-function #:%js-finish-async-arrow #:%js-funcall #:%js-method-ref #:%js-object-fold-fields #:%js-parse-arrow-or-paren-item #:%js-parse-async-expr #:%js-parse-class-expr #:%js-parse-if-tail #:%js-parse-import-expr #:%js-parse-param-list #:%js-parse-paren-or-arrow #:%js-prepend-param-destructuring #:%js-proto-accessor-lookup #:%js-proto-method-lookup #:%js-rest-binding #:%js-split-params-by-defaults #:%js-spread-array-elements #:%js-wrap-callable-body #:*js-apply-fn* #:*js-apply-with-this-fn* #:*js-callable-p* #:*js-method-resolver* #:js-parse-arguments #:js-parse-do-while-stmt #:js-parse-function-decl #:js-parse-if-stmt #:js-parse-params #:js-parse-while-stmt #:%js-dispatch-object-function-operation))

