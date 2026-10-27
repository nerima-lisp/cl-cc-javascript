(defpackage #:cl-cc/javascript/classes
  (:use #:cl)
  (:import-from #:cl-cc/ast
    #:ast-defun-body #:ast-defun-p #:ast-defun-params #:ast-imports #:ast-lambda-body
    #:ast-lambda-p #:ast-slot-def-p #:ast-slot-initform #:ast-slot-name #:ast-var-name
    #:ast-var-p #:make-ast-call #:make-ast-defclass #:make-ast-defun #:make-ast-lambda
    #:make-ast-let #:make-ast-progn #:make-ast-quote #:make-ast-slot-def #:make-ast-var )
  (:import-from #:cl-cc/javascript/objects
    #:%js-vm-closure-p #:%js-object-call-with-this #:%js-object-funcall
    #:%js-register-object-aggregate-error-factory #:%js-register-object-error-class
    #:%js-object-for-of #:%js-class-accessor-key #:%js-set-prop #:%js-to-property-key
    #:%js-to-string #:%js-ht-p #:%js-make-ht #:%js-vec-p #:+js-undefined+ #:%js-this
    #:%js-make-vec )
  (:import-from #:cl-cc/javascript/syntax
    #:%js-call #:%js-callable-body #:%js-consume-then #:js-at-eof-p #:js-consume
    #:js-expect #:js-ident-sym #:js-peek-type #:js-peek-value #:js-tok-value
    #:register-js-parser-handler #:js-call-parser-handler
    #:js-skip-semis )
  (:export "typeerror" #:%js-class-ctor-slot #:%js-class-field-slots #:%js-class-member-key #:%js-class-member-key-ast #:%js-class-member-orig-name #:%js-class-method-slots #:%js-class-private-field-get #:%js-class-private-field-set #:%js-class-private-method-slots #:%js-class-private-static-method-slots #:%js-class-static-field-slots #:%js-class-static-slots #:%js-composite-value-p #:%js-debugger #:%js-has-private-field #:%js-lower-class-ctor #:%js-lower-class-field-inits #:%js-lower-class-make-class-call #:%js-lower-class-method-args #:%js-lower-class-private-method-inits #:%js-lower-class-static-args #:%js-lower-class-static-field-args #:%js-lower-class-to-ast #:%js-make-aggregate-error #:%js-make-class #:%js-make-error-class #:%js-make-error-instance #:%js-make-super-binding #:%js-member-kind-metadata #:%js-new #:%js-parse-accessor #:%js-parse-class-body #:%js-parse-class-body-member #:%js-parse-class-field-member #:%js-parse-class-method-member #:%js-parse-class-static-block #:%js-parse-computed-name #:%js-parse-decorator #:%js-parse-decorator-args #:%js-parse-decorator-member-chain #:%js-parse-decorators #:%js-parse-member-name #:%js-parse-method-params-body #:%js-private-ht #:%js-run-constructor #:%js-skip-balanced-until #:%js-slot-method-p #:%js-slot-to-method-lambda #:%js-spread #:%js-super-ref #:%js-wrap-method-super #:%with-private-ht #:define-js-error-subclasses #:js-parse-class-decl #:js-private-ident-sym #:*js-error-class* #:*js-type-error-class* #:*js-range-error-class* #:*js-reference-error-class* #:*js-syntax-error-class* #:*js-eval-error-class* #:*js-uri-error-class* #:*js-aggregate-error-class*))

