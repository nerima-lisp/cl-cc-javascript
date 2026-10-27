(defpackage #:cl-cc/javascript/disposables
  (:use #:cl)
  (:import-from #:cl-cc/ast
    #:ast-progn-forms #:make-ast-call #:make-ast-go #:make-ast-lambda #:make-ast-let
    #:make-ast-progn #:make-ast-quote #:make-ast-return-from #:make-ast-var )
  (:import-from #:cl-cc/javascript/classes
    #:%js-debugger )
  (:import-from #:cl-cc/javascript/errors
    #:%js-throw )
  (:import-from #:cl-cc/javascript/expressions
    #:%js-using-register )
  (:import-from #:cl-cc/javascript/statements
    #:%js-binding-sym #:%js-consume-expected #:%js-try-catch-finally
    #:*js-break-targets* #:*js-continue-targets* #:*js-label-break-targets*
    #:*js-label-continue-targets* #:*js-loop-break-target* #:*js-loop-continue-target*
    #:js-parse-block )
  (:import-from #:cl-cc/javascript/syntax
    #:js-at-eof-p #:js-consume #:js-expect #:js-peek #:js-peek-type #:js-peek-value
    #:js-tok-value #:register-js-parser-handler #:js-call-parser-handler #:js-skip-semis )
  (:export #:%js-build-catch-dispatch #:%js-parse-catch-binding #:%js-parse-catch-clauses #:%js-parse-finally-clause #:js-parse-break-stmt #:js-parse-continue-stmt #:js-parse-debugger-stmt #:js-parse-return-stmt #:js-parse-throw-stmt #:js-parse-try-stmt #:js-parse-using-decl))

