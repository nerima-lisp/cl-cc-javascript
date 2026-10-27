;;;; t/runtime-builtins-promises-test.lisp
;;;;
;;;; Split from runtime-builtins-test.lisp: module export registration,
;;;; Promise.race/allSettled/finally/withResolvers/try, global isNaN/isFinite,
;;;; structuredClone, queueMicrotask, and the absent-by-design browser-timer /
;;;; dynamic-code (eval/Function) stubs.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list)

(in-package #:cl-cc/javascript/async/test)

;;; ─── Module exports ─────────────────────────────────────────────────────────

(defun %register-async-runtime-builtins-promises-tests ()
  (it-sequential "js-rt-promise-race-returns-first"
    (let* ((p1  (cl-cc/javascript/async::%js-promise-resolve 1))
           (p2  (cl-cc/javascript/async::%js-promise-resolve 2))
           (arr (vector p1 p2))
           (winner (cl-cc/javascript/async::%js-promise-race arr)))
      (expect winner :to-be p1)))
  (it-sequential "js-rt-promise-race-empty-pending"
    (let ((result (cl-cc/javascript/async::%js-promise-race (vector))))
      (expect (cl-cc/javascript/async::js-promise-p result) :to-be-truthy)
      (expect (cl-cc/javascript/async::js-promise-settled-p result) :to-be-falsy)))
  (it-sequential "js-rt-promise-all-settled-mixed"
    (let* ((p1  (cl-cc/javascript/async::%js-promise-resolve "ok"))
           (p2  (cl-cc/javascript/async::%js-promise-reject  "err"))
           (arr (vector p1 p2))
           (settled (cl-cc/javascript/async::%js-await
                     (cl-cc/javascript/async::%js-promise-all-settled arr)))
           (r1  (aref settled 0))
           (r2  (aref settled 1)))
      (expect (gethash "status" r1) :to-equal "fulfilled")
      (expect (gethash "value"  r1) :to-equal "ok")
      (expect (gethash "status" r2) :to-equal "rejected")
      (expect (gethash "reason" r2) :to-equal "err")))
  (it-sequential "js-rt-promise-with-resolvers"
    (let* ((obj     (cl-cc/javascript/async::%js-promise-with-resolvers))
           (promise  (gethash "promise" obj))
           (resolve  (gethash "resolve" obj)))
      (expect (cl-cc/javascript/async::js-promise-p promise) :to-be-truthy)
      (expect (functionp resolve) :to-be-truthy)
      (funcall resolve 99)
      (expect (= 99 (cl-cc/javascript/async::%js-await promise)) :to-be-truthy)))
  (it-sequential "js-rt-promise-try-success"
    (let ((result (%js-promise-try (lambda () 7))))
      (expect (= 7 (cl-cc/javascript/async::%js-await result)) :to-be-truthy)))
  (it-sequential "js-rt-queue-microtask-runs-fn"
    (let ((called (list nil)))
      (let ((ret (cl-cc/javascript/async::%js-queue-microtask
                  (lambda () (setf (car called) t)))))
        (expect (car called) :to-be-truthy)
        (expect ret :to-be-js-undefined))))
  )

;;; ─── Promise.race ────────────────────────────────────────────────────────────

;;; ─── Promise.allSettled ──────────────────────────────────────────────────────

;;; ─── Promise.withResolvers ───────────────────────────────────────────────────

;;; ─── Promise.try ─────────────────────────────────────────────────────────────

;;; ─── Global isNaN / isFinite (with coercion) ─────────────────────────────────

;;; ─── structuredClone ─────────────────────────────────────────────────────────

;;; ─── queueMicrotask / browser timers ─────────────────────────────────────────

;;; ─── Dynamic code stubs ─────────────────────────────────────────────────────

;;; ─── Promise built-ins ───────────────────────────────────────────────────────

(defun %register-async-runtime-collections-values-tests ()
  (it-sequential "js-rt-promise-resolve-await"
    (let* ((p (cl-cc/javascript::%js-promise-resolve 42))
           (v (cl-cc/javascript::%js-await p)))
      (expect (= 42 v) :to-be-truthy)))
  (it-sequential "js-rt-promise-reject-await"
    (let ((p (cl-cc/javascript::%js-promise-reject "oops")))
      (expect-rejects (lambda () (cl-cc/javascript::%js-await p))
        :to-be-instance-of 'cl-cc/javascript:js-exception)))
  (it-sequential "js-rt-promise-then"
    (let* ((p (cl-cc/javascript::%js-promise-resolve 5))
           (p2 (cl-cc/javascript::%js-promise-then
                p (lambda (v &rest _) (declare (ignore _)) (* v 2)))))
      (expect (= 10 (cl-cc/javascript::%js-await p2)) :to-be-truthy)))
  (it-sequential "js-rt-promise-all"
    (let* ((promises (vector (cl-cc/javascript::%js-promise-resolve 1)
                              (cl-cc/javascript::%js-promise-resolve 2)
                              (cl-cc/javascript::%js-promise-resolve 3)))
           (result (cl-cc/javascript::%js-await
                    (cl-cc/javascript::%js-promise-all promises))))
      (expect (coerce result (quote list)) :to-equal '(1 2 3))))
  (it-sequential "js-rt-promise-any-first-fulfilled"
    (let* ((p1 (cl-cc/javascript::%js-promise-reject "e1"))
           (p2 (cl-cc/javascript::%js-promise-resolve 42))
           (arr (vector p1 p2))
           (r   (cl-cc/javascript::%js-promise-any arr)))
      (expect (cl-cc/javascript::js-promise-rejected-p r) :to-be-falsy)
      (expect (= 42 (cl-cc/javascript::js-promise-value r)) :to-be-truthy)))
  (it-sequential "js-rt-promise-any-all-rejected"
    (let* ((p1 (cl-cc/javascript::%js-promise-reject "e1"))
           (p2 (cl-cc/javascript::%js-promise-reject "e2"))
           (arr (vector p1 p2))
           (r   (cl-cc/javascript::%js-promise-any arr))
           (err (cl-cc/javascript::js-promise-value r)))
      (expect (cl-cc/javascript::js-promise-rejected-p r) :to-be-truthy)
      ;; Regression: this used to reject with a plain object that merely had
      ;; matching "errors"/"message" properties — instanceof AggregateError
      ;; (and instanceof Error) both failed, unlike real Promise.any.
      (expect (cl-cc/javascript::%js-instanceof
               err *js-aggregate-error-class*) :to-be-truthy)
      (expect (gethash "message" err) :to-equal "All promises were rejected")
      (expect (coerce (gethash "errors" err) (quote list)) :to-equal '("e1" "e2"))))
  (it-sequential "js-rt-promise-with-resolvers"
    (let* ((trio    (cl-cc/javascript::%js-promise-with-resolvers))
           (promise (gethash "promise" trio))
           (resolve (gethash "resolve" trio))
           (reject  (gethash "reject"  trio)))
      (expect (cl-cc/javascript::js-promise-p promise) :to-be-truthy)
      (expect (functionp resolve) :to-be-truthy)
      (expect (functionp reject) :to-be-truthy)
      (funcall resolve 99)
      (expect (= 99 (cl-cc/javascript::js-promise-value promise)) :to-be-truthy)))
  )

;;; ─── AbortController ─────────────────────────────────────────────────────────

(defun %register-async-runtime-builtins-platform-object-tests ()
  (it-sequential "js-rt-abort-controller"
    (let* ((ctrl   (cl-cc/javascript/async:%js-make-abort-controller))
           (sig    (gethash "signal" ctrl))
           (abort  (gethash "abort"  ctrl)))
      (expect (gethash "aborted" sig) :to-be-falsy)
      (funcall abort "reason")
      (expect (gethash "aborted" sig) :to-be-truthy)
      (expect (gethash "reason" sig) :to-equal "reason")))
  (it-sequential "js-rt-abort-controller-dispatches-once"
    (let* ((ctrl   (cl-cc/javascript/async:%js-make-abort-controller))
           (sig    (gethash "signal" ctrl))
           (abort  (gethash "abort" ctrl))
           (onabort-calls 0)
           (listener-calls 0))
      (setf (gethash "onabort" sig)
            (lambda (event)
              (incf onabort-calls)
              (expect (gethash "type" event) :to-equal "abort")
              (expect (gethash "target" event) :to-be sig)))
      (funcall (gethash "addEventListener" sig)
               "abort"
               (lambda (event)
                 (incf listener-calls)
                 (expect (gethash "type" event) :to-equal "abort")
                 (expect (gethash "currentTarget" event) :to-be sig)))
      (funcall abort "first")
      (funcall abort "second")
      (expect (= 1 onabort-calls) :to-be-truthy)
      (expect (= 1 listener-calls) :to-be-truthy)
      (expect (gethash "reason" sig) :to-equal "first")))
  (it-sequential "js-rt-abort-signal-remove-event-listener"
    (let* ((ctrl  (cl-cc/javascript/async:%js-make-abort-controller))
           (sig   (gethash "signal" ctrl))
           (calls 0)
           (listener (lambda (&rest _) (declare (ignore _)) (incf calls))))
      (funcall (gethash "addEventListener" sig) "abort" listener)
      (funcall (gethash "removeEventListener" sig) "abort" listener)
      (funcall (gethash "abort" ctrl) "done")
      (expect (zerop calls) :to-be-truthy)))
  (it-sequential "js-rt-abort-signal-throw-if-aborted"
    (let ((sig (cl-cc/javascript/async:%js-abort-signal-aborted "boom")))
      (expect (gethash "aborted" sig) :to-be-truthy)
      (expect (gethash "reason" sig) :to-equal "boom")
      (handler-case
          (progn
            (funcall (gethash "throwIfAborted" sig))
            (expect nil :to-be-truthy))
        (cl-cc/javascript:js-exception (c)
          (expect (cl-cc/javascript:js-exception-value c) :to-equal "boom")))))
  (it-sequential "js-rt-abort-signal-static-helpers"
    (let* ((ctor    (cl-cc/javascript/async:%js-make-abort-signal-constructor))
           (aborted (funcall (gethash "abort" ctor) "done"))
           (timeout (funcall (gethash "timeout" ctor) 5))
           (reason  (gethash "reason" timeout))
           (source  (gethash "signal" (cl-cc/javascript/async:%js-make-abort-controller)))
           (combo   (funcall (gethash "any" ctor) (%jr-arr source))))
      (expect (gethash "aborted" aborted) :to-be-truthy)
      (expect (gethash "reason" aborted) :to-equal "done")
      (expect (gethash "aborted" timeout) :to-be-truthy)
      (expect (gethash "name" reason) :to-equal "TimeoutError")
      (expect (gethash "aborted" combo) :to-be-falsy)
      (cl-cc/javascript/async:%js-abort-signal-abort source "input")
      (expect (gethash "aborted" combo) :to-be-truthy)
      (expect (gethash "reason" combo) :to-equal "input")))
  )
