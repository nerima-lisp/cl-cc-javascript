;;;; run-tests.lisp
;;;;
;;;; Load "cl-cc-javascript/test" against the sibling checkouts resolved by
;;;; scripts/dependency-roots.lisp and run every test through cl-weave. Exits
;;;; non-zero on any load error, on zero tests loaded, or on any test failure.
;;;;
;;;; This file sits at the repository root (the org-wide test entry point), so
;;;; the helper it loads is addressed relative to that root, not as a sibling.

(load (merge-pathnames "scripts/dependency-roots.lisp"
                       (or *load-pathname* *compile-file-pathname*)))

(initialize-dependency-source-registry)

(handler-case
    (asdf:load-system "cl-cc-javascript/test" :verbose nil)
  (error (e)
    (format t "~&FAIL: ~A~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))

(let ((plan (uiop:symbol-call :cl-weave :list-tests
                              :reporter :json
                              :stream (make-broadcast-stream))))
  (format t "~&Loaded ~D tests.~%" (length plan))
  (when (zerop (length plan))
    (format t "~&FAIL: cl-cc-javascript loaded zero tests~%")
    (finish-output)
    (sb-ext:exit :code 1)))

(uiop:quit (if (uiop:symbol-call :cl-weave :run-all
                                 :reporter :spec
                                 :pass-with-no-tests nil)
               0
               1))
