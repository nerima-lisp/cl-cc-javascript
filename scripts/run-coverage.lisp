;;;; run-coverage.lisp
;;;;
;;;; Load :cl-cc-javascript-test with sb-cover instrumentation enabled and run
;;;; every test through cl-weave, writing an HTML coverage report. Coverage
;;;; instrumentation must be declaimed before the instrumented systems are
;;;; compiled, so this force-reloads :cl-cc-javascript-test after enabling it.

(load (merge-pathnames "dependency-roots.lisp"
                       (or *load-pathname* *compile-file-pathname*)))

(require :sb-cover)
(declaim (optimize sb-cover:store-coverage-data))

(initialize-dependency-source-registry)

(handler-case
    (asdf:load-system :cl-cc-javascript-test :force :all :verbose nil)
  (error (e)
    (format t "~&FAIL: ~A~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))

(uiop:quit (if (uiop:symbol-call :cl-weave :run-all
                                 :reporter :spec
                                 :pass-with-no-tests nil
                                 :coverage t
                                 :coverage-report-directory "coverage-report/")
               0
               1))
