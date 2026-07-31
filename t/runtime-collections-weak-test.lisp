;;;; t/runtime-collections-weak-test.lisp
;;;;
;;;; Split from runtime-collections-test.lisp: URI encoding/base64,
;;;; AggregateError/WeakRef/RegExp.escape, Map's keys/values/entries
;;;; iterators, and the weak-reference collections (WeakMap, WeakSet,
;;;; FinalizationRegistry).
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list, %jr-set)

(in-package :cl-cc-javascript/test)

;;; ─── URI encoding / base64 ───────────────────────────────────────────────────

(it-sequential-each (("hello world" "hello%20world")
                     ("a/b" "a%2Fb")
                     ("abc123" "abc123"))
    "js-rt-encode-uri-component ~S"
    (s expected)
  (expect (cl-cc/javascript::%js-encode-uri-component s) :to-equal expected))

(it-sequential "js-rt-decode-uri-component"
  (expect (cl-cc/javascript::%js-decode-uri-component "hello%20world") :to-equal "hello world"))

;; Property: decodeURIComponent(encodeURIComponent(s)) = s for any string —
;; every character %js-encode-uri-component doesn't leave literal gets
;; percent-encoded as its UTF-8 bytes, and %js-decode-uri-component's own
;; escape-or-literal loop reverses that exactly, so the round trip holds
;; regardless of how many characters in S happen to need escaping.
;; Complements the fixed examples above by covering strings with runs of
;; reserved/unreserved characters in every possible arrangement instead of
;; the two or three hand-picked shapes above.
(it-property "js-rt-encode-decode-uri-component-roundtrip-property"
    ((s (gen-string :min-length 0 :max-length 40
                    :alphabet " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")))
  (expect (cl-cc/javascript::%js-decode-uri-component
           (cl-cc/javascript::%js-encode-uri-component s))
          :to-equal s))

(it-sequential "js-rt-btoa-atob-roundtrip"
  (let* ((s "Hello, World!")
         (encoded (cl-cc/javascript::%js-btoa s))
         (decoded (cl-cc/javascript::%js-atob encoded)))
    (expect decoded :to-equal s)))

;; Property: atob(btoa(s)) = s for any binary string s (a JS "binary string"
;; is one character per byte — printable ASCII 32-126 stays safely within
;; that contract without also exercising this implementation's separate,
;; pre-existing gap around code points above 255, which %js-btoa does not
;; validate against). Complements the single fixed example above by covering
;; string lengths that aren't a multiple of 3 (the base64 group size, so
;; padding logic is exercised at every remainder: 0, 1, and 2) across many
;; generated inputs instead of one hand-picked one.
(it-property "js-rt-btoa-atob-roundtrip-property"
    ((s (gen-string :min-length 0 :max-length 40
                    :alphabet " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")))
  (expect (cl-cc/javascript::%js-atob (cl-cc/javascript::%js-btoa s)) :to-equal s))

;;; ─── AggregateError / WeakRef / RegExp.escape ────────────────────────────────

(it-sequential "js-rt-aggregate-error-make"
  (let* ((errs (%jr-arr "e1" "e2"))
         (obj  (cl-cc/javascript::%js-make-aggregate-error errs "some errors")))
    (expect (gethash "message" obj) :to-equal "some errors")
    (expect (gethash "name"    obj) :to-equal "AggregateError")
    (expect (gethash "errors"  obj) :to-be errs)
    (expect (cl-cc/javascript::%js-instanceof
                  obj cl-cc/javascript::*js-aggregate-error-class*) :to-be-truthy)))

(it-sequential "js-rt-weak-ref-make-deref"
  (let* ((target   (cl-cc/javascript::%js-make-object "k" 1))
         (wr       (cl-cc/javascript::%js-make-weak-ref target))
         (dereffed (cl-cc/javascript::%js-weak-ref-deref wr)))
    (expect dereffed :to-be target)))

