;;;; t/runtime-builtins-iterator-proxy-test.lisp
;;;;
;;;; Split from runtime-builtins-test.lisp: Iterator.from, Map.groupBy,
;;;; Set-from-iterable, Proxy traps, Math.sumPrecise, and Error.isError /
;;;; AggregateError.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr, %jr-list)

(in-package :cl-cc-javascript/test)

;;; ─── Iterator.from ───────────────────────────────────────────────────────────

(it-sequential "js-rt-iterator-from-array"
  (let* ((arr  (%jr-arr 1 2 3))
         (iter (cl-cc/javascript::%js-iterator-from-iterable arr))
         (acc  nil))
    (cl-cc/javascript::%js-for-of iter (lambda (v) (push v acc)))
    (expect acc :to-equal '(3 2 1))))

(it-sequential "js-rt-iterator-from-set"
  (let* ((set (cl-cc/javascript::%js-make-set))
         (_   (cl-cc/javascript::%js-set-add set 3))
         (_   (cl-cc/javascript::%js-set-add set 4))
         (iter (cl-cc/javascript::%js-iterator-from-iterable set))
         (acc nil))
    (declare (ignore _))
    (cl-cc/javascript::%js-for-of iter (lambda (v) (push v acc)))
    (expect acc :to-equal '(4 3))))

(it-sequential "js-rt-iterator-from-map"
  (let* ((map (cl-cc/javascript::%js-make-map))
         (_1  (cl-cc/javascript::%js-map-set map "a" 1))
         (_2  (cl-cc/javascript::%js-map-set map "b" 2))
         (iter (cl-cc/javascript::%js-iterator-from-iterable map))
         (acc nil))
    (declare (ignore _1 _2))
    (cl-cc/javascript::%js-for-of iter
                                  (lambda (entry)
                                    (push (%jr-list entry) acc)))
    (expect acc :to-equal '(("b" 2) ("a" 1)))))

(it-sequential "js-rt-iterator-from-plain-next"
  (let* ((step 0)
         (iterable
           (cl-cc/javascript::%js-make-object
            "next" (lambda ()
                     (prog1
                         (case step
                           (0 (cl-cc/javascript::%js-make-object "value" "first" "done" nil))
                           (1 (cl-cc/javascript::%js-make-object "value" "second" "done" nil))
                           (t (cl-cc/javascript::%js-make-object "value" cl-cc/javascript::+js-undefined+ "done" t)))
                       (incf step)))))
         (iter (cl-cc/javascript::%js-iterator-from-iterable iterable))
         (acc nil))
    (cl-cc/javascript::%js-for-of iter (lambda (v) (push v acc)))
    (expect acc :to-equal '("second" "first"))))

(it-sequential "js-rt-iterator-from-@@iterator"
  (let* ((iterable
           (cl-cc/javascript::%js-make-object
            "@@iterator" (lambda ()
                           (cl-cc/javascript::%js-vec-to-iter (%jr-arr 8 9)))))
         (iter (cl-cc/javascript::%js-iterator-from-iterable iterable))
         (acc nil))
    (cl-cc/javascript::%js-for-of iter (lambda (v) (push v acc)))
    (expect acc :to-equal '(9 8))))

(it-sequential "js-rt-iterator-from-string"
  (let* ((iter (cl-cc/javascript::%js-iterator-from-iterable "ab"))
         (acc nil))
    (cl-cc/javascript::%js-for-of iter (lambda (v) (push v acc)))
    (expect acc :to-equal '("b" "a"))))

(it-sequential "js-rt-iterator-from-non-iterable"
  (let ((iter (cl-cc/javascript::%js-iterator-from-iterable
               (cl-cc/javascript::%js-make-object))))
    (multiple-value-bind (value done) (cl-cc/javascript::%js-iter-next iter)
      (expect value :to-be-js-undefined)
      (expect done :to-be-truthy))))

;;; ─── Map.groupBy ─────────────────────────────────────────────────────────────

(it-sequential "js-rt-map-group-by"
  (let* ((items  (%jr-arr 1 2 3 4))
         (result (cl-cc/javascript::%js-map-group-by
                  items (lambda (x) (if (evenp x) "even" "odd"))))
         (evens  (cl-cc/javascript::%js-map-get result "even"))
         (odds   (cl-cc/javascript::%js-map-get result "odd")))
    (expect (= 2 (length evens)) :to-be-truthy)
    (expect (= 2 (length odds)) :to-be-truthy)))

;;; ─── Set-from-iterable ───────────────────────────────────────────────────────

(it-sequential "js-rt-make-set-from-iterable"
  (let* ((arr (cl-cc/javascript::%js-make-array 1 2 3 2))
         (s   (cl-cc/javascript::%js-make-set-from-iterable arr)))
    (expect (cl-cc/javascript::%js-set-has s 1) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-has s 3) :to-be-truthy)
    (expect (cl-cc/javascript::%js-set-has s 9) :to-be-falsy)))

;;; ─── Proxy ───────────────────────────────────────────────────────────────────

(it-sequential "js-rt-make-proxy-object"
  (let* ((target  (cl-cc/javascript::%js-make-object "x" 1))
         (handler (cl-cc/javascript::%js-make-object))
         (proxy   (cl-cc/javascript::%js-make-proxy-object target handler)))
    (expect (gethash "__proxy-target__"  proxy) :to-be target)
    (expect (gethash "__proxy-handler__" proxy) :to-be handler)
    (expect (cl-cc/javascript::%js-proxy-object-p proxy) :to-be-truthy)))

(it-sequential "js-rt-proxy-property-traps"
  (let* ((target (cl-cc/javascript::%js-make-object "x" 1))
         (deleted nil)
         (handler
           (cl-cc/javascript::%js-make-object
             "get" (lambda (target key receiver)
                     (declare (ignore receiver))
                     (concatenate 'string "trap-" key "-"
                                  (cl-cc/javascript::%js-to-string
                                    (gethash key target cl-cc/javascript::+js-undefined+))))
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
         (proxy (cl-cc/javascript::%js-make-proxy-object target handler)))
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
         (proxy (cl-cc/javascript::%js-make-proxy-object
                 target (cl-cc/javascript::%js-make-object))))
    (multiple-value-bind (value trapped)
        (cl-cc/javascript::%js-proxy-call-trap proxy "get" target "x" proxy)
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
                     (if (string= key "b") 20 cl-cc/javascript::+js-undefined+))
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
                   cl-cc/javascript::+js-undefined+))
             "defineProperty"
             (lambda (target key descriptor)
               (setf (gethash key target) (gethash "value" descriptor))
               t)))
         (proxy (cl-cc/javascript::%js-make-proxy-object target handler)))
    (expect (= 20 (cl-cc/javascript::%js-reflect-get proxy "b")) :to-be-truthy)
    (expect (cl-cc/javascript::%js-reflect-set proxy "z" 99) :to-be-truthy)
    (expect (= 99 (gethash "z" target)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-reflect-define-property
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

;;; ─── Math.sumPrecise (ES2026) ────────────────────────────────────────────────

(it-sequential "js-rt-math-sum-precise"
  (let ((result (cl-cc/javascript::%js-math-sum-precise (%jr-arr 1 2 3 4))))
    (expect (= 10.0d0 result) :to-be-truthy)))

;;; ─── Error.isError (ES2026) ──────────────────────────────────────────────────

(it-sequential "js-rt-error-is-error"
  (let ((with-message (cl-cc/javascript::%js-make-error-instance
                       cl-cc/javascript::*js-error-class* "oops"))
        (plain-obj    (cl-cc/javascript::%js-make-object "x" 1)))
    (expect (cl-cc/javascript::%js-error-is-error with-message) :to-be-truthy)
    (expect (cl-cc/javascript::%js-error-is-error plain-obj) :to-be-falsy)
    (expect (cl-cc/javascript::%js-error-is-error "error") :to-be-falsy)))

;;; ─── AggregateError ──────────────────────────────────────────────────────────

(it-sequential "js-rt-make-aggregate-error"
  (let* ((errors (%jr-arr "e1" "e2"))
         (cause  (cl-cc/javascript::%js-make-object "code" "root"))
         (opts   (cl-cc/javascript::%js-make-object "cause" cause))
         (agg    (cl-cc/javascript::%js-make-aggregate-error errors "multiple" opts)))
    (expect (gethash "name"    agg) :to-equal "AggregateError")
    (expect (gethash "message" agg) :to-equal "multiple")
    (expect (gethash "stack" agg) :to-equal "AggregateError: multiple")
    (expect (gethash "errors"  agg) :to-be errors)
    (expect (gethash "cause"   agg) :to-be cause)
    (expect (cl-cc/javascript::%js-instanceof
                  agg cl-cc/javascript::*js-aggregate-error-class*) :to-be-truthy)
    (expect (cl-cc/javascript::%js-instanceof
                  agg cl-cc/javascript::*js-error-class*) :to-be-truthy)))
