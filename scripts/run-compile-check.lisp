;;;; run-compile-check.lisp
;;;;
;;;; Compile and load :cl-cc-javascript (production system only) against the
;;;; sibling checkouts resolved by dependency-roots.lisp, then exit non-zero
;;;; on any compile/load error. This is the build gate; run-tests.lisp is the
;;;; test gate.

(load (merge-pathnames "dependency-roots.lisp"
                       (or *load-pathname* *compile-file-pathname*)))

(initialize-dependency-source-registry)

(handler-case
    (progn
      (asdf:load-system :cl-cc-javascript)
      (format t "~&PASS cl-cc-javascript compile check~%")
      (finish-output))
  (error (e)
    (format t "~&FAIL cl-cc-javascript: ~A~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))