(it-sequential "js-rt-weak-ref-deref-method"
  (let* ((target (cl-cc/javascript::%js-make-object "k" 1))
         (wr     (cl-cc/javascript::%js-make-weak-ref target))
         (deref  (cl-cc/javascript::%js-get-prop wr "deref")))
    (expect (funcall deref) :to-be target)))

(it-sequential "js-rt-regexp-escape"
  (expect (cl-cc/javascript::%js-regexp-escape "a.b+c?") :to-equal "\\x61\\.b\\+c\\?")
  (expect (cl-cc/javascript::%js-regexp-escape "foo-bar") :to-equal "\\x66oo\\x2Dbar")
  (expect (cl-cc/javascript::%js-regexp-escape (format nil " ~%~C" #\Tab)) :to-equal "\\x20\\n\\t"))

;;; ─── Map iterators — keys / values / entries ─────────────────────────────────

(it-sequential "js-rt-map-keys-iterator"
  (let* ((m   (cl-cc/javascript::%js-make-map))
         (acc nil))
    (cl-cc/javascript::%js-map-set m "a" 1)
    (cl-cc/javascript::%js-map-set m "b" 2)
    (cl-cc/javascript::%js-for-of
     (cl-cc/javascript::%js-map-keys m)
     (lambda (k) (push k acc)))
    (expect acc :to-equal '("b" "a"))))

(it-sequential "js-rt-map-values-iterator"
  (let* ((m   (cl-cc/javascript::%js-make-map))
         (acc nil))
    (cl-cc/javascript::%js-map-set m "x" 10)
    (cl-cc/javascript::%js-map-set m "y" 20)
    (cl-cc/javascript::%js-for-of
     (cl-cc/javascript::%js-map-values m)
     (lambda (v) (push v acc)))
    (expect acc :to-equal '(20 10))))

(it-sequential "js-rt-map-entries-iterator"
  (let* ((m   (cl-cc/javascript::%js-make-map))
         (acc nil))
    (cl-cc/javascript::%js-map-set m "k" 99)
    (cl-cc/javascript::%js-for-of
     (cl-cc/javascript::%js-map-entries m)
     (lambda (e) (push (list (aref e 0) (aref e 1)) acc)))
    (expect acc :to-equal '(("k" 99)))))

;;; ─── WeakMap ─────────────────────────────────────────────────────────────────

(it-sequential "js-rt-weak-map-lifecycle"
  (let* ((wm  (cl-cc/javascript::%js-make-weak-map))
         (key (cl-cc/javascript::%js-make-object "x" 1)))
    (expect (cl-cc/javascript::%js-weak-map-p wm) :to-be-truthy)
    (cl-cc/javascript::%js-weak-map-set wm key 42)
    (expect (= 42 (cl-cc/javascript::%js-weak-map-get wm key)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-weak-map-has wm key) :to-be-truthy)
    (expect (cl-cc/javascript::%js-weak-map-delete wm key) :to-be-truthy)
    (expect (cl-cc/javascript::%js-weak-map-has wm key) :to-be-falsy)
    (expect (cl-cc/javascript::%js-weak-map-get wm key) :to-be-js-undefined)))

(it-sequential "js-rt-weak-map-get-or-insert"
  (let* ((wm  (cl-cc/javascript::%js-make-weak-map))
         (key (cl-cc/javascript::%js-make-object "x" 1)))
    (cl-cc/javascript::%js-weak-map-set wm key 12)
    (expect (= 12 (cl-cc/javascript::%js-weak-map-get-or-insert wm key 99)) :to-be-truthy)
    (expect (= 12 (cl-cc/javascript::%js-weak-map-get wm key)) :to-be-truthy)))

(it-sequential "js-rt-weak-map-get-or-insert-computed"
  (let* ((wm  (cl-cc/javascript::%js-make-weak-map))
         (key (cl-cc/javascript::%js-make-object "x" 1))
         (calls 0))
    (cl-cc/javascript::%js-weak-map-set wm key 3)
    (expect (= 3 (cl-cc/javascript::%js-weak-map-get-or-insert-computed
               wm key
               (lambda (k)
                 (declare (ignore k))
                 (incf calls)
                 99))) :to-be-truthy)
    (expect (zerop calls) :to-be-truthy)
    (let ((other-key (cl-cc/javascript::%js-make-object "y" 2)))
      (expect (= 10 (cl-cc/javascript::%js-weak-map-get-or-insert-computed
                 wm other-key
                 (lambda (k)
                   (declare (ignore k))
                   (incf calls)
                   10))) :to-be-truthy)
      (expect (= 1 calls) :to-be-truthy)
      (expect (= 10 (cl-cc/javascript::%js-weak-map-get wm other-key)) :to-be-truthy))))

(it-sequential "js-rt-weak-map-get-or-insert-computed-reentrant"
  (let* ((wm  (cl-cc/javascript::%js-make-weak-map))
         (key (cl-cc/javascript::%js-make-object "x" 1))
         (calls 0))
    (expect (= 20 (cl-cc/javascript::%js-weak-map-get-or-insert-computed
               wm key
               (lambda (k)
                 (incf calls)
                 (cl-cc/javascript::%js-weak-map-set wm k 20)
                 99))) :to-be-truthy)
    (expect (= 1 calls) :to-be-truthy)
    (expect (= 20 (cl-cc/javascript::%js-weak-map-get wm key)) :to-be-truthy)))

;;; ─── WeakSet ─────────────────────────────────────────────────────────────────

(it-sequential "js-rt-weak-set-lifecycle"
  (let* ((ws  (cl-cc/javascript::%js-make-weak-set))
         (obj (cl-cc/javascript::%js-make-object "y" 2)))
    (expect (cl-cc/javascript::%js-weak-set-p ws) :to-be-truthy)
    (cl-cc/javascript::%js-weak-set-add ws obj)
    (expect (cl-cc/javascript::%js-weak-set-has ws obj) :to-be-truthy)
    (expect (cl-cc/javascript::%js-weak-set-has ws (cl-cc/javascript::%js-make-object)) :to-be-falsy)
    (cl-cc/javascript::%js-weak-set-delete ws obj)
    (expect (cl-cc/javascript::%js-weak-set-has ws obj) :to-be-falsy)))

;;; ─── FinalizationRegistry ────────────────────────────────────────────────────

(it-sequential "js-rt-finalization-registry-register-unregister"
  (let* ((reg    (cl-cc/javascript::%js-make-finalization-registry (lambda (hv) (declare (ignore hv)))))
         (tgt    (cl-cc/javascript::%js-make-object))
         (token  (cl-cc/javascript::%js-make-object "token" t))
         (token2 (cl-cc/javascript::%js-make-object "token" 2)))
    (expect (cl-cc/javascript::%js-finreg-register reg tgt "held" token) :to-be-js-undefined)
    (expect (cl-cc/javascript::%js-finreg-register reg tgt "held-again" token) :to-be-js-undefined)
    (expect (cl-cc/javascript::%js-finreg-register reg tgt "held-without-token") :to-be-js-undefined)
    (expect (cl-cc/javascript::%js-finreg-unregister reg token2) :to-be-falsy)
    (expect (cl-cc/javascript::%js-finreg-unregister reg token) :to-be-truthy)
    (expect (cl-cc/javascript::%js-finreg-unregister reg token) :to-be-falsy)))

(it-sequential "js-rt-finalization-registry-methods"
  (let* ((reg        (cl-cc/javascript::%js-make-finalization-registry (lambda (hv) (declare (ignore hv)))))
         (tgt        (cl-cc/javascript::%js-make-object))
         (token      (cl-cc/javascript::%js-make-object))
         (register   (cl-cc/javascript::%js-get-prop reg "register"))
         (unregister (cl-cc/javascript::%js-get-prop reg "unregister")))
    (expect (funcall register tgt "held" token) :to-be-js-undefined)
    (expect (funcall unregister token) :to-be-truthy)
    (expect (funcall unregister token) :to-be-falsy)))
