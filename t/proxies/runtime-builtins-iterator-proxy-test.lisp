;;;; t/runtime-builtins-iterator-proxy-test.lisp
;;;;
;;;; Split from runtime-builtins-test.lisp: Iterator.from, Map.groupBy,
;;;; Set-from-iterable, Proxy traps, Math.sumPrecise, and Error.isError /
;;;; AggregateError.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list)

(in-package #:cl-cc/javascript/proxies/test)

;;; ─── Iterator.from ───────────────────────────────────────────────────────────

(defun %register-proxies-runtime-builtins-iterator-proxy-tests ()
  (it-sequential "js-rt-make-proxy-object"
    (let* ((target  (cl-cc/javascript::%js-make-object "x" 1))
           (handler (cl-cc/javascript::%js-make-object))
           (proxy   (cl-cc/javascript/proxies:%js-make-proxy-object target handler)))
      (expect (gethash "__proxy-target__"  proxy) :to-be target)
      (expect (gethash "__proxy-handler__" proxy) :to-be handler)
      (expect (cl-cc/javascript/proxies:%js-proxy-object-p proxy) :to-be-truthy)))
  (it-sequential "js-rt-proxy-property-traps"
    (let* ((target (cl-cc/javascript::%js-make-object "x" 1))
           (deleted nil)
           (handler
             (cl-cc/javascript::%js-make-object
               "get" (lambda (target key receiver)
                       (declare (ignore receiver))
                       (concatenate 'string "trap-" key "-"
                                    (cl-cc/javascript::%js-to-string
                                      (gethash key target cl-cc/javascript/objects:+js-undefined+))))
               "set" (lambda (target key value receiver)
                       (declare (ignore receiver))
                       (setf (gethash key target) value)
                       t)
               "has" (lambda (target key)
                       (declare (ignore target))
                       (string= key "visible"))
               "deleteProperty" (lambda (target key)
                                  (setf deleted key)
                                  (remhash key target)
                                  t)))
           (proxy (cl-cc/javascript/proxies:%js-make-proxy-object target handler)))
      (expect (cl-cc/javascript::%js-get-prop proxy "x") :to-equal "trap-x-1")
      (expect (= 7 (cl-cc/javascript::%js-set-prop proxy "y" 7)) :to-be-truthy)
      (expect (= 7 (gethash "y" target)) :to-be-truthy)
      (expect (cl-cc/javascript::%js-in "visible" proxy) :to-be-truthy)
      (expect (cl-cc/javascript::%js-in "x" proxy) :to-be-falsy)
      (expect (cl-cc/javascript::%js-delete proxy "x") :to-be-truthy)
      (expect deleted :to-equal "x")
      (expect (nth-value 1 (gethash "x" target)) :to-be-falsy)))
  (it-sequential "js-rt-proxy-falls-back-without-traps"
    (let* ((target (cl-cc/javascript::%js-make-object "x" 1))
           (proxy (cl-cc/javascript/proxies:%js-make-proxy-object
                   target (cl-cc/javascript::%js-make-object))))
      (multiple-value-bind (value trapped)
          (cl-cc/javascript/proxies:%js-proxy-call-trap proxy "get" target "x" proxy)
        (expect value :to-be-js-undefined)
        (expect trapped :to-be-falsy))
      (expect (= 1 (cl-cc/javascript::%js-get-prop proxy "x")) :to-be-truthy)
      (expect (= 2 (cl-cc/javascript::%js-set-prop proxy "y" 2)) :to-be-truthy)
      (expect (= 2 (gethash "y" target)) :to-be-truthy)
      (expect (cl-cc/javascript::%js-in "x" proxy) :to-be-truthy)
      (expect (cl-cc/javascript::%js-delete proxy "x") :to-be-truthy)
      (expect (nth-value 1 (gethash "x" target)) :to-be-falsy)))
  (it-sequential "js-rt-proxy-reflect-and-object-traps"
    (let* ((target (cl-cc/javascript::%js-make-object "a" 1))
           (handler
             (cl-cc/javascript::%js-make-object
               "get" (lambda (target key receiver)
                       (declare (ignore target receiver))
                       (if (string= key "b") 20 cl-cc/javascript/objects:+js-undefined+))
               "set" (lambda (target key value receiver)
                       (declare (ignore receiver))
                       (setf (gethash key target) value)
                       t)
               "ownKeys" (lambda (target)
                           (declare (ignore target))
                           (%jr-arr "b" "c"))
               "getOwnPropertyDescriptor"
               (lambda (target key)
                 (declare (ignore target))
                 (if (or (string= key "b") (string= key "c"))
                     (cl-cc/javascript::%js-make-object
                       "value" key "writable" t "enumerable" t "configurable" t)
                     cl-cc/javascript/objects:+js-undefined+))
               "defineProperty"
               (lambda (target key descriptor)
                 (setf (gethash key target) (gethash "value" descriptor))
                 t)))
           (proxy (cl-cc/javascript/proxies:%js-make-proxy-object target handler)))
      (expect (= 20 (cl-cc/javascript/proxies:%js-reflect-get proxy "b")) :to-be-truthy)
      (expect (cl-cc/javascript/proxies:%js-reflect-set proxy "z" 99) :to-be-truthy)
      (expect (= 99 (gethash "z" target)) :to-be-truthy)
      (expect (cl-cc/javascript/proxies:%js-reflect-define-property
          proxy "d" (cl-cc/javascript::%js-make-object "value" 44)) :to-be-truthy)
      (expect (= 44 (gethash "d" target)) :to-be-truthy)
      (let ((keys (cl-cc/javascript::%js-object-keys proxy)))
        (expect (= 2 (length keys)) :to-be-truthy)
        (expect (aref keys 0) :to-equal "b")
        (expect (aref keys 1) :to-equal "c"))
      (let ((desc (cl-cc/javascript::%js-object-get-own-property-descriptor proxy "b")))
        (expect (gethash "value" desc) :to-equal "b"))
      (let ((desc (cl-cc/javascript::%js-object-get-own-property-descriptor proxy "c")))
        (expect (gethash "value" desc) :to-equal "c"))))
  )

;;; ─── Map.groupBy ─────────────────────────────────────────────────────────────

;;; ─── Set-from-iterable ───────────────────────────────────────────────────────

;;; ─── Proxy ───────────────────────────────────────────────────────────────────

;;; ─── Math.sumPrecise (ES2026) ────────────────────────────────────────────────

;;; ─── Error.isError (ES2026) ──────────────────────────────────────────────────

;;; ─── AggregateError ──────────────────────────────────────────────────────────

(defun %register-proxies-runtime-object-property-tests ()
  (it-sequential "js-rt-object-define-properties"
      (let* ((obj   (cl-cc/javascript::%js-make-object))
             (descs (cl-cc/javascript::%js-make-object
                     "a" (cl-cc/javascript::%js-make-object "value" 1)
                     "b" (cl-cc/javascript::%js-make-object "value" 2))))
        (cl-cc/javascript::%js-object-define-properties obj descs)
        (expect (= 1 (gethash "a" obj)) :to-be-truthy)
        (expect (= 2 (gethash "b" obj)) :to-be-truthy)))
  (it-sequential "js-rt-object-define-properties-ignores-non-objects"
      (let* ((obj (cl-cc/javascript::%js-make-object "keep" 1))
             (mixed (cl-cc/javascript::%js-make-object
                     "ok" (cl-cc/javascript::%js-make-object "value" 2)
                     "skip" 9)))
        (cl-cc/javascript::%js-object-define-properties obj (vector "bad"))
        (cl-cc/javascript::%js-object-define-properties obj mixed)
        (expect (= 1 (gethash "keep" obj)) :to-be-truthy)
        (expect (= 2 (gethash "ok" obj)) :to-be-truthy)
        (expect (nth-value 1 (gethash "skip" obj)) :to-be-falsy)))
  (it-sequential "js-rt-reflect-define-property"
      (let* ((obj  (cl-cc/javascript::%js-make-object))
             (desc (cl-cc/javascript::%js-make-object "value" 42))
             (ret  (cl-cc/javascript/proxies:%js-reflect-define-property obj "x" desc)))
        (expect ret :to-be-truthy)
        (expect (= 42 (gethash "x" obj)) :to-be-truthy)))
  (it-sequential "js-rt-object-define-property-value"
      (let* ((obj  (cl-cc/javascript::%js-make-object))
             (desc (cl-cc/javascript::%js-make-object "value" 99)))
        (let ((ret (cl-cc/javascript::%js-object-define-property obj "n" desc)))
          (expect ret :to-be obj)
          (expect (= 99 (gethash "n" obj)) :to-be-truthy))))
  (it-sequential "js-rt-object-define-property-getter"
      (let* ((obj  (cl-cc/javascript::%js-make-object))
             (getter (lambda () 7))
             (desc (cl-cc/javascript::%js-make-object "get" getter)))
        (cl-cc/javascript::%js-object-define-property obj "prop" desc)
        (expect (gethash "__get_prop" obj) :to-be getter)))
  (it-sequential "js-rt-object-get-own-property-descriptor-accessor"
      (let* ((obj (cl-cc/javascript::%js-make-object))
             (getter (lambda () 7))
             (setter (lambda (value) value))
             (desc (cl-cc/javascript::%js-make-object "get" getter "set" setter)))
        (cl-cc/javascript::%js-object-define-property obj "prop" desc)
        (let ((actual (cl-cc/javascript::%js-object-get-own-property-descriptor obj "prop")))
          (expect (gethash "get" actual) :to-be getter)
          (expect (gethash "set" actual) :to-be setter)
          (expect (gethash "enumerable" actual) :to-be-truthy)
          (expect (gethash "configurable" actual) :to-be-truthy)
          (expect (nth-value 1 (gethash "value" actual)) :to-be-falsy))))
  (it-sequential "js-rt-object-get-own-property-descriptors-includes-accessor-property"
      (let* ((obj (cl-cc/javascript::%js-make-object))
             (getter (lambda () 10))
             (desc (cl-cc/javascript::%js-make-object "get" getter)))
        (cl-cc/javascript::%js-object-define-property obj "computed" desc)
        (let* ((descs (cl-cc/javascript/proxies:%js-object-get-own-property-descriptors obj))
               (actual (gethash "computed" descs)))
          (expect (gethash "get" actual) :to-be getter)
          (expect (nth-value 1 (gethash "__get_computed" descs)) :to-be-falsy))))
  (it-sequential "js-rt-object-get-own-property-descriptor-reflects-object-flags"
      (let* ((sealed (cl-cc/javascript::%js-make-object "a" 1))
             (frozen (cl-cc/javascript::%js-make-object "b" 2)))
        (cl-cc/javascript/objects:%js-object-seal sealed)
        (cl-cc/javascript/objects:%js-object-freeze frozen)
        (let ((sealed-desc (cl-cc/javascript::%js-object-get-own-property-descriptor sealed "a"))
              (frozen-desc (cl-cc/javascript::%js-object-get-own-property-descriptor frozen "b")))
          (expect (gethash "configurable" sealed-desc) :to-be-falsy)
          (expect (gethash "writable" sealed-desc) :to-be-truthy)
          (expect (gethash "configurable" frozen-desc) :to-be-falsy)
          (expect (gethash "writable" frozen-desc) :to-be-falsy))))
  (it-sequential "js-rt-reflect-define-property-respects-prevent-extensions"
      (let* ((obj (cl-cc/javascript::%js-make-object))
             (desc (cl-cc/javascript::%js-make-object "value" 10)))
        (cl-cc/javascript/objects:%js-object-prevent-extensions obj)
        (expect (cl-cc/javascript/proxies:%js-reflect-define-property obj "blocked" desc) :to-be-falsy)
        (expect (nth-value 1 (gethash "blocked" obj)) :to-be-falsy)))
  (it-sequential "js-rt-object-define-property-signals-on-prevent-extensions"
      (let* ((obj (cl-cc/javascript::%js-make-object))
             (desc (cl-cc/javascript::%js-make-object "value" 10)))
        (cl-cc/javascript/objects:%js-object-prevent-extensions obj)
        (signals error (cl-cc/javascript::%js-object-define-property obj "blocked" desc))
        (expect (nth-value 1 (gethash "blocked" obj)) :to-be-falsy)))
  (it-sequential "js-rt-reflect-define-property-rejects-frozen-redefine"
      (let* ((obj (cl-cc/javascript::%js-make-object "locked" 1))
             (desc (cl-cc/javascript::%js-make-object "value" 2)))
        (cl-cc/javascript/objects:%js-object-freeze obj)
        (expect (cl-cc/javascript/proxies:%js-reflect-define-property obj "locked" desc) :to-be-falsy)
        (expect (= 1 (gethash "locked" obj)) :to-be-truthy)))
  (it-sequential "js-rt-object-define-property-rejects-frozen-redefine"
      (let* ((obj (cl-cc/javascript::%js-make-object "locked" 1))
             (desc (cl-cc/javascript::%js-make-object "value" 2)))
        (cl-cc/javascript/objects:%js-object-freeze obj)
        (signals error (cl-cc/javascript::%js-object-define-property obj "locked" desc))
        (expect (= 1 (gethash "locked" obj)) :to-be-truthy)))
  (it-sequential "js-rt-object-has-own-accessor-property"
    (let* ((obj (cl-cc/javascript/objects:%js-make-object))
           (getter (lambda () 42))
           (desc (cl-cc/javascript/objects:%js-make-object "get" getter)))
      (cl-cc/javascript/proxies:%js-object-define-property obj "answer" desc)
      (expect (cl-cc/javascript/objects:%js-object-has-own obj "answer") :to-be-truthy)))
  (it-sequential "js-rt-object-own-keys-includes-accessor-property-name"
    (let* ((obj (cl-cc/javascript/objects:%js-make-object "data" 1))
           (getter (lambda () 7))
           (desc (cl-cc/javascript/objects:%js-make-object "get" getter)))
      (cl-cc/javascript/proxies:%js-object-define-property obj "computed" desc)
      (let ((keys (sort (coerce (cl-cc/javascript/objects:%js-object-own-keys obj) 'list) #'string<)))
        (expect keys :to-equal '("computed" "data"))
        (expect (member "__get_computed" keys :test #'string=) :to-be-falsy))))
  (it-sequential "js-rt-object-values-reads-accessor"
    (let* ((obj (cl-cc/javascript/objects:%js-make-object))
           (getter (lambda () 123))
           (desc (cl-cc/javascript/objects:%js-make-object "get" getter "enumerable" t)))
      (cl-cc/javascript/proxies:%js-object-define-property obj "answer" desc)
      (let ((values (coerce (cl-cc/javascript/objects:%js-object-values obj) (quote list))))
        (expect values :to-equal (quote (123))))))
  (it-sequential "js-rt-object-keys-includes-accessor-property-name"
    (let* ((obj (cl-cc/javascript/objects:%js-make-object))
           (getter (lambda () 42))
           (desc (cl-cc/javascript/objects:%js-make-object "get" getter "enumerable" t)))
      (cl-cc/javascript/proxies:%js-object-define-property obj "answer" desc)
      (let ((keys (coerce (cl-cc/javascript/objects:%js-object-keys obj) (quote list))))
        (expect keys :to-equal (quote ("answer"))))))
  (it-sequential "js-rt-object-extensibility-seal-freeze"
    (let* ((proto (cl-cc/javascript/objects:%js-make-object "p" 1))
           (obj   (cl-cc/javascript/objects:%js-object-create proto)))
      (expect (cl-cc/javascript/objects:%js-object-extensible-p obj) :to-be-truthy)
      (expect (cl-cc/javascript/objects:%js-object-get-prototype-of obj) :to-be proto)
      (expect (= 1 (cl-cc/javascript/objects:%js-get-prop obj "p")) :to-be-truthy)
      (cl-cc/javascript/objects:%js-object-prevent-extensions obj)
      (expect (cl-cc/javascript/objects:%js-object-extensible-p obj) :to-be-falsy)
      (cl-cc/javascript/objects:%js-set-prop obj "new-key" 2)
      (expect (nth-value 1 (gethash "new-key" obj)) :to-be-falsy)
      (let ((next-proto (cl-cc/javascript/objects:%js-make-object "q" 2)))
        (expect (cl-cc/javascript/proxies:%js-reflect-set-prototype-of obj next-proto) :to-be-falsy)
        (expect (cl-cc/javascript/objects:%js-object-get-prototype-of obj) :to-be proto))))
)

(in-package #:cl-cc/javascript/proxies/test)

(defun %register-proxies-runtime-object-closure-integrity-tests ()
  (labels ((make-closure ()
             (let ((closure
                     (make-instance (quote cl-cc/vm:vm-closure-object)
                                    :entry-label "closure"
                                    :params nil)))
               (cl-cc/javascript/objects:%js-set-property-descriptor
                closure "length"
                (list :value 2 :writable nil :enumerable nil :configurable t))
               (cl-cc/javascript/objects:%js-set-property-descriptor
                closure "name"
                (list :value "closure" :writable nil :enumerable nil :configurable t))
               (cl-cc/javascript/objects:%js-set-property-descriptor
                closure "prototype"
                (list :value (%js-make-object)
                      :writable t :enumerable nil :configurable nil))
               closure)))
    (it-sequential "js-rt-vm-closure-prevent-extensions-blocks-new-properties"
      (let* ((closure (make-closure))
             (descriptor (%js-make-object "value" 1)))
        (expect
         (cl-cc/javascript/proxies:%js-reflect-prevent-extensions closure)
         :to-equal t)
        (expect (%js-object-extensible-p closure) :to-equal nil)
        (expect (%js-object-sealed-p closure) :to-equal nil)
        (expect (%js-object-frozen-p closure) :to-equal nil)
        (expect
         (cl-cc/javascript/proxies:%js-reflect-define-property
          closure "added" descriptor)
         :to-equal nil)
        (expect
         (handler-case
             (progn
               (cl-cc/javascript/proxies:%js-object-define-property
                closure "added" descriptor)
               nil)
           (error () t))
         :to-be-truthy)
        (expect
         (nth-value 1
                    (cl-cc/javascript/objects:%js-property-descriptor
                     closure "added"))
         :to-equal nil)))
    (it-sequential "js-rt-vm-closure-assignment-and-symbol-own-keys"
      (let* ((closure (make-closure))
             (value 23)
             (symbol-key (cl-cc/javascript/objects:%js-make-symbol "extra"))
             (symbol-storage-key
               (cl-cc/javascript/objects:%js-symbol-as-key symbol-key))
             (hidden-symbol (cl-cc/javascript/objects:%js-make-symbol "hidden")))
        (cl-cc/javascript/objects:%js-set-prop closure "extra" value)
        (let ((descriptor
                (cl-cc/javascript/proxies:%js-object-get-own-property-descriptor
                 closure "extra")))
          (expect (%js-get-prop closure "extra") :to-equal value)
          (expect (%js-get-prop descriptor "value") :to-equal value)
          (expect (%js-get-prop descriptor "writable") :to-equal t)
          (expect (%js-get-prop descriptor "enumerable") :to-equal t)
          (expect (%js-get-prop descriptor "configurable") :to-equal t))
        (cl-cc/javascript/proxies:%js-object-define-property
         closure symbol-key
         (%js-make-object "value" 29
                          "writable" t
                          "enumerable" t
                          "configurable" t))
        (cl-cc/javascript/proxies:%js-object-define-property
         closure hidden-symbol
         (%js-make-object "value" 31
                          "writable" t
                          "enumerable" nil
                          "configurable" t))
        (let ((assigned (cl-cc/javascript/objects:%js-object-assign
                         (%js-make-object) closure)))
          (expect (%js-get-prop assigned symbol-key) :to-equal 29)
          (expect (eq (%js-get-prop assigned hidden-symbol) cl-cc/javascript/objects:+js-undefined+)
                  :to-be-truthy))
        (let ((own-keys
                (coerce (cl-cc/javascript/objects:%js-object-own-keys closure)
                        (quote list)))
              (own-symbols
                (coerce
                 (cl-cc/javascript/objects:%js-object-get-own-property-symbols closure)
                 (quote list)))
              (descriptors
                (cl-cc/javascript/proxies:%js-object-get-own-property-descriptors
                 closure)))
          (expect
           (some
            (lambda (key)
              (and (cl-cc/javascript/objects:%js-symbol-p key)
                   (string= symbol-storage-key
                            (cl-cc/javascript/objects:%js-symbol-as-key key))))
            own-keys)
           :to-be-truthy)
          (expect
           (some
            (lambda (key)
              (string= symbol-storage-key
                       (cl-cc/javascript/objects:%js-symbol-as-key key)))
            own-symbols)
           :to-be-truthy)
          (expect (nth-value 1 (gethash symbol-storage-key descriptors))
                  :to-equal t)
          (expect (%js-get-prop (gethash symbol-storage-key descriptors) "value")
                  :to-equal 29))))
    (it-sequential "js-rt-vm-closure-accessor-properties"
      (let* ((closure (make-closure))
             (value 5)
             (getter (lambda () value))
             (setter (lambda (next-value) (setf value next-value))))
        (cl-cc/javascript/proxies:%js-object-define-property
         closure "computed"
         (%js-make-object "get" getter "set" setter
                          "enumerable" t "configurable" t))
        (expect (%js-get-prop closure "computed") :to-equal 5)
        (cl-cc/javascript/objects:%js-set-prop closure "computed" 11)
        (expect (%js-get-prop closure "computed") :to-equal 11)
        (let ((descriptor
                (cl-cc/javascript/proxies:%js-object-get-own-property-descriptor
                 closure "computed")))
          (expect (%js-get-prop descriptor "get") :to-be-truthy)
          (expect (%js-get-prop descriptor "set") :to-be-truthy)
          (expect (%js-get-prop descriptor "value") :to-equal cl-cc/javascript/objects:+js-undefined+)
          (expect (%js-get-prop descriptor "writable") :to-equal cl-cc/javascript/objects:+js-undefined+))
        (cl-cc/javascript/proxies:%js-object-define-property
         closure "computed" (%js-make-object "enumerable" nil))
        (let ((descriptor
                (cl-cc/javascript/proxies:%js-object-get-own-property-descriptor
                 closure "computed")))
          (expect (%js-get-prop closure "computed") :to-equal 11)
          (expect (%js-get-prop descriptor "get") :to-be-truthy)
          (expect (%js-get-prop descriptor "set") :to-be-truthy)
          (expect (%js-get-prop descriptor "enumerable") :to-equal nil))))
    (it-sequential "js-rt-vm-closure-seal-integrity-level"
      (let* ((closure (make-closure))
             (descriptor (%js-make-object "value" 1))
             (prototype-descriptor
               (cl-cc/javascript/proxies:%js-object-get-own-property-descriptor
                closure "prototype")))
        (expect (%js-object-seal closure) :to-be closure)
        (expect (%js-object-extensible-p closure) :to-equal nil)
        (expect (%js-object-sealed-p closure) :to-equal t)
        (expect (%js-object-frozen-p closure) :to-equal nil)
        (expect (%js-get-prop prototype-descriptor "writable") :to-equal t)
        (expect (%js-get-prop prototype-descriptor "configurable") :to-equal nil)
        (expect
         (cl-cc/javascript/proxies:%js-reflect-define-property
          closure "added" descriptor)
         :to-equal nil)))
    (it-sequential "js-rt-vm-closure-freeze-integrity-level"
      (let* ((closure (make-closure))
             (descriptor (%js-make-object "value" 1)))
        (expect (%js-object-freeze closure) :to-be closure)
        (expect (%js-object-extensible-p closure) :to-equal nil)
        (expect (%js-object-sealed-p closure) :to-equal t)
        (expect (%js-object-frozen-p closure) :to-equal t)
        (let ((prototype-descriptor
                (cl-cc/javascript/proxies:%js-object-get-own-property-descriptor
                 closure "prototype")))
          (expect (%js-get-prop prototype-descriptor "writable") :to-equal nil)
          (expect (%js-get-prop prototype-descriptor "configurable") :to-equal nil))
        (expect
         (cl-cc/javascript/proxies:%js-reflect-define-property
          closure "added" descriptor)
         :to-equal nil)))))

(defun %register-proxies-runtime-object-closure-empty-integrity-test ()
  (it-sequential "js-rt-vm-closure-empty-prevent-extensions-is-sealed-and-frozen"
    (let ((closure
            (make-instance (quote cl-cc/vm:vm-closure-object)
                           :entry-label "empty"
                           :params nil)))
      (expect (%js-object-prevent-extensions closure) :to-be closure)
      (expect (%js-object-extensible-p closure) :to-equal nil)
      (expect (%js-object-sealed-p closure) :to-equal t)
      (expect (%js-object-frozen-p closure) :to-equal t))))
