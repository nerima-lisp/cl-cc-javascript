;;;; packages/javascript/src/runtime-weak-collections.lisp
;;;; JS WeakMap, WeakSet, WeakRef, FinalizationRegistry
(in-package :cl-cc/javascript)

(defmacro define-js-weak-membership-ops (accessor &key has delete)
  "Define the HAS and DELETE operations for a weak collection whose backing
hash table is reached through ACCESSOR.

WeakMap and WeakSet are the same structure — an EQ hash table with no
insertion order to maintain — so membership and removal are character for
character the same operation on both; only the accessor differs.  (The ordered
Map and Set in runtime-map.lisp / runtime-collections-set.lisp deliberately do
NOT use this: their delete must also splice the key out of an order list, so
their bodies are genuinely different, not merely similar.)"
  `(progn
     (defun ,has (collection key)
       (nth-value 1 (gethash key (,accessor collection))))
     (defun ,delete (collection key)
       (multiple-value-bind (value present-p) (gethash key (,accessor collection))
         (declare (ignore value))
         (when present-p
           (remhash key (,accessor collection)))
         present-p))))

;;; -----------------------------------------------------------------------
;;;  WeakMap (ES2015+)
;;; -----------------------------------------------------------------------
;;;
;;; CL has no native weak references portable across implementations, so
;;; WeakMap is backed by a normal hash table using #'eq (identity equality).
;;; This gives correct JS semantics for object keys; primitive keys would be
;;; invalid per spec but we accept them silently for robustness.
(defstruct (js-weak-map (:conc-name js-weak-map-)) (ht (make-hash-table :test #'eq)))

(defun %js-weak-map-p (x)
  (js-weak-map-p x))

(defun %js-make-weak-map ()
  (make-js-weak-map))

(defun %js-weak-map-set (m key value)
  (setf (gethash key (js-weak-map-ht m)) value)
  m)

(defun %js-weak-map-get (m key)
  (multiple-value-bind (v f) (gethash key (js-weak-map-ht m))
    (if f v
      +js-undefined+)))

(define-js-map-like-get-or-insert
  %js-weak-map-get-or-insert
  %js-weak-map-get-or-insert-computed
  (m key)
  (gethash key (js-weak-map-ht m))
  (%js-weak-map-set m key v))

(define-js-weak-membership-ops
  js-weak-map-ht
  :has
  %js-weak-map-has
  :delete
  %js-weak-map-delete)

;;; -----------------------------------------------------------------------
;;;  WeakSet (ES2015+)
;;; -----------------------------------------------------------------------
(defstruct (js-weak-set (:conc-name js-weak-set-)) (ht (make-hash-table :test #'eq)))

(defun %js-weak-set-p (x)
  (js-weak-set-p x))

(defun %js-make-weak-set ()
  (make-js-weak-set))

(defun %js-weak-set-add (s value)
  (setf (gethash value (js-weak-set-ht s)) t)
  s)

(define-js-weak-membership-ops
  js-weak-set-ht
  :has
  %js-weak-set-has
  :delete
  %js-weak-set-delete)

;;; -----------------------------------------------------------------------
;;;  WeakRef (ES2021) — deterministic host-backed model
;;; -----------------------------------------------------------------------
(defstruct (js-weak-ref (:conc-name js-weak-ref-)) target)

(defun %js-make-weak-ref (target)
  "Create a WeakRef.
Portable CL does not expose ECMAScript-style weak reachability guarantees here,
so deref remains deterministic while the wrapper is alive."
  (make-js-weak-ref :target target))

(defun %js-weak-ref-deref (wr)
  (js-weak-ref-target wr))

;;; Prelude constructor values — plain function references wrapped in
;;; defparameter so seed-js-runtime-globals picks them up (boundp = t)
;;; and the compiler emits vm-get-global without an "Unbound variable" error.
(defparameter *js-weak-map-global* #'%js-make-weak-map)

(defparameter *js-weak-set-global* #'%js-make-weak-set)

;;; -----------------------------------------------------------------------
;;;  FinalizationRegistry (ES2021) — deterministic registration model
;;; -----------------------------------------------------------------------
(defstruct (js-finalization-registry (:conc-name js-finreg-)) callback
  (registrations nil))

(defstruct (js-finalization-registration (:conc-name js-finreg-entry-)) target
  held-value
  unregister-token)

(defun %js-make-finalization-registry (callback)
  (make-js-finalization-registry :callback callback))

(defun %js-finreg-register (reg target held-value &optional (unregister-token +js-undefined+))
  "Register TARGET with HELD-VALUE.
Cleanup callbacks are not run by this portable runtime, but registrations are
tracked so unregister has observable ECMAScript-compatible state."
  (push
    (make-js-finalization-registration
      :target
      target
      :held-value
      held-value
      :unregister-token
      unregister-token)
    (js-finreg-registrations reg))
  +js-undefined+)

(defun %js-finreg-unregister (reg token)
  "Remove all registrations associated with TOKEN, returning true if any existed."
  (let ((removed nil))
    (setf (js-finreg-registrations reg) (remove-if
        (lambda (entry)
          (let ((stored (js-finreg-entry-unregister-token entry)))
            (when (and (not (eq stored +js-undefined+)) (%js-same-value-zero stored token))
              (setf removed t)
              t)))
        (js-finreg-registrations reg)))
    removed))
