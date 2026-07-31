;;;; t/runtime-builtins-platform-object-test.lisp
;;;;
;;;; Split from runtime-builtins-test.lisp: AbortController/AbortSignal, URL,
;;;; the TypedArray constructor factory, and Object.defineProperties /
;;;; Reflect.defineProperty / Object.defineProperty.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list)

(in-package :cl-cc-javascript/test)

;;; ─── Local test helpers ──────────────────────────────────────────────────────

(defun %jr-assert-string-props (object expected-props)
  "Assert every (key expected) pair in EXPECTED-PROPS against OBJECT's
matching gethash value. Uses WITH-SOFT-ASSERTIONS so a mismatch on one
property doesn't hide mismatches on the others — useful here since callers
pass many properties (e.g. every URL component) in one call."
  (with-soft-assertions
    (dolist (prop expected-props)
      (destructuring-bind (key expected) prop
        (expect (gethash key object) :to-equal expected)))))

;;; ─── AbortController ─────────────────────────────────────────────────────────

(it-sequential "js-rt-abort-controller"
  (let* ((ctrl   (cl-cc/javascript::%js-make-abort-controller))
         (sig    (gethash "signal" ctrl))
         (abort  (gethash "abort"  ctrl)))
    (expect (gethash "aborted" sig) :to-be-falsy)
    (funcall abort "reason")
    (expect (gethash "aborted" sig) :to-be-truthy)
    (expect (gethash "reason" sig) :to-equal "reason")))

(it-sequential "js-rt-abort-controller-dispatches-once"
  (let* ((ctrl   (cl-cc/javascript::%js-make-abort-controller))
         (sig    (gethash "signal" ctrl))
         (abort  (gethash "abort" ctrl))
         (onabort-calls 0)
         (listener-calls 0))
    (setf (gethash "onabort" sig)
          (lambda (event)
            (incf onabort-calls)
            (expect (gethash "type" event) :to-equal "abort")
            (expect (gethash "target" event) :to-be sig)))
    (funcall (gethash "addEventListener" sig)
             "abort"
             (lambda (event)
               (incf listener-calls)
               (expect (gethash "type" event) :to-equal "abort")
               (expect (gethash "currentTarget" event) :to-be sig)))
    (funcall abort "first")
    (funcall abort "second")
    (expect (= 1 onabort-calls) :to-be-truthy)
    (expect (= 1 listener-calls) :to-be-truthy)
    (expect (gethash "reason" sig) :to-equal "first")))

(it-sequential "js-rt-abort-signal-remove-event-listener"
  (let* ((ctrl  (cl-cc/javascript::%js-make-abort-controller))
         (sig   (gethash "signal" ctrl))
         (calls 0)
         (listener (lambda (&rest _) (declare (ignore _)) (incf calls))))
    (funcall (gethash "addEventListener" sig) "abort" listener)
    (funcall (gethash "removeEventListener" sig) "abort" listener)
    (funcall (gethash "abort" ctrl) "done")
    (expect (zerop calls) :to-be-truthy)))

(it-sequential "js-rt-abort-signal-throw-if-aborted"
  (let ((sig (cl-cc/javascript::%js-abort-signal-aborted "boom")))
    (expect (gethash "aborted" sig) :to-be-truthy)
    (expect (gethash "reason" sig) :to-equal "boom")
    (handler-case
        (progn
          (funcall (gethash "throwIfAborted" sig))
          (%fail-test "throwIfAborted did not signal js-exception"))
      (cl-cc/javascript:js-exception (c)
        (expect (cl-cc/javascript:js-exception-value c) :to-equal "boom")))))

(it-sequential "js-rt-abort-signal-static-helpers"
  (let* ((ctor    (cl-cc/javascript::%js-make-abort-signal-constructor))
         (aborted (funcall (gethash "abort" ctor) "done"))
         (timeout (funcall (gethash "timeout" ctor) 5))
         (reason  (gethash "reason" timeout))
         (source  (gethash "signal" (cl-cc/javascript::%js-make-abort-controller)))
         (combo   (funcall (gethash "any" ctor) (%jr-arr source))))
    (expect (gethash "aborted" aborted) :to-be-truthy)
    (expect (gethash "reason" aborted) :to-equal "done")
    (expect (gethash "aborted" timeout) :to-be-truthy)
    (expect (gethash "name" reason) :to-equal "TimeoutError")
    (expect (gethash "aborted" combo) :to-be-falsy)
    (cl-cc/javascript::%js-abort-signal-abort source "input")
    (expect (gethash "aborted" combo) :to-be-truthy)
    (expect (gethash "reason" combo) :to-equal "input")))

;;; ─── URL ─────────────────────────────────────────────────────────────────────

(it-sequential "js-rt-make-url-parses-components"
  (let ((url (cl-cc/javascript::%js-make-url
              "https://example.com:8443/path/to?q=1#frag")))
    (%jr-assert-string-props
     url
     '(("href" "https://example.com:8443/path/to?q=1#frag")
       ("protocol" "https:")
       ("host" "example.com:8443")
       ("hostname" "example.com")
       ("port" "8443")
       ("origin" "https://example.com:8443")
       ("pathname" "/path/to")
       ("search" "?q=1")
       ("hash" "#frag")))
    (expect (funcall (gethash "toString" url)) :to-equal "https://example.com:8443/path/to?q=1#frag")))

(it-sequential "js-rt-make-url-resolves-base-relative-path"
  (let ((url (cl-cc/javascript::%js-make-url
              "child?x=1"
              "https://example.com/a/b/index.html")))
    (%jr-assert-string-props
     url
     '(("href" "https://example.com/a/b/child?x=1")
       ("pathname" "/a/b/child")
       ("search" "?x=1")))))

