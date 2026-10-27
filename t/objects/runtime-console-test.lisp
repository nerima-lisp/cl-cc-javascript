;;;; t/runtime-console-test.lisp
;;;;
;;;; Split from runtime-builtins-test.lisp: %js-make-console's methods beyond
;;;; log/error (already exercised via console.log/console.error in e2e
;;;; sources) — tested directly against the dispatch table since
;;;; dir/table/trace/assert write to *error-output* or use a format
;;;; independent of %js-run-capture's stdout-only capture.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list)

(in-package :cl-cc-javascript/test)

;;; ─── console ──────────────────────────────────────────────────────────────────
;;; %js-make-console's methods beyond log/error (already exercised via
;;; console.log/console.error in e2e sources) — tested directly against the
;;; dispatch table since dir/table/trace/assert write to *error-output* or
;;; use a format independent of %js-run-capture's stdout-only capture.

(it-sequential-each (("info") ("debug"))
    "js-rt-console-~A-aliases-log"
    (method-name)
  (let ((console (cl-cc/javascript::%js-make-console)))
    (expect (eq (gethash method-name console) (gethash "log" console)) :to-be-truthy)))

(it-sequential "js-rt-console-dir-formats-value"
  (let* ((console (cl-cc/javascript::%js-make-console))
         (dir-fn (gethash "dir" console))
         (output (with-output-to-string (*standard-output*)
                   (funcall dir-fn "hi"))))
    (expect (search "hi" output) :to-be-truthy)))

(it-sequential "js-rt-console-table-formats-args"
  (let* ((console (cl-cc/javascript::%js-make-console))
         (table-fn (gethash "table" console))
         (output (with-output-to-string (*standard-output*)
                   (funcall table-fn 1 2 3))))
    (expect (search "1" output) :to-be-truthy)
    (expect (search "2" output) :to-be-truthy)
    (expect (search "3" output) :to-be-truthy)))

(it-sequential "js-rt-console-trace-prefixes-output"
  (let* ((console (cl-cc/javascript::%js-make-console))
         (trace-fn (gethash "trace" console))
         (output (with-output-to-string (*standard-output*)
                   (funcall trace-fn "boom"))))
    (expect (search "Trace:" output) :to-be-truthy)
    (expect (search "boom" output) :to-be-truthy)))

(it-sequential "js-rt-console-assert-silent-when-truthy"
  (let* ((console (cl-cc/javascript::%js-make-console))
         (assert-fn (gethash "assert" console))
         (output (with-output-to-string (*error-output*)
                   (funcall assert-fn t "should not print"))))
    (expect output :to-equal "")))

(it-sequential "js-rt-console-assert-reports-when-falsy"
  (let* ((console (cl-cc/javascript::%js-make-console))
         (assert-fn (gethash "assert" console))
         (output (with-output-to-string (*error-output*)
                   (funcall assert-fn nil "reason"))))
    (expect (search "Assertion failed:" output) :to-be-truthy)
    (expect (search "reason" output) :to-be-truthy)))

(it-sequential-each (("group") ("groupEnd") ("time") ("timeEnd") ("count") ("countReset") ("clear"))
    "js-rt-console-~A-is-a-noop"
    (method-name)
  (let* ((console (cl-cc/javascript::%js-make-console))
         (fn (gethash method-name console)))
    (expect (eq cl-cc/javascript::+js-undefined+ (funcall fn)) :to-be-truthy)))
