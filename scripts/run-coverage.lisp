;;;; run-coverage.lisp
;;;;
;;;; Load "cl-cc-javascript/test" with sb-cover instrumentation enabled and run
;;;; every test through cl-weave, writing an HTML coverage report. Coverage
;;;; instrumentation must be declaimed before the instrumented systems are
;;;; compiled, so this force-reloads the test system after enabling it.

(load (merge-pathnames "dependency-roots.lisp"
                       (or *load-pathname* *compile-file-pathname*)))

(require :sb-cover)
(declaim (optimize sb-cover:store-coverage-data))

(initialize-dependency-source-registry)

(handler-case
    (asdf:load-system "cl-cc-javascript/test" :force :all :verbose nil)
  (error (e)
    (format t "~&FAIL: ~A~%" e)
    (finish-output)
    (sb-ext:exit :code 1)))

(defparameter *passed-p*
  (uiop:symbol-call :cl-weave :run-all
                    :reporter :spec
                    :pass-with-no-tests nil
                    :coverage t
                    :coverage-report-directory "coverage-report/"))

;; LCOV alongside the HTML report: a plain-text, line-based format with one
;; absolute SF: path per file, so a consumer can filter to "this repo's own
;; src/" unambiguously by path prefix -- unlike the HTML report, whose
;; per-file links are keyed by basename only and collide across sibling
;; packages that happen to share a generic filename (package.lisp, and
;; similar). See scripts/coverage-summary.lisp.
;;
;; Best-effort: SBCL 2.6.0's SB-COVER:LCOV-REPORT has been observed to signal
;; an internal TYPE-ERROR (a VECTOR bounds check on NIL, inside SB-COVER's
;; own code, not this script's) on this codebase's coverage data. That is an
;; SBCL contrib bug to report/track upstream, not something to route around
;; here by guessing at a workaround -- so this does not fail the whole
;; coverage build over it; the HTML report above already succeeded and is
;; the coverage-report derivation's primary deliverable.
(handler-case
    (progn
      (sb-cover:lcov-report (merge-pathnames "coverage.lcov"
                                             (or *load-pathname* *compile-file-pathname*)))
      (format t "~&Wrote coverage.lcov~%"))
  (error (e)
    (format t "~&WARNING: SB-COVER:LCOV-REPORT failed (~A); skipping coverage.lcov this run.~%" e)))

(uiop:quit (if *passed-p* 0 1))
