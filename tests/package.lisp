;;;; tests/package.lisp — test package for cl-cc-javascript (cl-weave based).

(defpackage :cl-cc-javascript/test
  (:use :cl :cl-weave)
  (:shadowing-import-from :cl-weave #:describe)
  (:import-from :cl-cc #:make-ast-var #:make-ast-quote))
