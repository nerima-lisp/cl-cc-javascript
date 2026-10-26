;;;; Tests for VM object shapes, inline method tables, mark words, and value types.
(in-package :cl-cc-javascript/test)

(it-sequential "vm-object-shape-cache-distinguishes-class-and-layout"
  (let ((cl-cc/javascript:*shape-registry* (make-hash-table :test #'equal)))
    (let* ((shape (cl-cc/javascript:find-or-create-shape 'shape-case '(first second)))
           (same (cl-cc/javascript:find-or-create-shape 'shape-case '(first second)))
           (reordered (cl-cc/javascript:find-or-create-shape 'shape-case '(second first)))
           (other-class (cl-cc/javascript:find-or-create-shape 'other-shape-case
                                                                '(first second))))
      (expect same :to-be shape)
      (expect (not (eq shape reordered)) :to-be-truthy)
      (expect (not (eq shape other-class)) :to-be-truthy)
      (expect (cl-cc/javascript:shape-slot-offset shape 'first) :to-equal 0)
      (expect (cl-cc/javascript:shape-slot-offset shape 'second) :to-equal 1)
      (expect (cl-cc/javascript:shape-slot-offset reordered 'second) :to-equal 0))))

(it-sequential "vm-object-shape-cache-copies-slot-list-keys"
  (let ((cl-cc/javascript:*shape-registry* (make-hash-table :test #'equal)))
    (let* ((slots (list 'first 'second))
           (shape (cl-cc/javascript:find-or-create-shape 'mutable-layout slots)))
      (setf (cdr slots) nil)
      (expect (cl-cc/javascript:find-or-create-shape 'mutable-layout '(first second))
              :to-be shape))))

(it-sequential "vm-object-shape-slot-offsets-use-equal-string-keys"
  (let ((cl-cc/javascript:*shape-registry* (make-hash-table :test #'equal)))
    (let* ((stored-slot (copy-seq "property"))
           (lookup-slot (copy-seq "property"))
           (shape (cl-cc/javascript:find-or-create-shape
                   'string-slot-layout (list stored-slot)))
           (same-shape (cl-cc/javascript:find-or-create-shape
                        'string-slot-layout (list lookup-slot))))
      (expect (not (eq stored-slot lookup-slot)) :to-be-truthy)
      (expect same-shape :to-be shape)
      (expect (cl-cc/javascript:shape-slot-offset shape lookup-slot) :to-equal 0))))

(it-sequential "vm-object-shape-cache-copies-mutable-string-keys"
  (let ((cl-cc/javascript:*shape-registry* (make-hash-table :test #'equal)))
    (let* ((caller-slot (copy-seq "property"))
           (shape (cl-cc/javascript:find-or-create-shape
                   'mutable-string-layout (list caller-slot))))
      (setf (char caller-slot 0) #\X)
      (let* ((same-shape
               (cl-cc/javascript:find-or-create-shape
                'mutable-string-layout (list (copy-seq "property"))))
             (offset (cl-cc/javascript:shape-slot-offset
                      shape (copy-seq "property"))))
        (expect caller-slot :to-equal "Xroperty")
        (expect same-shape :to-be shape)
        (expect offset :to-equal 0)))))

(it-sequential "vm-object-imt-reinsertion-preserves-collision-chain"
  (let ((buckets (make-array cl-cc/javascript:+imt-size+ :initial-element nil))
        (selectors nil))
    (loop for index below (1+ (* 2 cl-cc/javascript:+imt-size+))
          for selector = (make-symbol (format nil "IMT-SELECTOR-~D" index))
          for bucket = (mod (sxhash selector) cl-cc/javascript:+imt-size+)
          do (push selector (aref buckets bucket))
          when (= (length (aref buckets bucket)) 3)
            do (setf selectors (subseq (aref buckets bucket) 0 3))
               (return))
    (let* ((imt (cl-cc/javascript:make-inline-method-table))
           (first-impl (lambda () :first))
           (second-impl (lambda () :second))
           (third-impl (lambda () :third))
           (first-update (lambda () :first-update))
           (second-update (lambda () :second-update)))
      (loop for selector in selectors
            for impl in (list first-impl second-impl third-impl)
            do (cl-cc/javascript:imt-insert imt selector impl))
      (cl-cc/javascript:imt-insert imt (first selectors) first-update)
      (cl-cc/javascript:imt-insert imt (second selectors) second-update)
      (expect (eq (cl-cc/javascript:imt-lookup imt (first selectors)) first-update)
              :to-be-truthy)
      (expect (eq (cl-cc/javascript:imt-lookup imt (second selectors)) second-update)
              :to-be-truthy)
      (expect (eq (cl-cc/javascript:imt-lookup imt (third selectors)) third-impl)
              :to-be-truthy))))

(it-sequential "vm-object-mark-word-packs-64-bit-boundaries"
  (let ((mark-word
          (cl-cc/javascript:make-mark-word
           :gc-color 3
           :object-kind 3
           :identity-hash 268435455
           :lock-state 4294967295)))
    (expect mark-word :to-equal (1- (ash 1 64)))
    (expect (cl-cc/javascript:mark-word-gc-color mark-word) :to-equal 3)
    (expect (cl-cc/javascript:make-mark-word :gc-color 1) :to-equal 1)
    (expect (cl-cc/javascript:make-mark-word :object-kind 1)
            :to-equal (ash 1 2))
    (expect (cl-cc/javascript:make-mark-word :identity-hash 1)
            :to-equal (ash 1 4))
    (expect (cl-cc/javascript:make-mark-word :lock-state 1)
            :to-equal (ash 1 32))))

(it-sequential-each ((:gc-color -1)
                     (:gc-color 4)
                     (:object-kind -1)
                     (:object-kind 4)
                     (:identity-hash -1)
                     (:identity-hash 268435456)
                     (:lock-state -1)
                     (:lock-state 4294967296))
    "vm-object-mark-word-rejects-out-of-range-~S-~S"
    (key value)
  (expect (handler-case
              (progn (apply #'cl-cc/javascript:make-mark-word (list key value)) nil)
            (type-error () t))
          :to-be-truthy))

(it-sequential "vm-object-value-type-registers-its-fields"
  (let ((cl-cc/javascript:*value-types* (make-hash-table :test #'eq)))
    (expect (cl-cc/javascript:defvalue-type point2d
              (x :type single-float)
              (y :type single-float))
            :to-equal 'point2d)
    (let ((definition (gethash 'point2d cl-cc/javascript:*value-types*)))
      (expect (typep definition 'cl-cc/javascript:value-type-def) :to-be-truthy)
      (expect (cl-cc/javascript::value-type-def-fields definition)
              :to-equal '((x :type single-float) (y :type single-float)))
      (expect (cl-cc/javascript::value-type-def-total-size definition) :to-equal 2))))
