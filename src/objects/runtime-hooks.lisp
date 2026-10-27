(in-package #:cl-cc/javascript/objects)

(defvar *js-object-iterator-factory* nil)

(defun %js-register-object-iterator-factory (factory)
  (setf *js-object-iterator-factory* factory))

(defun %js-object-make-iterator (get-next-fn)
  (unless *js-object-iterator-factory*
    (error "The iterator feature has not registered its object factory."))
  (funcall *js-object-iterator-factory* get-next-fn))

(defvar *js-object-proxy-operation-handler* nil)

(defun %js-register-object-proxy-operation-handler (handler)
  (setf *js-object-proxy-operation-handler* handler))

(defun %js-call-object-proxy-operation (operation &rest args)
  (unless *js-object-proxy-operation-handler*
    (error "The proxies feature has not registered its object operations."))
  (apply *js-object-proxy-operation-handler* operation args))

(defun %js-object-proxy-p (object)
  (%js-call-object-proxy-operation :proxy-p object))

(defun %js-object-proxy-key-list (keys)
  (%js-call-object-proxy-operation :key-list keys))

(defun %js-object-proxy-own-keys (proxy)
  (%js-call-object-proxy-operation :own-keys proxy))

(defun %js-object-proxy-get (proxy key &optional receiver)
  (%js-call-object-proxy-operation :get proxy key receiver))

(defun %js-object-proxy-set (proxy key value &optional receiver)
  (%js-call-object-proxy-operation :set proxy key value receiver))

(defun %js-object-proxy-delete-property (proxy key)
  (%js-call-object-proxy-operation :delete-property proxy key))

(defun %js-object-proxy-has (proxy key)
  (%js-call-object-proxy-operation :has proxy key))

(defun %js-object-proxy-get-own-property-descriptor (proxy key)
  (%js-call-object-proxy-operation :get-own-property-descriptor proxy key))

(defun %js-object-proxy-own-property-or-accessor-present-p (object key)
  (%js-call-object-proxy-operation :own-property-or-accessor-present-p object key))

(defvar *js-object-regex-clone-handler* nil)

(defun %js-register-object-regex-clone-handler (handler)
  (setf *js-object-regex-clone-handler* handler))

(defun %js-clone-regex-if-applicable (value)
  (if *js-object-regex-clone-handler*
      (funcall *js-object-regex-clone-handler* value)
      (values nil nil)))

(defvar *js-object-for-of-handler* nil)

(defun %js-register-object-for-of-handler (handler)
  (setf *js-object-for-of-handler* handler))

(defun %js-object-for-of (iterable body-fn)
  (unless *js-object-for-of-handler*
    (error "The iterators feature has not registered its for-of handler."))
  (funcall *js-object-for-of-handler* iterable body-fn))
(defvar *js-object-date-handler* nil)
(defun %js-register-object-date-handler (handler)
  (setf *js-object-date-handler* handler))
(defun %js-object-date-operation (operation value) (if *js-object-date-handler* (funcall *js-object-date-handler* operation value) (ecase operation (:date-p nil))))

(defun %js-object-group-into (iterate-fn get-bucket)
  "Shared get-or-create-then-push logic behind Array.prototype.group,
Array.prototype.groupToMap, Object.groupBy, and Map.groupBy — each walks its
own source with its own key-fn arity/coercion (a plain index loop with a
3-arg key-fn for the two Array methods vs %js-for-of with a 1- or 2-arg
key-fn for the other two) and stores buckets in its own kind of container
(hash-table vs js-map), but every one of them reduces to \"find or lazily
create this key's bucket array, then push the item into it\" — that part is
what this unifies.

ITERATE-FN is called with one argument, a two-argument VISIT continuation;
ITERATE-FN must call (funcall visit key item) once per source element, with
KEY already computed however that caller's JS method defines it. GET-BUCKET,
given a key, returns that key's bucket array — creating and storing an empty
one first if this is the key's first item."
  (funcall
    iterate-fn
    (lambda (key item)
      (vector-push-extend item (funcall get-bucket key)))))

(defvar *js-object-array-factory* nil)

(defun %js-register-object-array-factory (factory)
  (setf *js-object-array-factory* factory))

(defun %js-object-make-array (&rest elements)
  (if *js-object-array-factory*
      (apply *js-object-array-factory* elements)
      (let* ((size (length elements))
             (array (make-array size :element-type t :adjustable t :fill-pointer size)))
        (loop for element in elements
              for index from 0
              do (setf (aref array index) element))
        array)))

(defun %js-object-list-to-array (list)
  (apply #'%js-object-make-array list))
  (defvar *js-object-aggregate-error-factory* nil)
(defun %js-register-object-aggregate-error-factory (factory)
  (setf *js-object-aggregate-error-factory* factory))
(defun %js-object-make-aggregate-error (errors message)
  (unless *js-object-aggregate-error-factory*
    (error "The classes feature has not registered its AggregateError factory."))
  (funcall *js-object-aggregate-error-factory* errors message))

(defvar *js-object-error-class* nil)

(defun %js-register-object-error-class (class) (setf *js-object-error-class* class))

(defun %js-object-error-class () (unless *js-object-error-class* (error "The classes feature has not registered its root Error class.")) *js-object-error-class*)
