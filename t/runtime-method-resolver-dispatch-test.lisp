;;;; t/runtime-method-resolver-dispatch-test.lisp
;;;;
;;;; Split from runtime-method-resolver-test.lisp: Reflect helpers, Object
;;;; property descriptors, bound-method, the define-js-type-resolver method
;;;; dispatch coverage (RegExp/Promise/Function/Symbol/TypedArray/BigInt
;;;; property and method resolution), the string resolver, string char-iter
;;;; via get-prop, and the Object fallback method table.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr)

(in-package :cl-cc-javascript/test)

;;; ─── Reflect helpers ─────────────────────────────────────────────────────────

(it-sequential "js-rt-reflect-get-set"
  (let ((obj (cl-cc/javascript::%js-make-object "x" 10)))
    (expect (= 10 (cl-cc/javascript::%js-reflect-get obj "x")) :to-be-truthy)
    (cl-cc/javascript::%js-reflect-set obj "x" 42)
    (expect (= 42 (cl-cc/javascript::%js-reflect-get obj "x")) :to-be-truthy)))

(it-sequential "js-rt-reflect-has"
  (let ((obj (cl-cc/javascript::%js-make-object "a" 1)))
    (expect (cl-cc/javascript::%js-reflect-has obj "a") :to-be-truthy)
    (expect (cl-cc/javascript::%js-reflect-has obj "b") :to-be-falsy)))

(it-sequential "js-rt-reflect-delete-property"
  (let ((obj (cl-cc/javascript::%js-make-object "k" 99)))
    (cl-cc/javascript::%js-reflect-delete-property obj "k")
    (expect (cl-cc/javascript::%js-reflect-get obj "k") :to-be-js-undefined)))

(it-sequential "js-rt-reflect-apply"
  (let* ((fn     (lambda (a b) (+ a b)))
         (result (cl-cc/javascript::%js-reflect-apply fn nil (%jr-arr 3 4))))
    (expect (= 7 result) :to-be-truthy)))

(it-sequential "js-rt-reflect-construct-mutates-this-when-ctor-returns-a-primitive"
  ;; Per JS `new` semantics, a constructor returning a primitive (here just
  ;; its first arg, a number) does NOT override `this` — the fresh instance
  ;; is returned instead, with `this` available for the constructor to mutate.
  (let* ((ctor  (lambda (&rest args)
                  (cl-cc/javascript::%js-set-prop cl-cc/javascript::%js-this
                                                   "val" (first args))
                  (first args)))
         (args  (%jr-arr 77))
         (obj   (cl-cc/javascript::%js-reflect-construct ctor args)))
    (expect (cl-cc/javascript::%js-ht-p obj) :to-be-truthy)
    (expect (cl-cc/javascript::%js-get-prop obj "val") :to-equal 77)))

(it-sequential "js-rt-reflect-construct-honors-explicit-object-return"
  (let* ((returned (cl-cc/javascript::%js-make-ht))
         (ctor     (lambda (&rest args) (declare (ignore args)) returned))
         (obj      (cl-cc/javascript::%js-reflect-construct ctor (%jr-arr))))
    (expect (eq obj returned) :to-be-truthy)))

;;; ─── Object property descriptors ────────────────────────────────────────────

(it-sequential "js-rt-object-define-property"
  (let* ((obj  (cl-cc/javascript::%js-make-object))
         (desc (cl-cc/javascript::%js-make-object "value" 77)))
    (cl-cc/javascript::%js-object-define-property obj "y" desc)
    (expect (= 77 (cl-cc/javascript::%js-reflect-get obj "y")) :to-be-truthy)))

(it-sequential "js-rt-object-get-own-property-descriptor"
  (let* ((obj  (cl-cc/javascript::%js-make-object "v" 5))
         (desc (cl-cc/javascript::%js-object-get-own-property-descriptor obj "v")))
    (expect (= 5 (gethash "value" desc)) :to-be-truthy)
    (expect (gethash "writable" desc) :to-be-truthy)))

