;;;; t/runtime-object-ops-test.lisp
;;;;
;;;; Unit tests for runtime-object.lisp: Object static methods, prototype ops,
;;;; freeze/seal/preventExtensions (objects and arrays), and destructuring
;;;; helpers. bitwise/shift/BigInt/URI-encoding/accessor-misc coverage split
;;;; out to runtime-ops-test.lisp once this file passed the org's 500-line cap.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list)

(in-package :cl-cc-javascript/test)

;;; ─── Internal key filter ─────────────────────────────────────────────────────

(it-sequential-each (("__proto__" t) ("__class__" t) ("__get_foo" t) ("__set_foo" t)
                     ("name" nil) ("" nil))
    "js-rt-internal-key-p ~S"
    (k expected)
  (expect (cl-cc/javascript::%js-internal-key-p k) :to-equal expected))

;;; ─── Object.keys / values / entries ─────────────────────────────────────────

(it-sequential "js-rt-object-keys-excludes-internals"
  (let ((obj (cl-cc/javascript::%js-make-object "a" 1 "b" 2)))
    (setf (gethash "__proto__" obj) cl-cc/javascript::+js-null+)
    (let ((keys (sort (coerce (cl-cc/javascript::%js-object-keys obj) 'list) #'string<)))
      (expect keys :to-equal '("a" "b")))))

(it-sequential "js-rt-object-keys-includes-accessor-property-name"
  (let* ((obj (cl-cc/javascript::%js-make-object))
         (getter (lambda () 42))
         (desc (cl-cc/javascript::%js-make-object "get" getter)))
    (cl-cc/javascript::%js-object-define-property obj "answer" desc)
    (let ((keys (coerce (cl-cc/javascript::%js-object-keys obj) 'list)))
      (expect keys :to-equal '("answer")))))

(it-sequential "js-rt-object-values"
  (let* ((obj    (cl-cc/javascript::%js-make-object "x" 10 "y" 20))
         (values (sort (coerce (cl-cc/javascript::%js-object-values obj) 'list) #'<)))
    (expect values :to-equal '(10 20))))

(it-sequential "js-rt-object-values-reads-accessor"
  (let* ((obj (cl-cc/javascript::%js-make-object))
         (getter (lambda () 123))
         (desc (cl-cc/javascript::%js-make-object "get" getter)))
    (cl-cc/javascript::%js-object-define-property obj "answer" desc)
    (let ((values (coerce (cl-cc/javascript::%js-object-values obj) 'list)))
      (expect values :to-equal '(123)))))

(it-sequential "js-rt-object-entries"
  (let* ((obj     (cl-cc/javascript::%js-make-object "k" 99))
         (entries (cl-cc/javascript::%js-object-entries obj)))
    (expect (= 1 (length entries)) :to-be-truthy)
    (let ((pair (aref entries 0)))
      (expect (aref pair 0) :to-equal "k")
      (expect (= 99 (aref pair 1)) :to-be-truthy))))

(it-sequential "js-rt-object-own-keys-includes-accessor-property-name"
  (let* ((obj (cl-cc/javascript::%js-make-object "data" 1))
         (getter (lambda () 7))
         (desc (cl-cc/javascript::%js-make-object "get" getter)))
    (cl-cc/javascript::%js-object-define-property obj "computed" desc)
    (let ((keys (sort (coerce (cl-cc/javascript::%js-object-own-keys obj) 'list) #'string<)))
      (expect keys :to-equal '("computed" "data"))
      (expect (member "__get_computed" keys :test #'string=) :to-be-falsy))))

(it-sequential "js-rt-object-symbol-own-property-keys"
  (let* ((obj (cl-cc/javascript::%js-make-object "name" "visible"))
         (sym (cl-cc/javascript::%js-make-symbol "secret")))
    (cl-cc/javascript::%js-set-prop obj sym 99)
    (expect (= 99 (cl-cc/javascript::%js-get-prop obj sym)) :to-be-truthy)
    (expect (coerce (cl-cc/javascript::%js-object-keys obj) 'list) :to-equal '("name"))
    (expect (coerce (cl-cc/javascript::%js-object-get-own-property-names obj) 'list) :to-equal '("name"))
    (let ((symbols (coerce (cl-cc/javascript::%js-object-get-own-property-symbols obj) 'list))
          (own-keys (coerce (cl-cc/javascript::%js-object-own-keys obj) 'list)))
      (expect (length symbols) :to-equal 1)
      (expect (first symbols) :to-be sym)
      (expect (member "name" own-keys :test #'equal) :to-be-truthy)
      (expect (member sym own-keys :test #'eq) :to-be-truthy))))

;;; ─── Object.assign ───────────────────────────────────────────────────────────

(it-sequential "js-rt-object-assign-merges"
  (let* ((target (cl-cc/javascript::%js-make-object "a" 1))
         (src1   (cl-cc/javascript::%js-make-object "b" 2))
         (src2   (cl-cc/javascript::%js-make-object "c" 3))
         (result (cl-cc/javascript::%js-object-assign target src1 src2)))
    (expect result :to-be target)
    (expect (= 1 (gethash "a" target)) :to-be-truthy)
    (expect (= 2 (gethash "b" target)) :to-be-truthy)
    (expect (= 3 (gethash "c" target)) :to-be-truthy)))

(it-sequential "js-rt-object-assign-skips-internal-slots"
  (let* ((proto (cl-cc/javascript::%js-make-object "inherited" 9))
         (src (cl-cc/javascript::%js-object-create proto))
         (target (cl-cc/javascript::%js-make-object)))
    (cl-cc/javascript::%js-set-prop src "a" 10)
    (cl-cc/javascript::%js-object-assign target src)
    (expect (= 10 (cl-cc/javascript::%js-get-prop target "a")) :to-be-truthy)
    (expect (cl-cc/javascript::%js-object-get-prototype-of target) :to-be cl-cc/javascript::+js-null+)
    (expect (nth-value 1 (gethash "__proto__" target)) :to-be-falsy)))

(it-sequential "js-rt-object-assign-copies-symbol-properties"
  (let* ((sym (cl-cc/javascript::%js-make-symbol "copy"))
         (src (cl-cc/javascript::%js-make-object "name" "source"))
         (target (cl-cc/javascript::%js-make-object)))
    (cl-cc/javascript::%js-set-prop src sym 77)
    (cl-cc/javascript::%js-object-assign target src)
    (expect (cl-cc/javascript::%js-get-prop target "name") :to-equal "source")
    (expect (= 77 (cl-cc/javascript::%js-get-prop target sym)) :to-be-truthy)
    (let ((symbols (coerce (cl-cc/javascript::%js-object-get-own-property-symbols target)
                           'list)))
      (expect (length symbols) :to-equal 1)
      (expect (first symbols) :to-be sym))))

(it-sequential "js-rt-object-spread-set-returns-obj"
  (let ((obj (cl-cc/javascript::%js-make-object "a" 1)))
    (let ((ret (cl-cc/javascript::%js-object-spread-set obj "b" 42)))
      (expect ret :to-be obj)
      (expect (= 42 (gethash "b" obj)) :to-be-truthy))))

;;; ─── Object.create / prototype ops ──────────────────────────────────────────

(it-sequential "js-rt-object-create-with-proto"
  (let* ((proto (cl-cc/javascript::%js-make-object "method" t))
         (obj   (cl-cc/javascript::%js-object-create proto)))
    (expect (cl-cc/javascript::%js-object-get-prototype-of obj) :to-be proto)))

(it-sequential "js-rt-object-create-null-proto"
  (let ((obj (cl-cc/javascript::%js-object-create cl-cc/javascript::+js-null+)))
    (expect (cl-cc/javascript::%js-object-get-prototype-of obj) :to-be cl-cc/javascript::+js-null+)))

(it-sequential "js-rt-object-set-prototype-of"
  (let* ((obj    (cl-cc/javascript::%js-make-object "x" 1))
         (proto2 (cl-cc/javascript::%js-make-object "tag" "v2")))
    (cl-cc/javascript::%js-object-set-prototype-of obj proto2)
    (expect (cl-cc/javascript::%js-object-get-prototype-of obj) :to-be proto2)))

(it-sequential "js-rt-object-extensibility-seal-freeze"
  (let* ((proto (cl-cc/javascript::%js-make-object "p" 1))
         (obj   (cl-cc/javascript::%js-object-create proto)))
    (expect (cl-cc/javascript::%js-object-extensible-p obj) :to-be-truthy)
    (expect (cl-cc/javascript::%js-object-get-prototype-of obj) :to-be proto)
    (expect (= 1 (cl-cc/javascript::%js-get-prop obj "p")) :to-be-truthy)
    (cl-cc/javascript::%js-object-prevent-extensions obj)
    (expect (cl-cc/javascript::%js-object-extensible-p obj) :to-be-falsy)
    (cl-cc/javascript::%js-set-prop obj "new-key" 2)
    (expect (nth-value 1 (gethash "new-key" obj)) :to-be-falsy)
    (let ((next-proto (cl-cc/javascript::%js-make-object "q" 2)))
      (expect (cl-cc/javascript::%js-reflect-set-prototype-of obj next-proto) :to-be-falsy)
      (expect (cl-cc/javascript::%js-object-get-prototype-of obj) :to-be proto))))

(it-sequential "js-rt-object-seal-and-freeze-mutations"
  (let ((sealed (cl-cc/javascript::%js-make-object "a" 1)))
    (expect (cl-cc/javascript::%js-object-seal sealed) :to-be sealed)
    (expect (cl-cc/javascript::%js-object-sealed-p sealed) :to-be-truthy)
    (expect (cl-cc/javascript::%js-delete sealed "a") :to-be-falsy)
    (expect (= 1 (gethash "a" sealed)) :to-be-truthy))
  (let ((frozen (cl-cc/javascript::%js-make-object "x" 10)))
    (expect (cl-cc/javascript::%js-object-freeze frozen) :to-be frozen)
    (expect (cl-cc/javascript::%js-object-frozen-p frozen) :to-be-truthy)
    (cl-cc/javascript::%js-set-prop frozen "x" 99)
    (expect (= 10 (gethash "x" frozen)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-delete frozen "x") :to-be-falsy)
    (expect (= 10 (gethash "x" frozen)) :to-be-truthy)))

;;; ─── Object.freeze/seal/preventExtensions on arrays ─────────────────────────
;;;
;;; A JS array is a CL vector, not a hash-table, so it needs its own flag
;;; storage (*js-array-flags* in runtime-property.lisp) -- these mirror the
;;; object tests above one for one to confirm arrays got the same treatment.

(it-sequential "js-rt-array-frozen-blocks-all-mutation"
  (let ((arr (cl-cc/javascript::%js-make-array 1 2 3)))
    (expect (cl-cc/javascript::%js-object-freeze arr) :to-be arr)
    (expect (cl-cc/javascript::%js-object-frozen-p arr) :to-be-truthy)
    (expect (cl-cc/javascript::%js-object-sealed-p arr) :to-be-truthy)
    (expect (cl-cc/javascript::%js-object-extensible-p arr) :to-be-falsy)
    ;; existing-index overwrite blocked
    (cl-cc/javascript::%js-set-prop arr "0" 99)
    (expect (= 1 (aref arr 0)) :to-be-truthy)
    ;; growth blocked, both via push and via a bare out-of-range index write
    (expect (cl-cc/javascript::%js-array-push arr 4) :to-equal 3)
    (expect (= 3 (length arr)) :to-be-truthy)
    (cl-cc/javascript::%js-set-prop arr "5" 42)
    (expect (= 3 (length arr)) :to-be-truthy)
    ;; shrink/removal blocked
    (expect (cl-cc/javascript::%js-array-pop arr) :to-be cl-cc/javascript::+js-undefined+)
    (expect (= 3 (length arr)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-array-shift arr) :to-be cl-cc/javascript::+js-undefined+)
    (expect (= 3 (length arr)) :to-be-truthy)
    ;; in-place rewrites blocked too
    (cl-cc/javascript::%js-array-fill arr 0)
    (expect (= 1 (aref arr 0)) :to-be-truthy)
    (cl-cc/javascript::%js-array-reverse arr)
    (expect (= 1 (aref arr 0)) :to-be-truthy)))

(it-sequential "js-rt-array-sealed-allows-existing-index-writes-blocks-growth-and-shrink"
  (let ((arr (cl-cc/javascript::%js-make-array 1 2 3)))
    (expect (cl-cc/javascript::%js-object-seal arr) :to-be arr)
    (expect (cl-cc/javascript::%js-object-sealed-p arr) :to-be-truthy)
    (expect (cl-cc/javascript::%js-object-frozen-p arr) :to-be-falsy)
    ;; existing-index overwrite still allowed while merely sealed
    (cl-cc/javascript::%js-set-prop arr "0" 99)
    (expect (= 99 (aref arr 0)) :to-be-truthy)
    ;; growth blocked
    (expect (cl-cc/javascript::%js-array-push arr 4) :to-equal 3)
    (expect (= 3 (length arr)) :to-be-truthy)
    ;; shrink/removal blocked (deletion needs [[Configurable]])
    (expect (cl-cc/javascript::%js-array-pop arr) :to-be cl-cc/javascript::+js-undefined+)
    (expect (= 3 (length arr)) :to-be-truthy)
    ;; in-place rewrite (no length change) still allowed
    (cl-cc/javascript::%js-array-reverse arr)
    (expect (= 99 (aref arr 2)) :to-be-truthy)))

(it-sequential "js-rt-array-prevent-extensions-blocks-growth-only"
  (let ((arr (cl-cc/javascript::%js-make-array 1 2 3)))
    (cl-cc/javascript::%js-object-prevent-extensions arr)
    (expect (cl-cc/javascript::%js-object-extensible-p arr) :to-be-falsy)
    (expect (cl-cc/javascript::%js-object-sealed-p arr) :to-be-falsy)
    ;; growth still blocked
    (expect (cl-cc/javascript::%js-array-push arr 4) :to-equal 3)
    ;; but shrink/removal is unaffected by extensibility alone
    (expect (cl-cc/javascript::%js-array-pop arr) :to-equal 3)
    (expect (= 2 (length arr)) :to-be-truthy)))

(it-sequential "js-rt-array-extra-property-respects-frozen-and-sealed"
  (let ((frozen (cl-cc/javascript::%js-make-array 1)))
    (cl-cc/javascript::%js-set-prop frozen "tag" "before")
    (cl-cc/javascript::%js-object-freeze frozen)
    (cl-cc/javascript::%js-set-prop frozen "tag" "after")
    (expect (cl-cc/javascript::%js-get-prop frozen "tag") :to-equal "before")
    (cl-cc/javascript::%js-set-prop frozen "new-prop" 1)
    (expect (cl-cc/javascript::%js-get-prop frozen "new-prop") :to-be cl-cc/javascript::+js-undefined+)))

;;; ─── Object.hasOwn ───────────────────────────────────────────────────────────

(it-sequential-each (("a" t) ("z" nil))
    "js-rt-object-has-own ~S"
    (key expected)
  (let ((obj (cl-cc/javascript::%js-make-object "a" 1)))
    (expect (cl-cc/javascript::%js-object-has-own obj key) :to-equal expected)))

(it-sequential "js-rt-object-has-own-symbol-key"
  (let* ((obj (cl-cc/javascript::%js-make-object))
         (sym (cl-cc/javascript::%js-make-symbol "owned")))
    (cl-cc/javascript::%js-set-prop obj sym 42)
    (expect (cl-cc/javascript::%js-object-has-own obj sym) :to-be-truthy)
    (expect (cl-cc/javascript::%js-object-has-own
                   obj
                   (cl-cc/javascript::%js-make-symbol "owned")) :to-be-falsy)))

(it-sequential "js-rt-object-has-own-accessor-property"
  (let* ((obj (cl-cc/javascript::%js-make-object))
         (getter (lambda () 42))
         (desc (cl-cc/javascript::%js-make-object "get" getter)))
    (cl-cc/javascript::%js-object-define-property obj "answer" desc)
    (expect (cl-cc/javascript::%js-object-has-own obj "answer") :to-be-truthy)))

;;; ─── Object.fromEntries ──────────────────────────────────────────────────────

(it-sequential "js-rt-object-from-entries"
  (let* ((pairs (cl-cc/javascript::%js-make-array (%jr-arr "x" 10)
                                                   (%jr-arr "y" 20)))
         (obj   (cl-cc/javascript::%js-object-from-entries pairs)))
    (expect (= 10 (gethash "x" obj)) :to-be-truthy)
    (expect (= 20 (gethash "y" obj)) :to-be-truthy)))

(it-sequential "js-rt-object-from-entries-preserves-symbol-keys"
  (let* ((sym (cl-cc/javascript::%js-make-symbol "entry"))
         (pairs (cl-cc/javascript::%js-make-array (%jr-arr sym 88)))
         (obj (cl-cc/javascript::%js-object-from-entries pairs)))
    (expect (= 88 (cl-cc/javascript::%js-get-prop obj sym)) :to-be-truthy)
    (let ((symbols (coerce (cl-cc/javascript::%js-object-get-own-property-symbols obj)
                           'list)))
      (expect (length symbols) :to-equal 1)
      (expect (first symbols) :to-be sym))))

;;; ─── Object.withoutKeys ──────────────────────────────────────────────────────

(it-sequential "js-rt-object-without-keys"
  (let* ((obj  (cl-cc/javascript::%js-make-object "a" 1 "b" 2 "c" 3))
         (excl (%jr-arr "b"))
         (copy (cl-cc/javascript::%js-object-without-keys obj excl)))
    (expect (eq obj copy) :to-be-falsy)
    (expect (= 1 (gethash "a" copy)) :to-be-truthy)
    (expect (nth-value 1 (gethash "b" copy)) :to-be-falsy)
    (expect (= 3 (gethash "c" copy)) :to-be-truthy)))

;;; ─── Object.groupBy ──────────────────────────────────────────────────────────

(it-sequential "js-rt-object-group-by"
  (let* ((items  (%jr-arr 1 2 3 4))
         (key-fn (lambda (x index)
                   (declare (ignore index))
                   (if (evenp x) "even" "odd")))
         (grouped (cl-cc/javascript::%js-object-group-by items key-fn)))
    (expect (= 2 (length (gethash "even" grouped))) :to-be-truthy)
    (expect (= 2 (length (gethash "odd"  grouped))) :to-be-truthy)))

(it-sequential "js-rt-object-group-by-passes-index"
  (let* ((seen '())
         (items (%jr-arr "a" "b" "c"))
         (grouped (cl-cc/javascript::%js-object-group-by
                   items
                   (lambda (item index)
                     (push (list item index) seen)
                     (if (evenp index) "even-index" "odd-index")))))
    (expect seen :to-equal '(("c" 2) ("b" 1) ("a" 0)))
    (expect (%jr-list (gethash "even-index" grouped)) :to-equal '("a" "c"))
    (expect (%jr-list (gethash "odd-index" grouped)) :to-equal '("b"))))

(it-sequential "js-rt-object-group-by-null-prototype"
  (let* ((items (%jr-arr 1))
         (grouped (cl-cc/javascript::%js-object-group-by
                   items
                   (lambda (item index)
                     (declare (ignore item index))
                     "all"))))
    (expect (cl-cc/javascript::%js-object-get-prototype-of grouped) :to-be cl-cc/javascript::+js-null+)
    (expect (member "__proto__"
                          (coerce (cl-cc/javascript::%js-object-keys grouped) 'list)
                          :test #'string=) :to-be-falsy)))

;;; ─── Destructuring helpers ───────────────────────────────────────────────────

(it-sequential "js-rt-destructure-array-rest"
  (let* ((arr  (%jr-arr 10 20 30 40))
         (rest (cl-cc/javascript::%js-destructure-array arr 1 :rest)))
    (expect (= 3 (length rest)) :to-be-truthy)
    (expect (= 20 (aref rest 0)) :to-be-truthy)
    (expect (= 40 (aref rest 2)) :to-be-truthy)))

(it-sequential "js-rt-destructure-array-value-mode"
  (let* ((arr (cl-cc/javascript::%js-make-array 10))
         (result (cl-cc/javascript::%js-destructure-array arr 0 99 1 42)))
    (expect (= 10 (first result)) :to-be-truthy)
    (expect (= 42 (second result)) :to-be-truthy)))

(it-sequential "js-rt-destructure-object-rest"
  (let* ((obj    (cl-cc/javascript::%js-make-object "a" 1 "b" 2 "c" 3))
         (others (cl-cc/javascript::%js-destructure-object obj :rest "a")))
    (expect (nth-value 1 (gethash "a" others)) :to-be-falsy)
    (expect (= 2 (gethash "b" others)) :to-be-truthy)
    (expect (= 3 (gethash "c" others)) :to-be-truthy)))

(it-sequential "js-rt-destructure-object-value-mode"
  (let* ((obj    (cl-cc/javascript::%js-make-object "x" 7))
         (result (cl-cc/javascript::%js-destructure-object obj "x" 0 "y" 99)))
    (expect (= 7 (first result)) :to-be-truthy)
    (expect (= 99 (second result)) :to-be-truthy)))
