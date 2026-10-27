(in-package #:cl-cc/javascript/iterators)

(defun %js-iter-values (iterable)
  "Collect ITERABLE's values into a fresh CL list, in order. This is the 1-arg
companion to the 2-arg %js-for-of (which calls a body-fn): the for-of loop
LOWERING walks the resulting list with car/cdr so that break/continue and the
loop body's own scope work as ordinary statements. Reuses %js-for-of so every
iterable kind (array, string, iterator-protocol object) is handled in one place."
  (let ((acc nil))
    (%js-for-of iterable (lambda (el) (push el acc)))
    (nreverse acc)))

(defun %js-for-of (iterable body-fn)
  "Execute BODY-FN for each element of ITERABLE."
  (cond
    ((%js-vec-p iterable)
     (loop for i below (length iterable)
           do (%js-object-funcall body-fn (aref iterable i))))
    ((stringp iterable)
     (loop for ch across iterable
           do (%js-object-funcall body-fn (string ch))))
    ((%js-map-p iterable)
     (%js-advance-iterator (%js-map-entries iterable) body-fn))
    ((js-set-p iterable)
     (dolist (value (%js-set-keys iterable))
       (%js-object-funcall body-fn value)))
    ((functionp iterable)
     (%js-advance-cl-iterator iterable body-fn))
    ((%js-ht-p iterable)
     (let ((next-fn (gethash "next" iterable))
           (iter-fn (gethash "@@iterator" iterable)))
       (cond
         (next-fn
          (%js-advance-iterator iterable body-fn))
         (iter-fn
          (%js-for-of (%js-object-funcall iter-fn) body-fn))
         (t
          (maphash (lambda (key value)
                     (declare (ignore value))
                     (unless (and (stringp key) (%js-internal-key-p key))
                       (%js-object-funcall body-fn key)))
                   iterable)))))
    (t nil))
  +js-undefined+)

(defun %js-advance-cl-iterator (iter body-fn)
  "Drain a CL-iterator (closure returning (:value v :done p) or :done)."
  (loop
    (multiple-value-bind (val done) (%js-iter-next iter)
      (when done (return))
      (%js-object-funcall body-fn val))))

(defun %js-advance-iterator (iter body-fn)
  "Drain a JS iterator object (with a \"next\" method), calling BODY-FN per value."
  (let ((next-fn (gethash "next" iter)))
    (when next-fn
      (loop
        (let ((result (%js-object-funcall next-fn)))
          (when (or (not (%js-ht-p result))
                    (%js-truthy (gethash "done" result)))
            (return))
          (%js-object-funcall body-fn (gethash "value" result)))))))
