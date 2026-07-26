;;;; packages/javascript/src/runtime-typed-arrays-methods-es2023.lisp — ES2023+ TypedArray methods
;;;;
;;;; Non-mutating methods, iterator helpers, and the TypedArray method dispatch
;;;; table live here so runtime-typed-arrays-methods.lisp can stay focused on the
;;;; core prototype operations.

(in-package :cl-cc/javascript)

;;; ─── ES2023 non-mutating TypedArray methods ──────────────────────────────────

(defun %js-ta-to-reversed (ta)
  "TypedArray.prototype.toReversed() — reversed copy."
  (let* ((n (js-ta-length ta))
         (new-buf (make-array n :element-type t :initial-element 0)))
    (dotimes (i n)
      (setf (aref new-buf i) (aref (js-ta-buffer ta) (- n 1 i))))
    (%js-ta-clone-with-buffer ta new-buf)))

(defun %js-ta-to-sorted (ta &optional compare-fn)
  "TypedArray.prototype.toSorted() — sorted copy."
  (let* ((n (js-ta-length ta))
         (new-buf (make-array n :element-type t :initial-element 0))
         (sorted (sort (coerce (copy-seq (js-ta-buffer ta)) 'list)
                       (if compare-fn
                           (lambda (a b) (< (%js-to-number (%js-funcall compare-fn a b)) 0))
                           #'<))))
    (loop for v in sorted for i from 0 do (setf (aref new-buf i) v))
    (%js-ta-clone-with-buffer ta new-buf)))

(defun %js-ta-with (ta index value)
  "TypedArray.prototype.with() — copy with one element replaced."
  (let* ((n (js-ta-length ta))
         (i (if (< index 0) (+ n index) index))
         (new-buf (copy-seq (js-ta-buffer ta))))
    (setf (aref new-buf i) (%js-ta-coerce-element (js-ta-type-name ta) value))
    (%js-ta-clone-with-buffer ta new-buf)))

(defun %js-ta-at (ta index)
  "TypedArray.prototype.at() — negative indexing."
  (let* ((n (js-ta-length ta))
         (i (if (< index 0) (+ n index) index)))
    (if (or (< i 0) (>= i n))
        +js-undefined+
        (coerce (aref (js-ta-buffer ta) i) 'double-float))))

(defmacro define-js-ta-find (name direction return docstring)
  "Define a TypedArray find/findLast (RETURN :value) or findIndex/findLastIndex
(RETURN :index) variant, iterating forward or in reverse — the TypedArray
analogue of runtime-array-core.lisp's DEFINE-JS-ARRAY-FIND-INDEX, generalized
to also return the found value (find/findLast return elements, not indices)."
  (let* ((not-found (if (eq return :value) '+js-undefined+ '-1.0d0))
         (found-form (if (eq return :value) 'v '(coerce i 'double-float)))
         (loop-clause
           (if (eq direction :forward)
               `(dotimes (i (js-ta-length ta) ,not-found)
                  (let ((v (coerce (aref (js-ta-buffer ta) i) 'double-float)))
                    (when (%js-truthy (%js-funcall fn v i ta))
                      (return ,found-form))))
               `(loop for i from (1- (js-ta-length ta)) downto 0
                      do (let ((v (coerce (aref (js-ta-buffer ta) i) 'double-float)))
                           (when (%js-truthy (%js-funcall fn v i ta))
                             (return ,found-form)))
                      finally (return ,not-found)))))
    `(defun ,name (ta fn)
       ,docstring
       ,loop-clause)))

(define-js-ta-find %js-ta-find :forward :value
  "TypedArray.prototype.find().")

(define-js-ta-find %js-ta-find-index :forward :index
  "TypedArray.prototype.findIndex().")

(define-js-ta-find %js-ta-find-last :reverse :value
  "TypedArray.prototype.findLast().")

(define-js-ta-find %js-ta-find-last-index :reverse :index
  "TypedArray.prototype.findLastIndex().")

(defmacro define-js-ta-predicate-test (name clause early-result final-result docstring)
  "Define a JS TypedArray predicate-test (some/every) from the shared loop
pattern — the TypedArray analogue of DEFINE-JS-ARRAY-PREDICATE-TEST."
  `(defun ,name (ta fn)
     ,docstring
     (loop for i below (js-ta-length ta)
           for element = (coerce (aref (js-ta-buffer ta) i) 'double-float)
           ,clause (%js-truthy (%js-funcall fn element i ta))
             return ,early-result
           finally (return ,final-result))))

(define-js-ta-predicate-test %js-ta-every unless nil t
  "TypedArray.prototype.every().")

(define-js-ta-predicate-test %js-ta-some when t nil
  "TypedArray.prototype.some().")

(defun %js-ta-reverse (ta)
  "TypedArray.prototype.reverse() — mutating."
  (let ((n (js-ta-length ta)) (buf (js-ta-buffer ta)))
    (loop for i below (floor n 2)
          do (rotatef (aref buf i) (aref buf (- n 1 i)))))
  ta)

(defun %js-ta-sort (ta &optional compare-fn)
  "TypedArray.prototype.sort() — mutating in-place sort."
  (let* ((n (js-ta-length ta))
         (sorted (if compare-fn
                     (sort (coerce (js-ta-buffer ta) 'list)
                           (lambda (a b) (< (%js-to-number (%js-funcall compare-fn a b)) 0)))
                     (sort (coerce (js-ta-buffer ta) 'list) #'<))))
    (loop for v in sorted for i from 0 do (setf (aref (js-ta-buffer ta) i) v)))
  ta)

(defun %js-ta-copy-within (ta target &optional (start 0) end)
  "TypedArray.prototype.copyWithin()."
  (let* ((n (js-ta-length ta))
         (t1 (if (< target 0) (max 0 (+ n target)) (min target n)))
         (s  (if (< start  0) (max 0 (+ n start))  (min start  n)))
         (e  (if (null end) n (if (< end 0) (max 0 (+ n end)) (min end n)))))
    (let ((src (subseq (js-ta-buffer ta) s e)))
      (loop for v across src for i from t1 while (< i n)
            do (setf (aref (js-ta-buffer ta) i) v))))
  ta)

(defun %js-ta-last-index-of (ta val &optional (from-index nil from-index-supplied-p))
  "TypedArray.prototype.lastIndexOf()."
  (let* ((target (%js-ta-coerce-element (js-ta-type-name ta) val))
         (n (js-ta-length ta))
         (end (if from-index-supplied-p
                  (let ((i (%js-array-to-integer from-index)))
                    (if (< i 0) (+ n i) (min i (1- n))))
                  (1- n))))
    (if (< end 0)
        -1.0d0
        (loop for i from end downto 0
              ;; Strict equality, not (=): lastIndexOf must never match NaN, and
              ;; a bare (=) against one raises FLOATING-POINT-INVALID-OPERATION
              ;; where the :INVALID trap is enabled — SBCL's default on x86-64.
              when (%js-strict-eq (aref (js-ta-buffer ta) i) target)
                return (coerce i 'double-float)
              finally (return -1.0d0)))))

(defmacro define-js-ta-iterator (name docstring value-form &key self-iterator)
  "Define a TypedArray prototype iterator method (values/keys/entries): an
object whose \"next\" method walks index I from 0 to (js-ta-length ta),
yielding VALUE-FORM (which may reference I, N, and BUF) at each step. When
SELF-ITERATOR is true, the object is also its own @@iterator (as values() is)."
  `(defun ,name (ta)
     ,docstring
     (let ((i (list 0)) (n (js-ta-length ta)) (buf (js-ta-buffer ta)))
       (declare (ignorable buf))
       (%js-make-object
        "next" (lambda ()
                 (if (< (car i) n)
                     (prog1 (%js-make-object "value" ,value-form "done" nil)
                       (incf (car i)))
                     (%js-make-object "value" +js-undefined+ "done" t)))
        ,@(when self-iterator
            `("@@iterator" (lambda () (gethash "@@iterator" (,name ta)))))))))

(define-js-ta-iterator %js-ta-values
    "TypedArray.prototype.values() — returns an iterator."
    (coerce (aref buf (car i)) 'double-float)
  :self-iterator t)

(define-js-ta-iterator %js-ta-keys
    "TypedArray.prototype.keys()."
    (coerce (car i) 'double-float))

(define-js-ta-iterator %js-ta-entries
    "TypedArray.prototype.entries()."
    (%js-make-array (coerce (car i) 'double-float) (coerce (aref buf (car i)) 'double-float)))

(defparameter *js-typed-array-method-table*
  (list (cons "set"           #'%js-ta-set-from)
        (cons "subarray"      #'%js-ta-subarray)
        (cons "slice"         #'%js-ta-slice)
        (cons "fill"          #'%js-ta-fill)
        (cons "indexOf"       #'%js-ta-index-of)
        (cons "lastIndexOf"   #'%js-ta-last-index-of)
        (cons "includes"      #'%js-ta-includes)
        (cons "join"          #'%js-ta-join)
        (cons "forEach"       #'%js-ta-for-each)
        (cons "map"           #'%js-ta-map)
        (cons "filter"        #'%js-ta-filter)
        (cons "reduce"        #'%js-ta-reduce)
        (cons "find"          #'%js-ta-find)
        (cons "findIndex"     #'%js-ta-find-index)
        (cons "findLast"      #'%js-ta-find-last)
        (cons "findLastIndex" #'%js-ta-find-last-index)
        (cons "every"         #'%js-ta-every)
        (cons "some"          #'%js-ta-some)
        (cons "reverse"       #'%js-ta-reverse)
        (cons "sort"          #'%js-ta-sort)
        (cons "copyWithin"    #'%js-ta-copy-within)
        (cons "at"            #'%js-ta-at)
        (cons "toReversed"    #'%js-ta-to-reversed)
        (cons "toSorted"      #'%js-ta-to-sorted)
        (cons "with"          #'%js-ta-with)
        (cons "values"        #'%js-ta-values)
        (cons "keys"          #'%js-ta-keys)
        (cons "entries"       #'%js-ta-entries)
        (cons "toArray"       #'%js-ta-to-array)
        (cons "@@iterator"    #'%js-ta-values)
        ;; ES2025 Uint8Array hex/base64
        (cons "toHex"         #'%js-uint8-to-hex)
        (cons "toBase64"      #'%js-uint8-to-base64)
        (cons "setFromHex"    #'%js-uint8-set-from-hex)
        (cons "setFromBase64" #'%js-uint8-set-from-base64))
  "TypedArray.prototype method dispatch.")
