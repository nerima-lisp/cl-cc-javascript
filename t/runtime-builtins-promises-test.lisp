;;;; t/runtime-builtins-promises-test.lisp
;;;;
;;;; Split from runtime-builtins-test.lisp: module export registration,
;;;; Promise.race/allSettled/finally/withResolvers/try, global isNaN/isFinite,
;;;; structuredClone, queueMicrotask, and the absent-by-design browser-timer /
;;;; dynamic-code (eval/Function) stubs.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list)

(in-package :cl-cc-javascript/test)

(defmacro with-fresh-js-module-exports (&body body)
  "Bind *js-module-exports* to a fresh, empty exports object for BODY. Each
module-exports test below needs its own isolated table so registrations from
one test can't leak into another."
  `(let ((cl-cc/javascript::*js-module-exports* (cl-cc/javascript::%js-make-object)))
     ,@body))

;;; ─── Module exports ─────────────────────────────────────────────────────────

(it-sequential "js-rt-export-default-registers-module-value"
  (with-fresh-js-module-exports
    (let* ((result (cl-cc/javascript::%js-export :default 42))
           (exports (cl-cc/javascript::%js-current-module-exports)))
      (expect (= 42 result) :to-be-truthy)
      (expect (= 42 (cl-cc/javascript::%js-get-prop exports "default")) :to-be-truthy))))

(it-sequential "js-rt-export-declaration-registers-named-value"
  (with-fresh-js-module-exports
    (let* ((fn (lambda () 7))
           (result (cl-cc/javascript::%js-export :declaration fn nil '("add")))
           (exports (cl-cc/javascript::%js-current-module-exports)))
      (expect result :to-be fn)
      (expect (gethash "add" exports) :to-be fn))))

(it-sequential "js-rt-export-reexport-records-source-metadata"
  (with-fresh-js-module-exports
    (cl-cc/javascript::%js-export
     :re-export
     (list (list :local "foo" :exported "bar"))
     "./dep.js")
    (let* ((exports (cl-cc/javascript::%js-current-module-exports))
           (reexports (cl-cc/javascript::%js-get-prop exports "__reexports__"))
           (entry (aref reexports 0))
           (specs (cl-cc/javascript::%js-get-prop entry "value"))
           (spec (aref specs 0)))
      (expect (= 1 (length reexports)) :to-be-truthy)
      (expect (cl-cc/javascript::%js-get-prop entry "kind") :to-equal "named")
      (expect (cl-cc/javascript::%js-get-prop entry "from") :to-equal "./dep.js")
      (expect (cl-cc/javascript::%js-get-prop spec "local") :to-equal "foo")
      (expect (cl-cc/javascript::%js-get-prop spec "exported") :to-equal "bar"))))

;;; ─── Promise.race ────────────────────────────────────────────────────────────

(it-sequential "js-rt-promise-race-returns-first"
  (let* ((p1  (cl-cc/javascript::%js-promise-resolve 1))
         (p2  (cl-cc/javascript::%js-promise-resolve 2))
         (arr (%jr-arr p1 p2))
         (winner (cl-cc/javascript::%js-promise-race arr)))
    (expect winner :to-be p1)))

(it-sequential "js-rt-promise-race-empty-pending"
  (let ((result (cl-cc/javascript::%js-promise-race (%jr-arr))))
    (expect (cl-cc/javascript::js-promise-p result) :to-be-truthy)
    (expect (cl-cc/javascript::js-promise-settled-p result) :to-be-falsy)))

;;; ─── Promise.allSettled ──────────────────────────────────────────────────────

(it-sequential "js-rt-promise-all-settled-mixed"
  (let* ((p1  (cl-cc/javascript::%js-promise-resolve "ok"))
         (p2  (cl-cc/javascript::%js-promise-reject  "err"))
         (arr (%jr-arr p1 p2))
         (settled (cl-cc/javascript::%js-await
                   (cl-cc/javascript::%js-promise-all-settled arr)))
         (r1  (aref settled 0))
         (r2  (aref settled 1)))
    (expect (gethash "status" r1) :to-equal "fulfilled")
    (expect (gethash "value"  r1) :to-equal "ok")
    (expect (gethash "status" r2) :to-equal "rejected")
    (expect (gethash "reason" r2) :to-equal "err")))

;;; ─── Promise.finally ─────────────────────────────────────────────────────────

(it-sequential "js-rt-promise-finally-calls-cleanup"
  (let* ((called (list nil))
         (p      (cl-cc/javascript::%js-promise-resolve 42))
         (result (cl-cc/javascript::%js-promise-finally
                  p (lambda () (setf (car called) t)))))
    (expect (car called) :to-be-truthy)
    (expect result :to-be p)))

;;; ─── Promise.withResolvers ───────────────────────────────────────────────────

(it-sequential "js-rt-promise-with-resolvers"
  (let* ((obj     (cl-cc/javascript::%js-promise-with-resolvers))
         (promise  (gethash "promise" obj))
         (resolve  (gethash "resolve" obj)))
    (expect (cl-cc/javascript::js-promise-p promise) :to-be-truthy)
    (expect (functionp resolve) :to-be-truthy)
    (funcall resolve 99)
    (expect (= 99 (cl-cc/javascript::%js-await promise)) :to-be-truthy)))

;;; ─── Promise.try ─────────────────────────────────────────────────────────────

(it-sequential "js-rt-promise-try-success"
  (let ((result (cl-cc/javascript::%js-promise-try (lambda () 7))))
    (expect (= 7 (cl-cc/javascript::%js-await result)) :to-be-truthy)))

;;; ─── Global isNaN / isFinite (with coercion) ─────────────────────────────────

(it-sequential-each ((#.cl-cc/javascript::*js-nan-float* t) ("NaN" t)
                     ("42" nil) (5 nil))
    "js-rt-global-is-nan ~A"
    (val expected)
  (expect (cl-cc/javascript::%js-is-nan val) :to-equal expected))

(it-sequential-each ((42 t) ("3.14" t)
                     (#.cl-cc/javascript::*js-nan-float* nil)
                     (#.cl-cc/javascript::*js-inf-float* nil))
    "js-rt-global-is-finite ~A"
    (val expected)
  (expect (cl-cc/javascript::%js-is-finite val) :to-equal expected))

;;; ─── structuredClone ─────────────────────────────────────────────────────────

(it-sequential "js-rt-structured-clone"
  (let* ((orig  (cl-cc/javascript::%js-make-object "x" 10))
         (clone (cl-cc/javascript::%js-structured-clone orig)))
    (expect (eq orig clone) :to-be-falsy)
    (expect (= 10 (gethash "x" clone)) :to-be-truthy)))

;;; ─── queueMicrotask / browser timers ─────────────────────────────────────────

(it-sequential "js-rt-queue-microtask-runs-fn"
  (let ((called (list nil)))
    (let ((ret (cl-cc/javascript::%js-queue-microtask
                (lambda () (setf (car called) t)))))
      (expect (car called) :to-be-truthy)
      (expect ret :to-be-js-undefined))))

(it-sequential-each (("setTimeout") ("setInterval") ("clearTimeout") ("clearInterval"))
    "js-rt-browser-timer-stubs-absent ~A"
    (name)
  (expect (nth-value 1 (gethash name cl-cc/javascript::*js-builtin-map*)) :to-be-falsy)
  (expect (find name cl-cc/javascript::*js-prelude-global-specs*
                :key #'second
                :test #'string=) :to-be-falsy)
  (expect (nth-value 1
                (gethash (cl-cc/javascript::js-ident-sym name)
                         cl-cc/javascript::*js-coercion-call-helpers*)) :to-be-falsy))

;;; ─── Dynamic code stubs ─────────────────────────────────────────────────────

(it-sequential-each (("eval") ("Function"))
    "js-rt-dynamic-code-stubs-absent ~A"
    (name)
  (expect (nth-value 1 (gethash name cl-cc/javascript::*js-builtin-map*)) :to-be-falsy)
  (expect (find name cl-cc/javascript::*js-prelude-global-specs*
                :key #'second
                :test #'string=) :to-be-falsy)
  (expect (nth-value 1
                (gethash (cl-cc/javascript::js-ident-sym name)
                         cl-cc/javascript::*js-coercion-call-helpers*)) :to-be-falsy))
