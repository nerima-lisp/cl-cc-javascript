;;;; packages/javascript/src/runtime-promise.lisp — JS Promise
;;;;
;;;; Simplified synchronous model: a promise is always already settled by the
;;;; time it's observable from JS, so .then/.catch/.finally run their handler
;;;; immediately instead of queuing a microtask.

(in-package :cl-cc/javascript)

(defstruct (js-promise (:conc-name js-promise-))
  value
  settled-p
  rejected-p)

(defun %js-promise-resolve (value)
  "Create a resolved promise. A promise argument is returned as-is, adopting
its state (per Promise.resolve semantics) — so a handler that returns a
rejected promise propagates the rejection through the chain."
  (if (js-promise-p value)
      value
      (make-js-promise :value value :settled-p t :rejected-p nil)))

(defun %js-promise-reject (reason)
  "Create a rejected promise."
  (make-js-promise :value reason :settled-p t :rejected-p t))

(defun %js-await (promise)
  "Synchronously unwrap a promise (for simplified async model)."
  (cond
    ((js-promise-p promise)
     (if (js-promise-rejected-p promise)
         (%js-throw (js-promise-value promise))
         (js-promise-value promise)))
    (t promise)))

(defun %js-for-await-of (iterable body-fn)
  "Synchronous for-await-of: resolves each element through %js-await eagerly."
  (%js-for-of iterable (lambda (item)
                         (%js-funcall body-fn (%js-await item)))))

(defun %js-async (thunk)
  "Execute THUNK, wrapping result/exception in a promise.
THUNK is a VM closure so use %js-funcall (not CL:FUNCALL) to re-enter the VM."
  (handler-case
      (%js-promise-resolve (%js-funcall thunk))
    (js-exception (c)
      (%js-promise-reject (js-exception-value c)))))

;;; Call HANDLER with VALUE; propagate JS exceptions as a rejected promise.
(defun %js-promise-apply-handler (value handler)
  (handler-case
      (%js-promise-resolve (%js-funcall handler value))
    (js-exception (c) (%js-promise-reject (js-exception-value c)))))

(defun %js-promise-then (promise on-fulfilled &optional on-rejected)
  "Chain a promise through on-fulfilled / on-rejected callbacks."
  (if (js-promise-rejected-p promise)
      (if on-rejected
          (%js-promise-apply-handler (js-promise-value promise) on-rejected)
          promise)
      (if on-fulfilled
          (%js-promise-apply-handler (js-promise-value promise) on-fulfilled)
          promise)))

(defun %js-promise-finally (promise on-finally)
  "Run ON-FINALLY regardless of outcome."
  (%js-funcall on-finally)
  promise)

;;; Shared helpers for Promise aggregator functions.

(defun %js-promises-as-vec (promises)
  "Ensure PROMISES is a JS vector (convert from iterator/array-like if needed)."
  (if (%js-vec-p promises) promises (%js-array-from promises)))

(defmacro %with-promise-vec ((var promises) &body body)
  "Bind VAR to (%js-promises-as-vec PROMISES) and run BODY."
  `(let ((,var (%js-promises-as-vec ,promises)))
     ,@body))

(defun %js-promise-unwrap (p)
  "Unwrap P's value whether P is a promise struct or a plain value."
  (if (js-promise-p p) (js-promise-value p) p))

(defun %js-promise-settled-outcome (p)
  "Build a {status, value/reason} object for Promise.allSettled."
  (if (and (js-promise-p p) (js-promise-rejected-p p))
      (%js-make-object "status" "rejected"  "reason" (js-promise-value p))
      (%js-make-object "status" "fulfilled" "value"  (%js-promise-unwrap p))))

(defun %js-promise-all (promises)
  "Resolve all promises; reject on first rejection."
  (%with-promise-vec (arr promises)
    (let ((results (make-array 0 :element-type t :adjustable t :fill-pointer 0)))
      (loop for p across arr
            do (vector-push-extend (%js-await p) results))
      (%js-promise-resolve results))))

(defun %js-promise-all-settled (promises)
  "Return array of status objects for all promises."
  (%with-promise-vec (arr promises)
    (let ((results (make-array 0 :element-type t :adjustable t :fill-pointer 0)))
      (loop for p across arr
            do (vector-push-extend (%js-promise-settled-outcome p) results))
      (%js-promise-resolve results))))

(defun %js-promise-any (promises)
  "Resolve with first fulfillment; reject with a real AggregateError if all
reject (previously a plain object with matching `errors'/`message'
properties but no AggregateError identity at all — `instanceof
AggregateError` and `instanceof Error` both failed; %js-make-aggregate-error
already existed, tested in isolation, just never called from here)."
  (%with-promise-vec (arr promises)
    (let ((errors (make-array 0 :element-type t :adjustable t :fill-pointer 0)))
      (loop for p across arr
            do (if (and (js-promise-p p) (js-promise-rejected-p p))
                   (vector-push-extend (js-promise-value p) errors)
                   (return-from %js-promise-any (%js-promise-resolve (%js-promise-unwrap p)))))
      (%js-promise-reject
       (%js-make-aggregate-error errors "All promises were rejected")))))

(defun %js-promise-race (promises)
  "Return the first settled promise."
  (let ((arr (%js-promises-as-vec promises)))
    (if (zerop (length arr))
        (make-js-promise :settled-p nil :rejected-p nil :value +js-undefined+)
        (aref arr 0))))

(defun %js-promise-with-resolvers ()
  "Return object with promise, resolve, reject."
  (let* ((p (make-js-promise :settled-p nil :rejected-p nil :value +js-undefined+))
         (resolve (lambda (v)
                    (setf (js-promise-value p) v
                          (js-promise-settled-p p) t
                          (js-promise-rejected-p p) nil)))
         (reject (lambda (r)
                   (setf (js-promise-value p) r
                         (js-promise-settled-p p) t
                         (js-promise-rejected-p p) t))))
    (%js-make-object "promise" p "resolve" resolve "reject" reject)))
