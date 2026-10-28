;;;; packages/javascript/src/runtime-builtins-object.lisp — JS Object/Reflect/Proxy helpers
;;;;
;;;; These helpers are referenced by runtime-builtins-table.lisp and must be
;;;; loaded before it.
(in-package #:cl-cc/javascript/proxies)

;;; -----------------------------------------------------------------------
;;;  Reflect / Object property-descriptor helpers (for runtime-builtins-table.lisp)
;;; -----------------------------------------------------------------------
(defun %js-reflect-get (target key &optional receiver)
  (if (%js-proxy-object-p target)
      (%js-proxy-get target key (or receiver target))
      (%js-get-prop target key)))

(defun %js-reflect-set (target key value &optional receiver)
  (if (%js-proxy-object-p target)
      (%js-proxy-set target key value (or receiver target))
      (progn
        (%js-set-prop target key value)
        t)))

(defun %js-reflect-has (target key)
  (%js-in key target))

(defun %js-reflect-delete-property (target key)
  (%js-delete target key))

(defun %js-reflect-apply (fn this-arg args)
  (%js-call-with-this this-arg fn (coerce args 'list)))

(defun %js-reflect-construct (target args &optional new-target)
  (declare (ignore new-target))
  (%js-new target (coerce args 'list)))

(defun %js-reflect-set-prototype-of (target proto)
  (when (%js-ht-p target)
    (let ((before (%js-object-get-prototype-of target)))
      (%js-object-set-prototype-of target proto)
      (or (eq before proto) (eq (%js-object-get-prototype-of target) proto)))))

(defun %js-reflect-prevent-extensions (target)
  (when (or (%js-ht-p target) (%js-vec-p target) (%js-vm-closure-p target))
    (%js-object-prevent-extensions target)
    t))

(defun %js-proxy-object-p (obj)
  "True when OBJ is a runtime Proxy wrapper."
  (and (%js-ht-p obj)
       (nth-value 1 (gethash "__proxy-target__" obj))
       (nth-value 1 (gethash "__proxy-handler__" obj))))

(defun %js-proxy-target (proxy)
  (gethash "__proxy-target__" proxy))

(defun %js-proxy-handler (proxy)
  (gethash "__proxy-handler__" proxy))

(defun %js-proxy-trap (proxy name)
  (let ((handler (%js-proxy-handler proxy)))
    (when (%js-ht-p handler)
      (multiple-value-bind (trap found) (gethash name handler)
        (when (and found (funcall *js-callable-p* trap))
          trap)))))

(defun %js-proxy-call-trap (proxy name &rest args)
  (let ((trap (%js-proxy-trap proxy name)))
    (if trap
        (values (apply #'%js-funcall trap args) t)
        (values +js-undefined+ nil))))

(defun %js-proxy-key-list (keys)
  (cond
    ((%js-vec-p keys) (coerce keys 'list))
    ((listp keys) keys)
    (t nil)))

(defun %js-proxy-get (proxy key &optional receiver)
  (let ((target (%js-proxy-target proxy)))
    (multiple-value-bind (result trapped)
        (%js-proxy-call-trap proxy "get" target (%js-to-string key) (or receiver proxy))
      (if trapped
          result
          (%js-get-prop target key)))))

(defun %js-proxy-set (proxy key value &optional receiver)
  (let ((target (%js-proxy-target proxy)))
    (multiple-value-bind (result trapped)
        (%js-proxy-call-trap proxy "set" target (%js-to-string key) value (or receiver proxy))
      (if trapped
          (%js-truthy result)
          (progn
            (%js-set-prop target key value)
            t)))))

(defun %js-proxy-has (proxy key)
  (let ((target (%js-proxy-target proxy)))
    (multiple-value-bind (result trapped)
        (%js-proxy-call-trap proxy "has" target (%js-to-string key))
      (if trapped
          (%js-truthy result)
          (%js-in key target)))))

(defun %js-proxy-delete-property (proxy key)
  (let ((target (%js-proxy-target proxy)))
    (multiple-value-bind (result trapped)
        (%js-proxy-call-trap proxy "deleteProperty" target (%js-to-string key))
      (if trapped
          (%js-truthy result)
          (%js-delete target key)))))

(defun %js-proxy-own-keys (proxy)
  (let ((target (%js-proxy-target proxy)))
    (multiple-value-bind (result trapped) (%js-proxy-call-trap proxy "ownKeys" target)
      (if trapped
          result
          (%js-object-own-keys target)))))

(defun %js-proxy-define-property (proxy key descriptor)
  (let ((target (%js-proxy-target proxy)))
    (multiple-value-bind (result trapped)
        (%js-proxy-call-trap proxy "defineProperty" target (%js-to-string key) descriptor)
      (if trapped
          (%js-truthy result)
          (%js-reflect-define-property target key descriptor)))))

(defun %js-proxy-get-own-property-descriptor (proxy key)
  (let ((target (%js-proxy-target proxy)))
    (multiple-value-bind (result trapped)
        (%js-proxy-call-trap proxy "getOwnPropertyDescriptor" target (%js-to-string key))
      (if trapped
          result
          (%js-object-get-own-property-descriptor target key)))))

(defun %js-make-proxy-object (target handler)
  "Proxy constructor: stores target+handler and routes common traps at runtime."
  (let ((ht (%js-make-ht)))
    (setf (gethash "__proxy-target__" ht) target
          (gethash "__proxy-handler__" ht) handler)
    ht))