(it-sequential "js-rt-make-url-normalizes-relative-dot-segments"
  (let ((url (cl-cc/javascript::%js-make-url
              "../c/./d/?x=1"
              "https://example.com/a/b/index.html")))
    (%jr-assert-string-props
     url
     '(("href" "https://example.com/a/c/d/?x=1")
       ("pathname" "/a/c/d/")
       ("search" "?x=1")))))

(it-sequential "js-rt-make-url-resolves-query-and-hash-only-relative"
  (let ((query-url (cl-cc/javascript::%js-make-url
                    "?q=2"
                    "https://example.com/a/b/index.html?old=1#frag"))
        (hash-url (cl-cc/javascript::%js-make-url
                   "#next"
                   "https://example.com/a/b/index.html?old=1#frag")))
    (%jr-assert-string-props
     query-url
     '(("href" "https://example.com/a/b/index.html?q=2")
       ("pathname" "/a/b/index.html")
       ("search" "?q=2")))
    (%jr-assert-string-props
     hash-url
     '(("href" "https://example.com/a/b/index.html?old=1#next")
       ("pathname" "/a/b/index.html")
       ("search" "?old=1")
       ("hash" "#next")))))

;;; ─── TypedArray constructor factory ─────────────────────────────────────────

(it-sequential "js-rt-typed-array-ctor-factory"
  (let* ((ctor (cl-cc/javascript::%js-make-typed-array-ctor "Int32Array"))
         (ta   (funcall ctor 3)))
    (expect (cl-cc/javascript::js-typed-array-p ta) :to-be-truthy)
    (expect (= 3 (cl-cc/javascript::js-ta-length ta)) :to-be-truthy)))

;;; ─── Object.defineProperties ─────────────────────────────────────────────────

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
    (cl-cc/javascript::%js-object-define-properties obj (%jr-arr "bad"))
    (cl-cc/javascript::%js-object-define-properties obj mixed)
    (expect (= 1 (gethash "keep" obj)) :to-be-truthy)
    (expect (= 2 (gethash "ok" obj)) :to-be-truthy)
    (expect (nth-value 1 (gethash "skip" obj)) :to-be-falsy)))

;;; ─── Reflect.defineProperty / Object.defineProperty ─────────────────────────

(it-sequential "js-rt-reflect-define-property"
  (let* ((obj  (cl-cc/javascript::%js-make-object))
         (desc (cl-cc/javascript::%js-make-object "value" 42))
         (ret  (cl-cc/javascript::%js-reflect-define-property obj "x" desc)))
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
    (let* ((descs (cl-cc/javascript::%js-object-get-own-property-descriptors obj))
           (actual (gethash "computed" descs)))
      (expect (gethash "get" actual) :to-be getter)
      (expect (nth-value 1 (gethash "__get_computed" descs)) :to-be-falsy))))

(it-sequential "js-rt-object-get-own-property-descriptor-reflects-object-flags"
  (let* ((sealed (cl-cc/javascript::%js-make-object "a" 1))
         (frozen (cl-cc/javascript::%js-make-object "b" 2)))
    (cl-cc/javascript::%js-object-seal sealed)
    (cl-cc/javascript::%js-object-freeze frozen)
    (let ((sealed-desc (cl-cc/javascript::%js-object-get-own-property-descriptor sealed "a"))
          (frozen-desc (cl-cc/javascript::%js-object-get-own-property-descriptor frozen "b")))
      (expect (gethash "configurable" sealed-desc) :to-be-falsy)
      (expect (gethash "writable" sealed-desc) :to-be-truthy)
      (expect (gethash "configurable" frozen-desc) :to-be-falsy)
      (expect (gethash "writable" frozen-desc) :to-be-falsy))))

(it-sequential "js-rt-reflect-define-property-respects-prevent-extensions"
  (let* ((obj (cl-cc/javascript::%js-make-object))
         (desc (cl-cc/javascript::%js-make-object "value" 10)))
    (cl-cc/javascript::%js-object-prevent-extensions obj)
    (expect (cl-cc/javascript::%js-reflect-define-property obj "blocked" desc) :to-be-falsy)
    (expect (nth-value 1 (gethash "blocked" obj)) :to-be-falsy)))

(it-sequential "js-rt-object-define-property-signals-on-prevent-extensions"
  (let* ((obj (cl-cc/javascript::%js-make-object))
         (desc (cl-cc/javascript::%js-make-object "value" 10)))
    (cl-cc/javascript::%js-object-prevent-extensions obj)
    (signals error (cl-cc/javascript::%js-object-define-property obj "blocked" desc))
    (expect (nth-value 1 (gethash "blocked" obj)) :to-be-falsy)))

(it-sequential "js-rt-reflect-define-property-rejects-frozen-redefine"
  (let* ((obj (cl-cc/javascript::%js-make-object "locked" 1))
         (desc (cl-cc/javascript::%js-make-object "value" 2)))
    (cl-cc/javascript::%js-object-freeze obj)
    (expect (cl-cc/javascript::%js-reflect-define-property obj "locked" desc) :to-be-falsy)
    (expect (= 1 (gethash "locked" obj)) :to-be-truthy)))

(it-sequential "js-rt-object-define-property-rejects-frozen-redefine"
  (let* ((obj (cl-cc/javascript::%js-make-object "locked" 1))
         (desc (cl-cc/javascript::%js-make-object "value" 2)))
    (cl-cc/javascript::%js-object-freeze obj)
    (signals error (cl-cc/javascript::%js-object-define-property obj "locked" desc))
    (expect (= 1 (gethash "locked" obj)) :to-be-truthy)))
