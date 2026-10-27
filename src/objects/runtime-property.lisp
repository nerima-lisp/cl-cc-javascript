;;;; packages/javascript/src/runtime-property.lisp — JS property access + string coercion
;;;;
;;;; %js-get-prop / %js-set-prop / %js-delete / %js-in / optional-chain ops,
;;;; plus %js-add / %js-mod / %js-divide / %js-pow / %js-to-string /
;;;; %js-template-string (arithmetic + coercion used by the above).
;;;;
;;;; Load order: after runtime.lisp (needs type predicates, method-resolver vars,
;;;;             proto-lookup helpers defined there).
(in-package #:cl-cc/javascript/objects)

;;; -----------------------------------------------------------------------
;;;  Property access
;;; -----------------------------------------------------------------------
(defun %js-accessor-descriptor-p (v)
  "True when V is a get/set accessor descriptor produced by %js-accessor
(a hash-table tagged __accessor__ carrying KIND and FN)."
  (and (%js-ht-p v) (gethash "__accessor__" v)))

(defun %js-to-property-key (key)
  "Coerce KEY to the runtime storage key for a JS property."
  (if (%js-symbol-p key) (%js-symbol-as-key key)
    (%js-to-string key)))

(defun %js-class-accessor-key (prefix raw-key)
  "Build a __get_/__set_-prefixed prototype key for a COMPUTED class accessor
name, e.g. `class C { get [expr]() {} }'. PREFIX is \"__get_\" or \"__set_\";
RAW-KEY is the un-normalized runtime value of the bracketed key expression.
Mirrors %js-class-member-key's static-name prefixing (parser-class-lower-classify.lisp)
but the key itself is only known at runtime, so the __get_/__set_ prefix is
applied via a runtime string-concat instead of being baked into a compile-time
ast-quote string."
  (concatenate 'string prefix (%js-to-property-key raw-key)))

(defvar *js-array-extra-properties* (make-hash-table :test #'eq)
  "Side table for non-index, non-\"length\" string-keyed properties set on a
JS array. This runtime represents JS arrays as plain CL adjustable vectors
(see %js-vec-p), which have no slot to carry arbitrary named properties the
way a real JS Array -- a genuine object underneath its exotic index
behavior -- can (`arr.foo = 1; arr.foo` is valid, ordinary JS). Keyed by
vector EQ identity so arrays that never use this (the overwhelming
majority) pay no cost; the inner table is created lazily per array on first
extra-property write.")

(defun %js-array-extra-prop-get (arr key)
  "Look up a non-index property KEY previously set on array ARR via
%JS-ARRAY-EXTRA-PROP-SET. Returns (values value found-p)."
  (let ((table (gethash arr *js-array-extra-properties*)))
    (if table (gethash key table)
      (values nil nil))))

(defun %js-array-extra-prop-set (arr key value)
  "Set a non-index, non-\"length\" property KEY on array ARR to VALUE, in a
lazily-created per-array side table (see *JS-ARRAY-EXTRA-PROPERTIES*)."
  (let ((table (or (gethash arr *js-array-extra-properties*)
                   (setf (gethash arr *js-array-extra-properties*)
                         (make-hash-table :test #'equal)))))
    (setf (gethash key table) value)))

(defvar *js-array-flags* (make-hash-table :test #'eq)
  "Side table for internal, non-JS-visible array flags
(__frozen__/__sealed__/__extensible__, mirroring the plain hash-table keys
Object.freeze/seal/preventExtensions already use for ordinary objects) --
deliberately SEPARATE from *JS-ARRAY-EXTRA-PROPERTIES* (ordinary named
properties like `arr.foo = 1`) so an internal flag can never leak into
Object.keys/for-in enumeration the way storing it in that other, JS-visible
table would.")

(defun %js-array-flag (arr key default)
  "Look up internal flag KEY on array ARR (see *JS-ARRAY-FLAGS*), or DEFAULT
if never set."
  (let ((table (gethash arr *js-array-flags*)))
    (if table
        (multiple-value-bind (value present-p) (gethash key table)
          (if present-p value default))
        default)))

(defun %js-set-array-flag (arr key value)
  "Set internal flag KEY on array ARR to VALUE, in a lazily-created
per-array side table (see *JS-ARRAY-FLAGS*)."
  (let ((table (or (gethash arr *js-array-flags*)
                   (setf (gethash arr *js-array-flags*)
                         (make-hash-table :test #'equal)))))
    (setf (gethash key table) value)))

(defun %js-object-put-entry (ht k v)
  "Store K -> V in object HT.  A get/set accessor descriptor is routed to the
internal __get_K / __set_K slot (so a getter and setter on the same key both
survive and are dispatched by %js-get-prop / %js-set-prop); anything else is a
plain own property."
  (if (%js-accessor-descriptor-p v) (let ((kind (gethash "kind" v))
          (fn (gethash "fn" v)))
      (setf (gethash
          (concatenate
            'string
            (if (equal kind "set") "__set_"
              "__get_")
            k)
          ht) fn))
    (setf (gethash k ht) v))
  v)

(defun %js-get-prop (obj key)
  "Get property KEY from JS object/array/string."
  (let ((k (%js-to-property-key key)))
    (cond
      ((%js-vec-p obj)
       (cond
         ((string= k "length") (length obj))
         ((every #'digit-char-p k)
          (let ((idx (parse-integer k)))
            (if (< idx (length obj))
                (aref obj idx)
                +js-undefined+)))
         ;; An own extra property (arr.foo = 1) shadows an inherited
         ;; Array.prototype method of the same name, same as real JS.
         (t (multiple-value-bind (val found) (%js-array-extra-prop-get obj k)
              (if found val (%js-object-method-ref obj k))))))
      ((stringp obj)
       (cond
         ((string= k "length") (length obj))
         ((every #'digit-char-p k)
          (let ((idx (parse-integer k)))
            (if (< idx (length obj))
                (string (char obj idx))
                +js-undefined+)))
         (t (%js-object-method-ref obj k))))
      ((%js-ht-p obj)
       (if (%js-object-proxy-p obj)
           (%js-object-proxy-get obj k obj)
           (let ((getter (gethash (concatenate 'string "__get_" k) obj)))
             (if getter
                 ;; Accessor property (get v(){...} / Object.defineProperty getter):
                 ;; invoke the getter with `this' = OBJ and return its result.
                 (%js-object-call-with-this obj getter nil)
                 (multiple-value-bind (val found) (gethash k obj)
                   (cond
                     ;; An own callable property is a method: return it bound to OBJ so
                     ;; `this' inside an object-literal method (let o={m(){return this.x}})
                     ;; resolves to the receiver, matching o.m() semantics.
                     ((and found (%js-object-callable-p val))
                      (let ((method val) (receiver obj))
                        (lambda (&rest args) (%js-object-call-with-this receiver method args))))
                     (found val)
                     (t (%js-object-proto-method-lookup obj k))))))))
      ((eq obj +js-null+) (error "JS TypeError: Cannot read properties of null"))
      ((eq obj +js-undefined+) (error "JS TypeError: Cannot read properties of undefined"))
      ;; All remaining types (Number/Symbol/Promise/Map/WeakMap/WeakSet/etc.)
      ;; delegate to the method resolver.  Struct types like js-promise, js-map,
      ;; js-weak-map returned +js-undefined+ before this fix — so promise.then /
      ;; map.get / weakmap.set all failed at the call site.
      (t (%js-object-method-ref obj k)))))

(defun %js-set-prop (obj key value)
  "Set property KEY on JS object/array."
  (let ((k (%js-to-property-key key)))
    (cond
      ((%js-vec-p obj)
       (cond
         ((string= k "length")
          ;; Growing or shrinking .length either adds new indices (blocked
          ;; while non-extensible, i.e. sealed or frozen) or deletes existing
          ;; ones (also blocked while sealed or frozen -- deletion needs
          ;; [[Configurable]], same as %js-delete's object branch above).
          (unless (or (%js-object-sealed-p obj) (%js-object-frozen-p obj))
            (let ((new-len (truncate value)))
              (adjust-array obj new-len :fill-pointer new-len))))
         ((every #'digit-char-p k)
          (let ((idx (parse-integer k)))
            (if (< idx (length obj))
                ;; Overwriting an existing element's value stays writable
                ;; while merely sealed -- only frozen blocks it.
                (unless (%js-object-frozen-p obj)
                  (setf (aref obj idx) value))
                ;; Growing the array by writing past its current end is
                ;; adding a new index: blocked once non-extensible.
                (unless (or (%js-object-frozen-p obj)
                            (not (%js-object-extensible-p obj)))
                  (adjust-array obj (1+ idx) :fill-pointer (1+ idx)
                                :initial-element +js-undefined+)
                  (setf (aref obj idx) value)))))
         ;; A non-index, non-"length" key: an ordinary named property, same
         ;; as `arr.foo = 1' in real JS. See *js-array-extra-properties*.
         (t
          (let ((present-p (nth-value 1 (%js-array-extra-prop-get obj k))))
            (unless (or (%js-object-frozen-p obj)
                        (not (or present-p (%js-object-extensible-p obj))))
              (%js-array-extra-prop-set obj k value))))))
      ((%js-ht-p obj)
       (cond
         ((%js-object-proxy-p obj)
          (%js-object-proxy-set obj k value obj))
         ;; Defining an accessor (object-literal get/set, or assignment of an
         ;; accessor descriptor): route the fn to __get_K/__set_K so a getter and
         ;; setter on the same key coexist instead of overwriting each other.
         ((%js-accessor-descriptor-p value)
          (%js-object-put-entry obj k value))
         ;; Plain write to a key that has a setter (own, or inherited from the
         ;; class prototype): invoke it with `this' = OBJ.
         (t
          (let ((setter (or (gethash (concatenate 'string "__set_" k) obj)
                            (%js-object-proto-accessor-lookup obj (concatenate 'string "__set_" k)))))
            (if setter
                (%js-object-call-with-this obj setter (list value))
                (multiple-value-bind (_old present-p) (gethash k obj)
                  (declare (ignore _old))
                  (unless (or (%js-object-frozen-p obj)
                              (not (or present-p (%js-object-extensible-p obj))))
                    (setf (gethash k obj) value))))))))
      (t nil)))
  value)

(defun %js-delete (obj key)
  "JS delete operator."
  (let ((k (%js-to-property-key key)))
    (cond
      ((%js-object-proxy-p obj) (%js-object-proxy-delete-property obj k))
      ((%js-ht-p obj)
        (unless (and
            (or (%js-object-sealed-p obj) (%js-object-frozen-p obj))
            (nth-value 1 (gethash k obj)))
          (remhash k obj)
          t))
      (t t))))

(defun %js-in (key obj)
  "JS 'key in obj'."
  (let ((k (%js-to-property-key key)))
    (cond
      ((%js-object-proxy-p obj) (%js-object-proxy-has obj k))
      ((%js-ht-p obj) (nth-value 1 (gethash k obj)))
      ((%js-vec-p obj)
        (or
          (string= k "length")
          (and (every #'digit-char-p k) (< (parse-integer k) (length obj)))
          (nth-value 1 (%js-array-extra-prop-get obj k))))
      (t nil))))

(defun %js-optional-chain (obj key)
  "Return nil if OBJ is null/undefined, else %js-get-prop."
  (if (%js-not-nullish obj) (%js-get-prop obj key)
    +js-undefined+))

(defun %js-optional-call (func &rest args)
  "Call FUNC with ARGS unless FUNC is null/undefined."
  (if (%js-not-nullish func) (apply func args)
    +js-undefined+))

(defun %js-optional-method-call (obj key &rest args)
  "obj?.method(args) — short-circuit to undefined when OBJ is null/undefined."
  (if (%js-not-nullish obj) (let ((method (%js-get-prop obj key)))
      (apply #'%js-object-funcall method args))
    +js-undefined+))

;;; -----------------------------------------------------------------------
;;;  Control flow / exceptions and iteration protocol
;;; -----------------------------------------------------------------------
;;; js-exception and %js-throw are in errors/runtime-exception.lisp.
;;; %js-try-catch-finally, %js-for-in, and %js-iter-keys are in statements/runtime-control.lisp.
;;; %js-for-of, %js-iter-values, and iterator-drain helpers are in iterators/runtime-for-of.lisp.
