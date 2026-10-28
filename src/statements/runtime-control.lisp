;;;; packages/javascript/src/runtime-control.lisp — JS control-flow & iteration
;;;;
;;;; Statement control-flow helpers extracted from runtime.lisp.
;;;; Includes try/catch/finally and for-in lowering.
;;;; Load order: directly after runtime.lisp.
(in-package #:cl-cc/javascript/statements)

(defun %js-try-catch-finally (try-thunk catch-thunk finally-thunk)
  "Execute TRY-THUNK; on JS exception call CATCH-THUNK with the value.
   FINALLY-THUNK is always called. Returns value of try or catch.
   The thunks are compiled-JS lambdas (vm-closure-objects), so they must be
   invoked through %js-funcall (-> *js-apply-fn* -> %vm-call-closure-sync), not a
   raw CL:FUNCALL which cannot call a vm-closure."
  (let ((result +js-undefined+))
    (unwind-protect
        (handler-case (setf result (%js-object-funcall try-thunk))
          (js-exception (c)
            (when catch-thunk
              (setf result (%js-object-funcall catch-thunk (js-exception-value c))))))
      (when finally-thunk
        (%js-object-funcall finally-thunk)))
    result))

;;; -----------------------------------------------------------------------
;;;  Iteration protocol
;;; -----------------------------------------------------------------------
(defun %js-for-in (obj body-fn)
  "Execute BODY-FN for each enumerable string key in OBJ, in the same order
Object.keys/values/entries use: array-index keys numerically ascending
first, per ES2015+ [[OwnPropertyKeys]] (see %JS-OBJECT-OWN-STRING-PROPERTY-
KEYS, which this shares instead of its own unordered maphash). An
accessor (getter/setter) property enumerates under its real property name
(a `get foo(){}' in an object literal is enumerable by default, same as a
plain data property) -- internal runtime keys (__proto__, __class__, the
__get_X/__set_X storage keys themselves) are still excluded."
  (when (%js-ht-p obj)
    (loop for k across (%js-object-own-string-property-keys obj t)
          do (%js-object-funcall body-fn k)))
  +js-undefined+)

(defun %js-iter-keys (obj)
  "Collect OBJ's enumerable string keys into a fresh CL list — the 1-arg
companion to %js-for-in, used by the for-in loop lowering (see %js-iter-values)."
  (let ((acc nil))
    (%js-for-in obj
                (lambda (k)
                  (push k acc)))
    (nreverse acc)))
