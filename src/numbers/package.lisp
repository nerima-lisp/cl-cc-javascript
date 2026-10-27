(defpackage #:cl-cc/javascript/numbers
  (:use #:cl)
  (:import-from #:cl-cc/javascript/objects #:%js-to-string #:%js-float-infinity-p #:%js-float-nan-p #:%js-int-arg-or-default
    #:%js-nan-p #:%js-to-number #:+js-undefined+ #:*js-nan-float* #:%js-object-for-of #:*js-inf-float* #:*js-neg-inf-float*)
  (:import-from #:cl-cc/javascript/syntax
    #:define-builder-table #:js-digit-p #:js-hex-digit-p #:js-id-start-p #:make-js-token
    #:register-js-lexer-extension )
  (:export #:%js-f16round-number #:%js-math-abs #:%js-math-acos #:%js-math-asin #:%js-math-atan #:%js-math-atan2 #:%js-math-ceil #:%js-math-clz32 #:%js-math-cos #:%js-math-exp #:%js-math-f16round #:%js-math-floor #:%js-math-fround #:%js-math-hypot #:%js-math-imul #:%js-math-log #:%js-math-log10 #:%js-math-log2 #:%js-math-max #:%js-math-min #:%js-math-pow #:%js-math-random #:%js-math-round #:%js-math-sign #:%js-math-sin #:%js-math-sqrt #:%js-math-tan #:%js-math-trunc #:%js-round-half-even #:%lex-js-binary-digits #:%lex-js-decimal-digits #:%lex-js-decimal-number #:%lex-js-hex-digits #:%lex-js-octal-digits #:%lex-js-radix-number #:*js-radix-prefix-readers* #:define-js-digit-reader #:define-js-math-rounding #:define-js-math-trig #:lex-js-number #:%js-parse-int #:%js-parse-float #:%js-is-nan #:%js-is-finite #:%js-math-sum-precise))

