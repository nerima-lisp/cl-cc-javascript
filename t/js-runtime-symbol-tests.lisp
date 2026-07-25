;;;; t/js-runtime-symbol-tests.lisp
;;;;
;;;; Unit tests for runtime-symbol.lisp: Symbol primitive, global registry
;;;; (Symbol.for / keyFor), well-known symbols, and Symbol-as-property-key.
;;;;
;;;; Depends on: js-runtime-core-tests.lisp (%jr-arr, %jr-list)

(in-package :cl-cc-javascript/test)

;;; ─── Symbol predicate ────────────────────────────────────────────────────────

(it-sequential "js-rt-symbol-p symbol"
  (destructuring-bind (val expected) (list (cl-cc/javascript::%js-make-symbol "x") t)
    (expect (cl-cc/javascript::%js-symbol-p val) :to-equal expected)))

(it-sequential-each (("sym" nil) (42 nil) (nil nil))
    "js-rt-symbol-p ~A"
    (val expected)
  (expect (cl-cc/javascript::%js-symbol-p val) :to-equal expected))

;;; ─── Symbol creation ─────────────────────────────────────────────────────────

(it-sequential "js-rt-symbol-unique-identity"
  (let ((a (cl-cc/javascript::%js-make-symbol "tag"))
        (b (cl-cc/javascript::%js-make-symbol "tag")))
    (expect (eq a b) :to-be-falsy)))

(it-sequential "js-rt-symbol-no-description"
  (let ((sym (cl-cc/javascript::%js-make-symbol)))
    (expect (cl-cc/javascript::%js-symbol-p sym) :to-be-truthy)
    (expect (cl-cc/javascript::%js-symbol-description sym) :to-be cl-cc/javascript::+js-undefined+)))

;;; ─── toString / description ──────────────────────────────────────────────────

(it-sequential-each (("tag" "Symbol(tag)") ("" "Symbol()") (:js-undefined "Symbol()"))
    "js-rt-symbol-to-string ~A"
    (desc expected)
  (let* ((sym (cl-cc/javascript::%js-make-symbol desc))
         (str (cl-cc/javascript::%js-symbol-to-string sym)))
    (expect str :to-equal expected)))

(it-sequential "js-rt-symbol-description-accessor"
  (let ((with-desc (cl-cc/javascript::%js-make-symbol "label"))
        (no-desc   (cl-cc/javascript::%js-make-symbol)))
    (expect (cl-cc/javascript::%js-symbol-description with-desc) :to-equal "label")
    (expect (cl-cc/javascript::%js-symbol-description no-desc) :to-be cl-cc/javascript::+js-undefined+)))

;;; ─── Global registry — Symbol.for / Symbol.keyFor ────────────────────────────

(it-sequential "js-rt-symbol-for-idempotent"
  (let ((s1 (cl-cc/javascript::%js-symbol-for "my-key"))
        (s2 (cl-cc/javascript::%js-symbol-for "my-key")))
    (expect s2 :to-be s1)))

(it-sequential "js-rt-symbol-for-different-keys"
  (let ((a (cl-cc/javascript::%js-symbol-for "alpha"))
        (b (cl-cc/javascript::%js-symbol-for "beta")))
    (expect (eq a b) :to-be-falsy)))

(it-sequential "js-rt-symbol-key-for-registered"
  (let ((sym (cl-cc/javascript::%js-symbol-for "registry-key")))
    (expect (cl-cc/javascript::%js-symbol-key-for sym) :to-equal "registry-key")))

(it-sequential "js-rt-symbol-key-for-unregistered"
  (let ((local (cl-cc/javascript::%js-make-symbol "local")))
    (expect (cl-cc/javascript::%js-symbol-key-for local) :to-be cl-cc/javascript::+js-undefined+)))

(it-sequential "js-rt-symbol-key-for-non-symbol"
  (expect (cl-cc/javascript::%js-symbol-key-for "not-a-symbol") :to-be cl-cc/javascript::+js-undefined+))

;;; ─── Symbol as property key ──────────────────────────────────────────────────

(it-sequential "js-rt-symbol-as-key-format"
  (let* ((sym (cl-cc/javascript::%js-make-symbol "k"))
         (key (cl-cc/javascript::%js-symbol-as-key sym)))
    (expect (stringp key) :to-be-truthy)
    (expect (string= key "__sym_" :end1 6) :to-be-truthy)
    (expect (string= key "__" :start1 (- (length key) 2)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-symbol-storage-key-p key) :to-be-truthy)
    (expect (cl-cc/javascript::%js-symbol-from-storage-key key) :to-be sym)
    (expect (cl-cc/javascript::%js-symbol-storage-key-p "not-a-symbol-key") :to-be-falsy)
    (expect (cl-cc/javascript::%js-symbol-from-storage-key "not-a-symbol-key") :to-be cl-cc/javascript::+js-undefined+)))

