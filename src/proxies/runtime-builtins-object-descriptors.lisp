(in-package #:cl-cc/javascript/proxies)

(progn
  (defun %js-object-descriptor-update-compatible-p (obj key descriptor)
    (let* ((k (%js-to-property-key key))
           (getter-key (%js-object-descriptor-slot-key "__get_" key))
           (setter-key (%js-object-descriptor-slot-key "__set_" key))
           (old-descriptor
            (nth-value 0
                       (cl-cc/javascript/objects:%js-property-descriptor obj k)))
           (has-old-descriptor
            (nth-value 1
                       (cl-cc/javascript/objects:%js-property-descriptor obj k)))
           (old-property-p (%js-object-own-property-or-accessor-present-p obj k))
           (old-getter (cond
                           ((%js-ht-p obj)
                            (gethash getter-key obj +js-undefined+))
                           ((and has-old-descriptor (member :get old-descriptor))
                            (getf old-descriptor :get))
                           (t +js-undefined+)))
           (old-setter (cond
                           ((%js-ht-p obj)
                            (gethash setter-key obj +js-undefined+))
                           ((and has-old-descriptor (member :set old-descriptor))
                            (getf old-descriptor :set))
                           (t +js-undefined+)))
           (has-old-getter (or (and (%js-ht-p obj)
                                (nth-value 1 (gethash getter-key obj)))
                               (and (cl-cc/javascript/objects:%js-vm-closure-p obj)
                                    has-old-descriptor
                                    (member :get old-descriptor))))
           (has-old-setter (or (and (%js-ht-p obj)
                                (nth-value 1 (gethash setter-key obj)))
                               (and (cl-cc/javascript/objects:%js-vm-closure-p obj)
                                    has-old-descriptor
                                    (member :set old-descriptor))))
           (value (gethash "value" descriptor))
           (has-value-p (nth-value 1 (gethash "value" descriptor)))
           (writable (gethash "writable" descriptor))
           (has-writable-p (nth-value 1 (gethash "writable" descriptor)))
           (enumerable (gethash "enumerable" descriptor))
           (has-enumerable-p (nth-value 1 (gethash "enumerable" descriptor)))
           (configurable (gethash "configurable" descriptor))
           (has-configurable-p (nth-value 1 (gethash "configurable" descriptor)))
           (getter (gethash "get" descriptor))
           (has-getter-p (nth-value 1 (gethash "get" descriptor)))
           (setter (gethash "set" descriptor))
           (has-setter-p (nth-value 1 (gethash "set" descriptor)))
           (new-data-p (or has-value-p has-writable-p))
           (new-accessor-p (or has-getter-p has-setter-p))
           (old-accessor-p (or has-old-getter has-old-setter))
           (old-value
            (if has-old-descriptor
                (getf old-descriptor :value)
              (if (%js-ht-p obj)
                  (gethash k obj +js-undefined+)
                +js-undefined+)))
           (old-writable
            (if has-old-descriptor
                (getf old-descriptor :writable)
              (and old-property-p (not (%js-object-frozen-p obj)))))
           (old-enumerable
            (if has-old-descriptor
                (getf old-descriptor :enumerable)
              old-property-p))
           (old-configurable
            (if has-old-descriptor
                (getf old-descriptor :configurable)
              (and old-property-p (not (%js-object-sealed-p obj))))))
      (and (not (and new-data-p new-accessor-p))
           (or (not old-property-p)
               old-configurable
               (and (or (not has-configurable-p)
                        (not (%js-truthy configurable)))
                    (or (not has-enumerable-p)
                        (eql (%js-truthy enumerable) old-enumerable))
                    (or (not (or new-data-p new-accessor-p))
                        (eq new-accessor-p old-accessor-p))
                    (if old-accessor-p
                        (and (or (not has-getter-p)
                                 (cl-cc/javascript/objects:%js-object-is
                                  old-getter getter))
                             (or (not has-setter-p)
                                 (cl-cc/javascript/objects:%js-object-is
                                  old-setter setter)))
                      (or old-writable
                          (and (or (not has-writable-p)
                                   (not (%js-truthy writable)))
                               (or (not has-value-p)
                                   (cl-cc/javascript/objects:%js-object-is
                                    old-value value))))))))))
  (defun %js-object-apply-property-descriptor (obj key descriptor)
    (when (and (%js-object-define-property-allowed-p obj key descriptor)
               (%js-object-descriptor-update-compatible-p obj key descriptor))
      (let* ((k (%js-to-property-key key))
             (getter-key (%js-object-descriptor-slot-key "__get_" key))
             (setter-key (%js-object-descriptor-slot-key "__set_" key))
             (old-descriptor
               (nth-value 0
                          (cl-cc/javascript/objects:%js-property-descriptor
                           obj k)))
             (has-old-descriptor
               (nth-value 1
                          (cl-cc/javascript/objects:%js-property-descriptor
                           obj k)))
             (old-property-p (%js-object-own-property-or-accessor-present-p obj k))
             (old-value
               (multiple-value-bind (value found-p)
                   (if has-old-descriptor
                       (values (getf old-descriptor :value) t)
                       (if (%js-ht-p obj)
                           (gethash k obj)
                           (cl-cc/javascript/objects:%js-property-value obj k)))
                 (if found-p value +js-undefined+)))
             (value (gethash "value" descriptor))
             (has-value-p (nth-value 1 (gethash "value" descriptor)))
             (writable (gethash "writable" descriptor))
             (has-writable-p (nth-value 1 (gethash "writable" descriptor)))
             (enumerable (gethash "enumerable" descriptor))
             (has-enumerable-p (nth-value 1 (gethash "enumerable" descriptor)))
             (configurable (gethash "configurable" descriptor))
             (has-configurable-p
               (nth-value 1 (gethash "configurable" descriptor))))
        (when (and (%js-ht-p obj)
           (or has-value-p has-writable-p))
  (remhash getter-key obj)
  (remhash setter-key obj)
  (when has-value-p
    (setf (gethash k obj) value)))
        (if (cl-cc/javascript/objects:%js-vm-closure-p obj)
            (cl-cc/javascript/objects:%js-property-set-closure-descriptor
             obj k descriptor old-descriptor has-old-descriptor old-property-p)
            (cl-cc/javascript/objects:%js-set-property-descriptor
             obj k
             (list :value (if has-value-p value old-value)
                   :writable (if has-writable-p writable
                                 (if has-old-descriptor
                                     (getf old-descriptor :writable)
                                     (and old-property-p
                                          (not (%js-object-frozen-p obj)))))
                   :enumerable (if has-enumerable-p enumerable
                                   (if has-old-descriptor
                                       (getf old-descriptor :enumerable)
                                       old-property-p))
                   :configurable (if has-configurable-p configurable
                                     (if has-old-descriptor
                                         (getf old-descriptor :configurable)
                                         (and old-property-p
                                              (not (%js-object-sealed-p obj))))))))
        (multiple-value-bind (getter has-getter-p)
            (gethash "get" descriptor)
          (when (and has-getter-p (%js-ht-p obj))
            (setf (gethash getter-key obj) getter)))
        (multiple-value-bind (setter has-setter-p)
            (gethash "set" descriptor)
          (when (and has-setter-p (%js-ht-p obj))
            (setf (gethash setter-key obj) setter))))
      t)))

(defun %js-object-descriptor-slot-key (prefix key)
  (concatenate 'string prefix (%js-to-string key)))

(defun %js-object-own-property-or-accessor-present-p (obj key)
  (let* ((k (%js-to-property-key key))
         (getter-key (%js-object-descriptor-slot-key "__get_" key))
         (setter-key (%js-object-descriptor-slot-key "__set_" key)))
    (or
      (nth-value 1 (cl-cc/javascript/objects:%js-property-descriptor obj k))
      (and (%js-ht-p obj)
           (or (nth-value 1 (gethash k obj))
               (nth-value 1 (gethash getter-key obj))
               (nth-value 1 (gethash setter-key obj)))))))

(defun %js-object-define-property-allowed-p (obj key descriptor)
  (and
    (or (%js-ht-p obj)
        (cl-cc/javascript/objects:%js-vm-closure-p obj))
    (%js-ht-p descriptor)
    (or
      (%js-object-own-property-or-accessor-present-p obj key)
      (%js-object-extensible-p obj))))

(defun %js-object-data-property-descriptor (obj key value)
  (multiple-value-bind (attributes found-p)
      (cl-cc/javascript/objects:%js-property-descriptor obj key)
    (%js-make-object
     "value" value
     "writable" (and (not (%js-object-frozen-p obj))
                     (if found-p (getf attributes :writable) t))
     "enumerable" (if found-p (getf attributes :enumerable) t)
     "configurable" (and (not (%js-object-sealed-p obj))
                         (if found-p (getf attributes :configurable) t)))))

(defun %js-object-accessor-property-descriptor (obj key)
  (let* ((descriptor
        (%js-make-object "enumerable" t "configurable" (not (%js-object-sealed-p obj))))
         (getter-key (%js-object-descriptor-slot-key "__get_" key))
         (setter-key (%js-object-descriptor-slot-key "__set_" key)))
    (multiple-value-bind (getter has-getter-p) (gethash getter-key obj)
      (when has-getter-p
        (setf (gethash "get" descriptor) getter)))
    (multiple-value-bind (setter has-setter-p) (gethash setter-key obj)
      (when has-setter-p
        (setf (gethash "set" descriptor) setter)))
    descriptor))

(defun %js-reflect-define-property (target key descriptor)
  (cond
    ((%js-proxy-object-p target) (%js-proxy-define-property target key descriptor))
    (t (%js-object-apply-property-descriptor target key descriptor))))

(defun %js-reflect-get-own-property-descriptor (target key)
  (%js-object-get-own-property-descriptor target key))

(defun %js-object-define-property (obj key descriptor)
  (unless (%js-reflect-define-property obj key descriptor)
    (error "JS TypeError: Cannot define property ~A" (%js-to-string key)))
  obj)

(defun %js-object-define-properties (obj props)
  (when (and (%js-ht-p obj) (%js-ht-p props))
    (maphash
      (lambda (k v)
        (when (%js-ht-p v)
          (%js-object-define-property obj k v)))
      props))
  obj)

(defun %js-object-get-own-property-descriptor (obj key)
  (cond
    ((%js-proxy-object-p obj) (%js-proxy-get-own-property-descriptor obj key))
    ((%js-ht-p obj)
     (let ((k (%js-to-property-key key)))
       (multiple-value-bind (val found) (gethash k obj)
         (cond
           (found (%js-object-data-property-descriptor obj k val))
           ((%js-object-own-property-or-accessor-present-p obj k) (if (or (nth-value 1 (gethash (%js-object-descriptor-slot-key "__get_" k) obj)) (nth-value 1 (gethash (%js-object-descriptor-slot-key "__set_" k) obj))) (%js-object-accessor-property-descriptor obj k) (%js-object-data-property-descriptor obj k (cl-cc/javascript/objects:%js-property-value obj k))))
           (t +js-undefined+)))))
    (t
     (multiple-value-bind (attributes found-p)
         (cl-cc/javascript/objects:%js-property-descriptor obj key)
       (if found-p
           (cl-cc/javascript/objects:%js-property-descriptor-object attributes)
           +js-undefined+)))))

(defun %js-object-get-own-property-descriptors (obj)
  (let ((result (%js-make-ht)))
    (cond
      ((%js-proxy-object-p obj)
       (dolist (key (%js-proxy-key-list (%js-proxy-own-keys obj)))
         (let ((descriptor (%js-object-get-own-property-descriptor obj key)))
           (unless (eq descriptor +js-undefined+)
             (setf (gethash (%js-to-string key) result) descriptor)))))
      ((%js-ht-p obj)
       (maphash
        (lambda (key value)
          (unless (%js-internal-key-p key)
            (setf (gethash key result)
                  (%js-object-data-property-descriptor obj key value))))
        obj)
       (maphash
        (lambda (key value)
          (declare (ignore value))
          (let ((property-name (%js-object-accessor-property-name key)))
            (when (and property-name
                       (not (nth-value 1 (gethash property-name result))))
              (setf (gethash property-name result)
                    (%js-object-accessor-property-descriptor obj property-name)))))
        obj)
       (map nil
            (lambda (key)
              (unless (nth-value 1 (gethash key result))
                (let ((descriptor (%js-object-get-own-property-descriptor obj key)))
                  (unless (eq descriptor +js-undefined+)
                    (setf (gethash key result) descriptor)))))
            (cl-cc/javascript/objects:%js-property-descriptor-keys obj)))
      ((cl-cc/javascript/objects:%js-vm-closure-p obj)
       (map nil
            (lambda (key)
              (let ((descriptor (%js-object-get-own-property-descriptor obj key)))
                (unless (eq descriptor +js-undefined+)
                  (setf (gethash (%js-to-property-key key) result) descriptor))))
            (cl-cc/javascript/objects:%js-object-own-property-keys obj))))
    result))
