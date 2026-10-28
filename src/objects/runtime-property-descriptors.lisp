(in-package #:cl-cc/javascript/objects)

(defvar *js-own-property-descriptors*
  (make-hash-table :test #'eq))
(defvar *js-own-property-descriptor-order* (make-hash-table :test (function eq)))

(defvar *js-object-integrity-flags* (make-hash-table :test (function eq)))

(defun %js-property-descriptor-table (object)
  (or (gethash object *js-own-property-descriptors*)
      (setf (gethash object *js-own-property-descriptors*) (make-hash-table
                                                            :test
                                                            #'equal))))

(defun %js-property-descriptor (object key)
  (let ((table (gethash object *js-own-property-descriptors*)))
    (if table
        (gethash (%js-to-property-key key) table)
        (values nil nil))))

(defun %js-set-property-descriptor (object key descriptor)
  (let* ((normalized-key (%js-to-property-key key))
         (table (%js-property-descriptor-table object))
         (order (gethash object *js-own-property-descriptor-order*)))
    (unless (nth-value 1 (gethash normalized-key table))
      (setf (gethash object *js-own-property-descriptor-order*)
            (append order (list normalized-key))))
    (setf (gethash normalized-key table) descriptor)))

(defun %js-remove-property-descriptor (object key)
  (let* ((table (gethash object *js-own-property-descriptors*))
         (normalized-key (%js-to-property-key key)))
    (when table
      (remhash normalized-key table))
    (setf (gethash object *js-own-property-descriptor-order*)
          (remove normalized-key
                  (gethash object *js-own-property-descriptor-order*)
                  :test (function equal)))))

(defun %js-property-value (object key)
  (multiple-value-bind (descriptor found-p) (%js-property-descriptor object key)
    (if found-p
        (values (getf descriptor :value) t)
        (values nil nil))))

(defun %js-property-writable-p (object key)
  (multiple-value-bind (descriptor found-p) (%js-property-descriptor object key)
    (if found-p (getf descriptor :writable) (not (%js-object-frozen-p object)))))

(defun %js-property-configurable-p (object key)
  (multiple-value-bind (descriptor found-p) (%js-property-descriptor object key)
    (if found-p (getf descriptor :configurable) (not (%js-object-sealed-p object)))))

(defun %js-update-property-value (object key value)
  (multiple-value-bind (descriptor found-p) (%js-property-descriptor object key)
    (when found-p
      (setf (getf descriptor :value) value)
      (%js-set-property-descriptor object key descriptor))))

(defun %js-seal-property-descriptors (object freeze-p)
  (let ((table (gethash object *js-own-property-descriptors*)))
    (when table
      (maphash
       (lambda (key descriptor)
         (declare (ignore key))
         (setf (getf descriptor :configurable) nil)
         (when freeze-p
           (setf (getf descriptor :writable) nil)))
       table)))
  object)
(defun %js-property-descriptor-keys (object)
  (copy-list (gethash object *js-own-property-descriptor-order*)))
(defun %js-property-enumerable-p (object key) (multiple-value-bind (descriptor found-p) (%js-property-descriptor object key) (if found-p (getf descriptor :enumerable) t)))

(defun %js-object-integrity-flag (object key default) (let ((flags (gethash object *js-object-integrity-flags*))) (if flags (gethash key flags default) default)))

(defun %js-set-object-integrity-flag (object key value)
  (let ((flags
         (or (gethash object *js-object-integrity-flags*)
             (setf (gethash object *js-object-integrity-flags*)
                   (make-hash-table :test (function equal))))))
    (setf (gethash key flags) value)))
(progn
  (defun %js-property-accessor-descriptor-p (descriptor)
    (or (member :get descriptor) (member :set descriptor)))
  (defun %js-property-get-value (object key)
    (multiple-value-bind (descriptor found-p) (%js-property-descriptor object key)
      (if (not found-p)
          (values nil nil)
          (if (%js-property-accessor-descriptor-p descriptor)
              (let ((getter (getf descriptor :get +js-undefined+)))
                (values (if (eq getter +js-undefined+)
                            +js-undefined+
                            (%js-object-call-with-this object getter nil))
                        t))
              (values (getf descriptor :value) t)))))
  (defun %js-property-set-value (object key value)
    (multiple-value-bind (descriptor present-p) (%js-property-descriptor object key)
      (cond
        ((and present-p (%js-property-accessor-descriptor-p descriptor))
         (let ((setter (getf descriptor :set +js-undefined+)))
           (unless (eq setter +js-undefined+)
             (%js-object-call-with-this object setter (list value)))))
        ((%js-property-writable-p object key)
         (if present-p
             (%js-update-property-value object key value)
             (when (and (%js-vm-closure-p object) (%js-object-extensible-p object))
               (%js-set-property-descriptor object key
                                            (list :value value :writable t
                                                  :enumerable t :configurable t)))))))
    value)
  (defun %js-property-descriptor-attribute (descriptor key supplied-p value
                                             old-descriptor old-found-p default)
    (if supplied-p value
        (if old-found-p (getf old-descriptor key default) default)))
  (defun %js-property-set-closure-descriptor (object key descriptor old-descriptor
                                               old-found-p old-property-p)
    (let* ((old-accessor-p (and old-found-p
                                (%js-property-accessor-descriptor-p old-descriptor)))
           (value (gethash "value" descriptor))
           (has-value-p (nth-value 1 (gethash "value" descriptor)))
           (writable (gethash "writable" descriptor))
           (has-writable-p (nth-value 1 (gethash "writable" descriptor)))
           (getter (gethash "get" descriptor))
           (has-getter-p (nth-value 1 (gethash "get" descriptor)))
           (setter (gethash "set" descriptor))
           (has-setter-p (nth-value 1 (gethash "set" descriptor)))
           (enumerable (gethash "enumerable" descriptor))
           (has-enumerable-p (nth-value 1 (gethash "enumerable" descriptor)))
           (configurable (gethash "configurable" descriptor))
           (has-configurable-p (nth-value 1 (gethash "configurable" descriptor)))
           (accessor-p
             (or has-getter-p has-setter-p
                 (and old-accessor-p
                      (not (or has-value-p has-writable-p)))))
           (attributes
             (list :enumerable
                   (%js-property-descriptor-attribute
                    descriptor :enumerable has-enumerable-p enumerable old-descriptor
                    old-found-p old-property-p)
                   :configurable
                   (%js-property-descriptor-attribute
                    descriptor :configurable has-configurable-p configurable old-descriptor
                    old-found-p
                    (and old-property-p (not (%js-object-sealed-p object)))))))
      (%js-set-property-descriptor
       object key
       (if accessor-p
           (append (list :get (if has-getter-p getter
                                  (if old-accessor-p
                                      (getf old-descriptor :get +js-undefined+)
                                      +js-undefined+))
                         :set (if has-setter-p setter
                                  (if old-accessor-p
                                      (getf old-descriptor :set +js-undefined+)
                                      +js-undefined+)))
                   attributes)
           (append (list :value (if has-value-p value
                                   (if old-found-p
                                       (getf old-descriptor :value +js-undefined+)
                                       +js-undefined+))
                         :writable
                         (%js-property-descriptor-attribute
                          descriptor :writable has-writable-p writable old-descriptor
                          old-found-p
                          (and old-property-p
                               (not (%js-object-frozen-p object)))))
                   attributes)))))
  (defun %js-property-descriptor-object (descriptor)
    (if (%js-property-accessor-descriptor-p descriptor)
        (%js-make-object "get" (getf descriptor :get +js-undefined+)
                         "set" (getf descriptor :set +js-undefined+)
                         "enumerable" (getf descriptor :enumerable)
                         "configurable" (getf descriptor :configurable))
        (%js-make-object "value" (getf descriptor :value +js-undefined+)
                         "writable" (getf descriptor :writable)
                         "enumerable" (getf descriptor :enumerable)
                         "configurable" (getf descriptor :configurable)))))