(it-sequential-each (("real" t) ("__proto__" nil) ("__get_x" nil) ("__set_x" nil))
    "js-rt-get-own-property-descriptors-filters-internals ~A"
    (key should-appear)
  (let ((obj (cl-cc/javascript::%js-make-object "real" 1)))
    (setf (gethash "__proto__" obj) cl-cc/javascript::+js-null+
          (gethash "__get_x"   obj) (lambda () 0)
          (gethash "__set_x"   obj) (lambda (v) v))
    (let* ((descs (cl-cc/javascript::%js-object-get-own-property-descriptors obj))
           (found (nth-value 1 (gethash key descs))))
      (expect found :to-equal should-appear))))

;;; ─── bound-method ────────────────────────────────────────────────────────────

(it-sequential "js-rt-bound-method-found"
  (let* ((table (list (cons "double" (lambda (n) (* 2 n)))))
         (bound (cl-cc/javascript::%js-bound-method table 5 "double")))
    (expect (functionp bound) :to-be-truthy)
    (expect (= 10 (funcall bound)) :to-be-truthy)))

(it-sequential "js-rt-bound-method-not-found"
  (let* ((table  (list (cons "existing" #'identity)))
         (result (cl-cc/javascript::%js-bound-method table 5 "missing")))
    (expect result :to-be-js-undefined)))

;;; ─── Type resolver coverage (define-js-type-resolver) ────────────────────────

(it-sequential-each (("source" "hello") ("flags" "") ("global" nil))
    "js-rt-resolve-regexp-props ~A"
    (key expected)
  (let* ((re  (cl-cc/javascript::%js-make-regex "hello" ""))
         (val (cl-cc/javascript::%js-resolve-regexp-method re key)))
    (expect val :to-equal expected)))

(it-sequential "js-rt-resolve-regexp-test-method"
  (let* ((re (cl-cc/javascript::%js-make-regex "hi" ""))
         (fn (cl-cc/javascript::%js-resolve-regexp-method re "test")))
    (expect (funcall fn "say hi there") :to-be-truthy)
    (expect (funcall fn "goodbye") :to-be-falsy)))

(it-sequential-each (("ignoreCase" t) ("multiline" t))
    "js-rt-resolve-regexp-bool-props ~A"
    (key expected)
  (let* ((re (cl-cc/javascript::%js-make-regex "hello" "im"))
         (val (cl-cc/javascript::%js-resolve-regexp-method re key)))
    (expect val :to-equal expected)))

(it-sequential "js-rt-resolve-regexp-last-index"
  (let ((re (cl-cc/javascript::%js-make-regex "hello" "im")))
    (setf (cl-cc/javascript::js-regexp-last-index re) 3)
    (let ((val (cl-cc/javascript::%js-resolve-regexp-method re "lastIndex")))
      (expect (= 3 val) :to-be-truthy))))

(it-sequential "js-rt-resolve-regexp-exec-method"
  (let* ((re (cl-cc/javascript::%js-make-regex "hello" ""))
         (fn (cl-cc/javascript::%js-resolve-regexp-method re "exec"))
         (m  (funcall fn "say hello world")))
    (expect (gethash "0" m) :to-equal "hello")
    (expect (= 4 (truncate (gethash "index" m))) :to-be-truthy)))

(it-sequential "js-rt-resolve-promise-methods"
  (let* ((fulfilled (cl-cc/javascript::%js-promise-resolve 5))
         (rejected   (cl-cc/javascript::%js-promise-reject "boom"))
         (then       (cl-cc/javascript::%js-resolve-promise-method fulfilled "then"))
         (catch      (cl-cc/javascript::%js-resolve-promise-method rejected "catch"))
         (finally    (cl-cc/javascript::%js-resolve-promise-method fulfilled "finally"))
         (called     0)
         (then-value (cl-cc/javascript::%js-await
                      (funcall then (lambda (v) (1+ v)))))
         (catch-value (cl-cc/javascript::%js-await
                       (funcall catch (lambda (reason)
                                        (if (string= reason "boom") 99 0)))))
         (finally-value (cl-cc/javascript::%js-await
                         (funcall finally (lambda ()
                                           (incf called))))))
    (expect (= 6 then-value) :to-be-truthy)
    (expect (= 99 catch-value) :to-be-truthy)
    (expect (= 1 called) :to-be-truthy)
    (expect (= 5 finally-value) :to-be-truthy)))

(it-sequential "js-rt-resolve-promise-finally-rejects-through"
  (let* ((called 0)
         (rejected (cl-cc/javascript::%js-promise-reject "boom"))
         (finally (cl-cc/javascript::%js-resolve-promise-method rejected "finally"))
         (result (funcall finally (lambda ()
                                    (incf called)))))
    (expect-rejects (lambda () (cl-cc/javascript::%js-await result))
      :to-be-instance-of 'cl-cc/javascript:js-exception)
    (expect (= 1 called) :to-be-truthy)))

(it-sequential-each (("name" "") ("toString" "function() { [native code] }"))
    "js-rt-resolve-function-methods ~A"
    (key expected)
  (let* ((fn  (lambda (&rest args) args))
         (val (cl-cc/javascript::%js-resolve-function-method fn key))
         ;; toString resolves to a callable method (f.toString() in JS);
         ;; name resolves directly to its value.
         (result (if (functionp val) (funcall val) val)))
    (expect result :to-equal expected)))

(it-sequential "js-rt-resolve-function-length"
  (let* ((fn  (lambda (&rest args) args))
         (val (cl-cc/javascript::%js-resolve-function-method fn "length")))
    (expect (zerop val) :to-be-truthy)))

(it-sequential "js-rt-resolve-function-call-apply-bind"
  (let* ((seen nil)
         (fn   (lambda (&rest args)
                 (setf seen args)
                 args))
         (call (cl-cc/javascript::%js-resolve-function-method fn "call"))
         (apply (cl-cc/javascript::%js-resolve-function-method fn "apply"))
         (bind  (cl-cc/javascript::%js-resolve-function-method fn "bind"))
         (bound (funcall bind "self" 1 2))
         (call-result (funcall call "self" 3 4))
         (apply-result (funcall apply "self" (%jr-arr 5 6)))
         (bind-result (funcall bound 7 8)))
    (expect call-result :to-equal '("self" 3 4))
    (expect apply-result :to-equal '("self" 5 6))
    (expect bind-result :to-equal '("self" 1 2 7 8))
    (expect seen :to-equal '("self" 1 2 7 8))))

(it-sequential "js-rt-resolve-symbol-description"
  (let* ((sym (cl-cc/javascript::%js-make-symbol "label"))
         (val (cl-cc/javascript::%js-resolve-symbol-method sym "description")))
    (expect val :to-equal "label")))

(it-sequential "js-rt-resolve-method-dispatch-fallback"
  (expect (cl-cc/javascript::%js-resolve-method (list 1 2) "anything") :to-be-js-undefined))

(it-sequential-each (("Int32Array" 3 "length" 3)
                     ("Int32Array" 3 "byteLength" 12)
                     ("Int32Array" 3 "byteOffset" 0)
                     ("Float16Array" 3 "byteLength" 6))
    "js-rt-resolve-typed-array-props ~A ~*~A"
    (type-name length key expected)
  (let* ((ta  (cl-cc/javascript::%js-make-typed-array type-name length))
         (val (cl-cc/javascript::%js-resolve-typed-array-method ta key)))
    (expect (= expected val) :to-be-truthy)))

(it-sequential-each (("toString" "42") ("toLocaleString" "42"))
    "js-rt-resolve-bigint-methods ~A"
    (key expected)
  (let* ((bi     (cl-cc/javascript::%make-js-bigint 42))
         (fn     (cl-cc/javascript::%js-resolve-bigint-method bi key))
         (result (funcall fn cl-cc/javascript::+js-undefined+)))
    (expect result :to-equal expected)))

(it-sequential "js-rt-resolve-bigint-value-of"
  (let* ((bi (cl-cc/javascript::%make-js-bigint 7))
         (fn (cl-cc/javascript::%js-resolve-bigint-method bi "valueOf")))
    (expect (funcall fn) :to-be bi)))

;;; ─── String resolver ───────────────────────────────────────────────────────

(it-sequential "js-rt-string-resolver-rejects-deprecated-substr"
  (expect (cl-cc/javascript::%js-resolve-string-method "abcdef" "substr") :to-be-js-undefined))

;;; ─── String char-iter via get-prop ──────────────────────────────────────────

(it-sequential "js-rt-string-char-iter-yields-chars"
  (let* ((iter (cl-cc/javascript::%js-string-char-iter "abc"))
         (next (gethash "next" iter))
         (r1   (funcall next))
         (r2   (funcall next))
         (r3   (funcall next))
         (done (funcall next)))
    (expect (gethash "value" r1) :to-equal "a")
    (expect (gethash "value" r2) :to-equal "b")
    (expect (gethash "value" r3) :to-equal "c")
    (expect (gethash "done"  done) :to-be-truthy)))

(it-sequential "js-rt-string-char-iter-via-get-prop"
  (let* ((fn   (cl-cc/javascript::%js-get-prop "xy" "@@iterator"))
         (iter (funcall fn))
         (next (gethash "next" iter))
         (r1   (funcall next))
         (r2   (funcall next))
         (done (funcall next)))
    (expect (gethash "value" r1) :to-equal "x")
    (expect (gethash "value" r2) :to-equal "y")
    (expect (gethash "done"  done) :to-be-truthy)))

;;; ─── Object fallback method table ────────────────────────────────────────────

(it-sequential-each (("hasOwnProperty" "x" t)
                     ("hasOwnProperty" "z" nil)
                     ("propertyIsEnumerable" "x" t)
                     ("propertyIsEnumerable" "z" nil))
    "js-rt-object-fallback-methods ~A ~A"
    (method key expected)
  (let* ((obj (cl-cc/javascript::%js-make-object "x" 1))
         (fn  (cl-cc/javascript::%js-resolve-object-method obj method)))
    (expect (functionp fn) :to-be-truthy)
    (expect (funcall fn key) :to-equal expected)))

(it-sequential "js-rt-object-fallback-to-string"
  (let* ((obj (cl-cc/javascript::%js-make-object))
         (fn  (cl-cc/javascript::%js-resolve-object-method obj "toString")))
    (expect (funcall fn) :to-equal "[object Object]")))

(it-sequential "js-rt-object-fallback-value-of"
  (let* ((obj (cl-cc/javascript::%js-make-object "k" 1))
         (fn  (cl-cc/javascript::%js-resolve-object-method obj "valueOf")))
    (expect (funcall fn) :to-be obj)))

(it-sequential "js-rt-object-fallback-constructor"
  (let* ((obj (cl-cc/javascript::%js-make-object))
         (fn  (cl-cc/javascript::%js-resolve-object-method obj "constructor")))
    (expect (funcall fn) :to-be obj)))

(it-sequential "js-rt-object-fallback-stored-wins"
  (let* ((obj    (cl-cc/javascript::%js-make-object "toString" "custom"))
         (result (cl-cc/javascript::%js-resolve-object-method obj "toString")))
    (expect result :to-equal "custom")))

(it-sequential "js-rt-object-fallback-unknown-returns-undefined"
  (let* ((obj    (cl-cc/javascript::%js-make-object))
         (result (cl-cc/javascript::%js-resolve-object-method obj "nonExistent")))
    (expect result :to-be-js-undefined)))
