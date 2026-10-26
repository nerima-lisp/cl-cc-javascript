;;;; Runtime structures used by the VM's object and dispatch paths.
(in-package #:cl-cc/javascript)

;;; Hidden classes / object shapes
(defstruct object-shape
  "A shape shared by instances with the same class and ordered slot layout."
  (name nil :type symbol)
  (slot-offsets (make-hash-table :test #'equal))
  (transition-table (make-hash-table :test #'equal))
  (parent-shape nil))

(defvar *shape-registry* (make-hash-table :test #'equal)
  "Map (CLASS-NAME SLOT-NAMES) keys to their object shapes.")

(defun find-or-create-shape (class-name slot-names)
  "Find or create a shape for CLASS-NAME and the ordered SLOT-NAMES layout."
  (check-type class-name symbol)
  (check-type slot-names list)
  (let* ((stable-slot-names
           (mapcar (lambda (slot)
                     (if (stringp slot) (copy-seq slot) slot))
                   slot-names))
         (key (list class-name stable-slot-names)))
    (or (gethash key *shape-registry*)
        (let ((shape (make-object-shape :name class-name)))
          (loop for slot in stable-slot-names
                for offset from 0
                do (setf (gethash slot (object-shape-slot-offsets shape)) offset))
          (setf (gethash key *shape-registry*) shape)
          shape))))

(defun shape-slot-offset (shape slot-name)
  "Return SLOT-NAME's offset in SHAPE, or NIL when it is absent."
  (gethash slot-name (object-shape-slot-offsets shape)))

;;; Inline method dispatch tables
(defconstant +imt-size+ 64
  "Fixed number of selector buckets in an inline method table.")

(defstruct imt-entry
  "An inline method entry and its collision chain."
  (selector nil :type symbol)
  (implementation nil :type (or null function))
  (conflict-chain nil :type list))

(defstruct inline-method-table
  "Per-class inline method table with collision chains."
  (entries (make-array +imt-size+ :initial-element nil)))

(defun imt-insert (imt selector impl)
  "Insert or replace SELECTOR's implementation in IMT without losing collisions."
  (let* ((hash (mod (sxhash selector) +imt-size+))
         (entry (aref (inline-method-table-entries imt) hash)))
    (cond
      ((null entry)
       (setf (aref (inline-method-table-entries imt) hash)
             (make-imt-entry :selector selector :implementation impl)))
      ((eq (imt-entry-selector entry) selector)
       (setf (aref (inline-method-table-entries imt) hash)
             (make-imt-entry
              :selector selector
              :implementation impl
              :conflict-chain (imt-entry-conflict-chain entry))))
      (t
       (let ((conflict (find selector (imt-entry-conflict-chain entry)
                             :test #'eq :key #'imt-entry-selector)))
         (if conflict
             (progn
               (setf (imt-entry-implementation conflict) impl)
               (imt-entry-conflict-chain entry))
             (push (make-imt-entry :selector selector :implementation impl)
                   (imt-entry-conflict-chain entry))))))))

(defun imt-lookup (imt selector)
  "Return SELECTOR's implementation from IMT, or NIL when it is absent."
  (let* ((hash (mod (sxhash selector) +imt-size+))
         (entry (aref (inline-method-table-entries imt) hash)))
    (cond
      ((null entry) nil)
      ((eq (imt-entry-selector entry) selector)
       (imt-entry-implementation entry))
      (t
       (let ((found (find selector (imt-entry-conflict-chain entry)
                          :test #'eq :key #'imt-entry-selector)))
         (when found
           (imt-entry-implementation found)))))))

;;; Object mark word
(defconstant +mark-word-gc-color-bits+ 2)
(defconstant +mark-word-kind-bits+ 2)
(defconstant +mark-word-hash-bits+ 28)

(defun make-mark-word (&key (gc-color 0) (object-kind 0)
                            (identity-hash 0) (lock-state 0))
  "Create a 64-bit mark word after validating each field's bit width."
  (check-type gc-color (unsigned-byte 2))
  (check-type object-kind (unsigned-byte 2))
  (check-type identity-hash (unsigned-byte 28))
  (check-type lock-state (unsigned-byte 32))
  (logior gc-color
          (ash object-kind +mark-word-gc-color-bits+)
          (ash identity-hash (+ +mark-word-gc-color-bits+ +mark-word-kind-bits+))
          (ash lock-state (+ +mark-word-gc-color-bits+ +mark-word-kind-bits+
                             +mark-word-hash-bits+))))

(defun mark-word-gc-color (mw)
  "Extract the two GC color bits from mark word MW."
  (logand mw (1- (ash 1 +mark-word-gc-color-bits+))))

;;; Value types / inline structs
(defstruct value-type-def
  "Definition of an inline value type stored in stack or register slots."
  (name nil :type symbol)
  (fields nil :type list)
  (total-size 0 :type fixnum))

(defvar *value-types* (make-hash-table :test #'eq)
  "Registered value type definitions.")

(defmacro defvalue-type (name &rest fields)
  "Register NAME with FIELDS as an inline composite value type."
  `(progn
     (setf (gethash ',name *value-types*)
           (make-value-type-def :name ',name :fields ',fields
                                :total-size ,(length fields)))
     ',name))

(export '(object-shape make-object-shape *shape-registry*
          find-or-create-shape shape-slot-offset
          +imt-size+ imt-entry make-imt-entry
          inline-method-table make-inline-method-table imt-insert imt-lookup
          make-mark-word mark-word-gc-color
          defvalue-type value-type-def *value-types*))