;;; ─── Well-known symbols ──────────────────────────────────────────────────────

(it-sequential-each (("iterator"           cl-cc/javascript::%js-symbol-iterator)
                     ("toPrimitive"        cl-cc/javascript::%js-symbol-to-primitive)
                     ("toStringTag"        cl-cc/javascript::%js-symbol-to-string-tag)
                     ("hasInstance"        cl-cc/javascript::%js-symbol-has-instance)
                     ("species"            cl-cc/javascript::%js-symbol-species)
                     ("asyncIterator"      cl-cc/javascript::%js-symbol-async-iterator)
                     ("match"              cl-cc/javascript::%js-symbol-match)
                     ("replace"            cl-cc/javascript::%js-symbol-replace)
                     ("search"             cl-cc/javascript::%js-symbol-search)
                     ("split"              cl-cc/javascript::%js-symbol-split)
                     ("dispose"            cl-cc/javascript::%js-symbol-dispose)
                     ("asyncDispose"       cl-cc/javascript::%js-symbol-async-dispose)
                     ("metadata"           cl-cc/javascript::%js-symbol-metadata)
                     ("isConcatSpreadable" cl-cc/javascript::%js-symbol-is-concat-spreadable)
                     ("unscopables"        cl-cc/javascript::%js-symbol-unscopables))
    "js-rt-well-known-symbol-~A-is-registered"
    (name symbol-var)
  (declare (ignore name))
  (expect (cl-cc/javascript::%js-symbol-p (symbol-value symbol-var)) :to-be-truthy))

;;; ─── Symbol global object ────────────────────────────────────────────────────

(it-sequential-each (("iterator")     ("toPrimitive")     ("toStringTag")
                     ("hasInstance")  ("species")         ("asyncIterator")
                     ("match")        ("replace")         ("search")
                     ("split")        ("dispose")         ("asyncDispose")
                     ("metadata")     ("isConcatSpreadable") ("unscopables"))
    "js-rt-symbol-global-exposes-~A"
    (prop-name)
  (expect (cl-cc/javascript::%js-symbol-p
           (gethash prop-name cl-cc/javascript::*js-symbol-global*))
          :to-be-truthy))

(it-sequential "js-rt-symbol-global-has-static-methods-and-callable"
  (let ((g cl-cc/javascript::*js-symbol-global*))
    (expect (cl-cc/javascript::%js-ht-p g) :to-be-truthy)
    (expect (functionp (gethash "for" g)) :to-be-truthy)
    (expect (functionp (gethash "keyFor" g)) :to-be-truthy)
    (expect (functionp (gethash "__call__" g)) :to-be-truthy)
    (expect (funcall (gethash "for" g) "wk-registry-test")
            :to-be (cl-cc/javascript::%js-symbol-for "wk-registry-test"))
    (expect (cl-cc/javascript::%js-symbol-p (funcall (gethash "__call__" g)))
            :to-be-truthy)))

;;; ─── Iterator control: iter-values / iter-keys / advance-iterator ────────────

(it-sequential "js-rt-iter-values-from-array"
  (let* ((arr    (%jr-arr 10 20 30))
         (values (cl-cc/javascript::%js-iter-values arr)))
    (expect values :to-equal '(10 20 30))))

(it-sequential "js-rt-iter-values-from-string"
  (expect (cl-cc/javascript::%js-iter-values "abc") :to-equal '("a" "b" "c")))

(it-sequential "js-rt-advance-iterator-drains-object"
  (let* ((items '(7 8 9))
         (idx   (list 0))
         (iter  (cl-cc/javascript::%js-make-object
                 "next" (lambda ()
                           (if (< (car idx) (length items))
                               (prog1 (cl-cc/javascript::%js-make-object
                                       "value" (nth (car idx) items) "done" nil)
                                 (incf (car idx)))
                               (cl-cc/javascript::%js-make-object
                                "value" cl-cc/javascript::+js-undefined+ "done" t)))))
         (acc   nil))
    (cl-cc/javascript::%js-advance-iterator iter (lambda (v) (push v acc)))
    (expect acc :to-equal '(9 8 7))))
