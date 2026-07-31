;;;; packages/javascript/src/runtime-array-core.lisp — JS Array core built-ins
;;;;
;;;; Load order: after runtime-array.lisp and before runtime-array-es2023.lisp.
(in-package :cl-cc/javascript)

;;; -----------------------------------------------------------------------
;;;  Arrays
;;; -----------------------------------------------------------------------
(defun %js-make-array (&rest elements)
  "Create a JS array from ELEMENTS."
  (let* ((n (length elements))
         (arr (make-array n :element-type t :adjustable t :fill-pointer n)))
    (loop for el in elements
          for i from 0
          do (setf (aref arr i) el))
    arr))

(defun %js-list-to-array (list)
  "Create a JS array (adjustable vector) from a Common Lisp LIST. Used to turn a
rest parameter's collected &rest list into a real JS array."
  (apply #'%js-make-array list))

(defun %js-make-tagged-template-strings (cooked-array raw-array)
  "Build the first argument a tagged-template call passes to its tag
function: COOKED-ARRAY (an ordinary JS array of escapes-processed strings,
`strings[0]`, `strings.length`, `strings.map(...)` all work exactly like
any other array) with a `raw` property attached pointing at RAW-ARRAY (the
same strings as-written, unescaped) -- the TC39 tagged-template protocol.
Returns COOKED-ARRAY itself (mutated via the array-extra-property side
table, see *js-array-extra-properties* in runtime-property.lisp), not a
copy, so identity-sensitive tag functions still see one object."
  (%js-array-extra-prop-set cooked-array "raw" raw-array)
  cooked-array)

(defun %js-group-into (iterate-fn get-bucket)
  "Shared get-or-create-then-push logic behind Array.prototype.group,
Array.prototype.groupToMap, Object.groupBy, and Map.groupBy — each walks its
own source with its own key-fn arity/coercion (a plain index loop with a
3-arg key-fn for the two Array methods vs %js-for-of with a 1- or 2-arg
key-fn for the other two) and stores buckets in its own kind of container
(hash-table vs js-map), but every one of them reduces to \"find or lazily
create this key's bucket array, then push the item into it\" — that part is
what this unifies.

ITERATE-FN is called with one argument, a two-argument VISIT continuation;
ITERATE-FN must call (funcall visit key item) once per source element, with
KEY already computed however that caller's JS method defines it. GET-BUCKET,
given a key, returns that key's bucket array — creating and storing an empty
one first if this is the key's first item."
  (funcall
    iterate-fn
    (lambda (key item)
      (vector-push-extend item (funcall get-bucket key)))))

(defun %js-array-push (arr val)
  "Append VAL to ARR; return new length."
  (vector-push-extend val arr)
  (length arr))

(defun %js-array-pop (arr)
  "Remove and return last element, or undefined."
  (if (zerop (length arr)) +js-undefined+
    (let ((val (aref arr (1- (length arr)))))
      (decf (fill-pointer arr))
      val)))

(defun %js-array-shift (arr)
  "Remove and return first element."
  (if (zerop (length arr)) +js-undefined+
    (let ((val (aref arr 0)))
      (loop for i from 0 below (1- (length arr))
            do (setf (aref arr i) (aref arr (1+ i))))
      (decf (fill-pointer arr))
      val)))

(defun %js-array-unshift (arr &rest items)
  "Prepend ITEMS to ARR; return new length."
  (let* ((n (length items))
         (old-len (length arr))
         (new-len (+ old-len n)))
    (adjust-array arr new-len :fill-pointer new-len)
    ;; shift existing elements right
    (loop for i from (1- old-len) downto 0
          do (setf (aref arr (+ i n)) (aref arr i)))
    ;; insert new items
    (loop for item in items for i from 0
          do (setf (aref arr i) item))
    new-len))

;;; -----------------------------------------------------------------------
;;;  Array index coercion
;;; -----------------------------------------------------------------------
(defun %js-array-to-integer (value)
  "Coerce VALUE like ECMAScript ToIntegerOrInfinity for array indices."
  (let ((n (%js-to-number value)))
    (cond
      ((%js-nan-p n) 0)
      ((%js-float-infinity-p n)
        (if (plusp n) most-positive-fixnum
          most-negative-fixnum))
      (t (truncate n)))))

(defun %js-array-relative-start (index length)
  "Clamp a relative array INDEX into the inclusive range [0, LENGTH]."
  (let ((i (%js-array-to-integer index)))
    (if (minusp i) (max 0 (+ length i))
      (min i length))))

(defun %js-array-relative-end (index length)
  "Clamp an optional relative end INDEX into the inclusive range [0, LENGTH]."
  (if (or (null index) (eq index +js-undefined+)) length
    (%js-array-relative-start index length)))

;;; -----------------------------------------------------------------------
;;;  Array callback iteration
;;; -----------------------------------------------------------------------
(defmacro %js-do-array-elements ((element index array &key result) &body body)
  "Iterate ARRAY once, binding ELEMENT and INDEX for callback-style methods."
  (let ((array-var (gensym "ARRAY-"))
        (length-var (gensym "LENGTH-")))
    `(let* ((,array-var ,array)
           (,length-var (length ,array-var)))
      (loop for ,index below ,length-var
            for ,element = (aref ,array-var ,index)
            do ,@body
            finally (return ,result)))))

(defmacro %js-array-callback (fn element index array)
  "Call a JS array callback with the standard (element, index, array) shape."
  `(%js-funcall ,fn ,element ,index ,array))

(defun %js-array-map (arr fn)
  "Map FN over ARR, returning new array."
  (let* ((n (length arr))
         (result (%js-make-vec n)))
    (%js-do-array-elements
      (element i arr :result result)
      (setf (aref result i) (%js-array-callback fn element i arr)))))

(defun %js-array-for-each (arr fn)
  "Call FN(element, index, arr) for each element of ARR; returns undefined
(JS Array.prototype.forEach)."
  (%js-do-array-elements
    (element i arr :result +js-undefined+)
    (%js-array-callback fn element i arr)))

(defun %js-array-filter (arr fn)
  "Filter ARR by predicate FN."
  (let ((result (%js-make-vec)))
    (%js-do-array-elements
      (element i arr :result result)
      (when (%js-truthy (%js-array-callback fn element i arr))
        (vector-push-extend element result)))))

(defmacro define-js-array-reducer (name direction docstring)
  "Define reduce/reduceRight from the shared accumulator prolog."
  (let ((initial-index
        (if (eq direction :forward) 0
          '(1- (length arr))))
        (next-index
        (if (eq direction :forward) 1
          '(1- i)))
        (loop-clause
        (if (eq direction :forward) '(loop for i from start below (length arr)
                do (setf acc (%js-funcall fn acc (aref arr i) i arr)))
          '(loop for i from start downto 0
                do (setf acc (%js-funcall fn acc (aref arr i) i arr))))))
    `(defun ,name (arr fn &optional (init +js-undefined+))
      ,docstring
      (let ((acc init)
            (start ,initial-index))
        (when (eq acc +js-undefined+)
          (when (zerop (length arr))
            (error "JS TypeError: Reduce of empty array with no initial value"))
          (let ((i start))
            (setf acc (aref arr i)
                  start ,next-index)))
        ,loop-clause
        acc))))

(define-js-array-reducer
  %js-array-reduce
  :forward
  "Reduce ARR with FN and optional INIT.")

(define-js-array-reducer
  %js-array-reduce-right
  :reverse
  "Reduce ARR from right with FN.")

(defmacro define-js-array-find-index (name direction docstring)
  "Define forward or reverse Array find-index variants."
  (let ((loop-clause
        (if (eq direction :forward) '(loop for i below (length arr)
                for element = (aref arr i)
                when (%js-truthy (%js-array-callback pred element i arr))
                  return i
                finally (return -1))
          '(loop for i from (1- (length arr)) downto 0
                for element = (aref arr i)
                when (%js-truthy (%js-array-callback pred element i arr))
                  return i
                finally (return -1)))))
    `(defun ,name (arr pred)
      ,docstring
      ,loop-clause)))

(define-js-array-find-index
  %js-array-find-index
  :forward
  "Return index of first element satisfying FN, or -1.")

(defun %js-array-find (arr fn)
  "Return first element satisfying FN, or undefined."
  (let ((idx (%js-array-find-index arr fn)))
    (if (= idx -1) +js-undefined+
      (aref arr idx))))

(defmacro define-js-array-predicate-test (name clause early-result final-result docstring)
  "Define a JS Array predicate-test (some/every) from the shared loop pattern."
  `(defun ,name (arr fn)
    ,docstring
    (loop for i below (length arr)
          for element = (aref arr i) ,clause (%js-truthy (%js-array-callback fn element i arr))
          return ,early-result
          finally (return ,final-result))))

(define-js-array-predicate-test
  %js-array-some
  when
  t
  nil
  "True if any element satisfies FN.")

(define-js-array-predicate-test
  %js-array-every
  unless
  nil
  t
  "True if all elements satisfy FN.")

(defun %js-array-includes (arr val &optional (from 0))
  "True if ARR contains VAL starting from FROM."
  (let* ((n (length arr))
         (start (%js-array-relative-start from n)))
    (loop for i from start below n
          when (%js-same-value-zero (aref arr i) val)
            return t
          finally (return))))

(defun %js-array-index-of (arr val &optional (from 0))
  "Return first index of VAL in ARR, or -1."
  (let* ((n (length arr))
         (start (%js-array-relative-start from n)))
    (loop for i from start below n
          when (%js-strict-eq (aref arr i) val)
            return i
          finally (return -1))))

(defun %js-array-last-index-of (arr val &optional (from nil))
  "Return last index of VAL in ARR, or -1."
  (let* ((n (length arr))
         (end
        (if from (let ((i (%js-array-to-integer from)))
            (if (minusp i) (+ n i)
              (min i (1- n))))
          (1- n))))
    (if (minusp end) -1
      (loop for i from
            end downto 0
            when (%js-strict-eq (aref arr i) val)
              return i
            finally (return -1)))))

(defun %js-array-join (arr &optional (sep ","))
  "Join array elements with separator."
  (let ((s
        (if (eq sep +js-undefined+) ","
          sep)))
    (with-output-to-string (out)
      (loop for i below (length arr)
            do (when (plusp i)
          (write-string s out)) (let ((el (aref arr i)))
          (unless (or (eq el +js-undefined+) (eq el +js-null+))
            (write-string (%js-to-string el) out)))))))

(defun %js-array-slice (arr &optional (start 0) (end nil))
  "Return a new array slice."
  (let* ((n (length arr))
         (s (%js-array-relative-start start n))
         (e (%js-array-relative-end end n))
         (len (max 0 (- e s)))
         (result (%js-make-vec len)))
    (loop for i from s below (+ s len)
          for j from 0
          do (setf (aref result j) (aref arr i)))
    result))
