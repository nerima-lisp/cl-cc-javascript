;;;; t/runtime-json-test.lisp
;;;;
;;;; Split from runtime-date-json-test.lisp: JSON.stringify (primitives,
;;;; string escaping, arrays, objects, nesting, raw JSON) and JSON.parse
;;;; (all value kinds, whitespace handling, invalid input, and a
;;;; stringify/parse roundtrip).
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr)

(in-package :cl-cc-javascript/test)

;;; ─── JSON stringify ──────────────────────────────────────────────────────────

(it-sequential-each ((:js-null "null")
                     (t "true")
                     (nil "false")
                     (42.0d0 "42")
                     (1.5d0 "1.5")
                     ("hello" "\"hello\"")
                     (#.cl-cc/javascript::*js-nan-float* "null"))
    "js-rt-json-stringify-primitives ~A"
    (val expected)
  (expect (cl-cc/javascript::%js-json-stringify val) :to-equal expected))

(it-sequential "js-rt-json-stringify-undefined-at-top-level-returns-undefined"
  ;; JSON.stringify(undefined) === undefined -- the actual JS value, not a
  ;; "null"/"undefined" string. Functions and Symbols get the same treatment
  ;; (no JSON representation at all); undefined is the one this runtime can
  ;; construct directly without a real function/Symbol value on hand.
  (expect (cl-cc/javascript::%js-json-stringify cl-cc/javascript::+js-undefined+)
          :to-be-js-undefined))

(it-sequential "js-rt-json-stringify-undefined-omitted-from-object-property"
  (let ((obj (cl-cc/javascript::%js-make-object
              "a" 1.0d0 "b" cl-cc/javascript::+js-undefined+ "c" 2.0d0)))
    (expect (cl-cc/javascript::%js-json-stringify obj) :to-equal "{\"a\":1,\"c\":2}")))

(it-sequential "js-rt-json-stringify-undefined-becomes-null-in-array"
  (let ((arr (cl-cc/javascript::%js-make-array
              1.0d0 cl-cc/javascript::+js-undefined+ 2.0d0)))
    (expect (cl-cc/javascript::%js-json-stringify arr) :to-equal "[1,null,2]")))

(it-sequential "js-rt-json-stringify-string-escapes"
  (expect (cl-cc/javascript::%js-json-stringify "line1
line2") :to-equal "\"line1\\nline2\"")
  (expect (cl-cc/javascript::%js-json-stringify "a	b") :to-equal "\"a\\tb\"")
  (expect (cl-cc/javascript::%js-json-stringify "say \"hi\"") :to-equal "\"say \\\"hi\\\"\""))

(it-sequential "js-rt-json-stringify-array"
  (let ((arr (cl-cc/javascript::%js-make-array 1.0d0 2.0d0 3.0d0)))
    (expect (cl-cc/javascript::%js-json-stringify arr) :to-equal "[1,2,3]")))

(it-sequential "js-rt-json-stringify-object"
  (let* ((obj    (cl-cc/javascript::%js-make-object "x" 1.0d0 "y" 2.0d0))
         (result (cl-cc/javascript::%js-json-stringify obj)))
    (expect (cl-cc/javascript::%js-string-includes result "\"x\":1") :to-be-truthy)
    (expect (cl-cc/javascript::%js-string-includes result "\"y\":2") :to-be-truthy)))

(it-sequential "js-rt-json-stringify-object-key-order"
  ;; Real JS: JSON.stringify serializes an ordinary object's own properties
  ;; in the same ES2015+ [[OwnPropertyKeys]] order Object.keys/for...in use
  ;; -- array-index keys ("1","2",...) numerically ascending, ahead of every
  ;; other key. Checks the EXACT string (not just substring inclusion, like
  ;; the alphabetic 2-key case above, which can't distinguish "did order
  ;; actually apply" from "there's nothing to reorder").
  (let* ((obj (cl-cc/javascript::%js-make-object "2" "b" "foo" "bar" "1" "a"))
         (result (cl-cc/javascript::%js-json-stringify obj)))
    (expect result :to-equal "{\"1\":\"a\",\"2\":\"b\",\"foo\":\"bar\"}")))

(it-sequential "js-rt-json-stringify-object-getter-property"
  ;; JSON.stringify reads each own enumerable key through [[Get]] -- a
  ;; getter/setter accessor property must be serialized under its own
  ;; property name, with the GETTER'S RETURN VALUE, not silently dropped
  ;; (its raw stored form is an internal __get_X/__set_X entry holding the
  ;; accessor FUNCTION itself, previously filtered out as "internal").
  (let ((ht (cl-cc/javascript::%js-make-ht)))
    (cl-cc/javascript::%js-object-put-entry
     ht "foo" (cl-cc/javascript::%js-accessor "get" (lambda () 42.0d0)))
    (expect (cl-cc/javascript::%js-json-stringify ht) :to-equal "{\"foo\":42}")))

(it-sequential "js-rt-json-stringify-nested"
  (let* ((inner (cl-cc/javascript::%js-make-object "a" 1.0d0))
         (arr   (cl-cc/javascript::%js-make-array inner))
         (result (cl-cc/javascript::%js-json-stringify arr)))
    (expect (cl-cc/javascript::%js-string-includes result "{") :to-be-truthy)
    (expect (cl-cc/javascript::%js-string-includes result "\"a\":1") :to-be-truthy)))

(it-sequential "js-rt-json-raw-json"
  (let* ((raw (cl-cc/javascript::%js-json-raw-json "{\"x\":1}"))
         (obj (cl-cc/javascript::%js-make-object "payload" raw)))
    (expect (cl-cc/javascript::%js-json-is-raw-json raw) :to-be-truthy)
    (expect (not (cl-cc/javascript::%js-json-is-raw-json obj)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-object-get-own-property-descriptor raw "__raw_json__") :to-be-js-undefined)
    (expect (cl-cc/javascript::%js-json-stringify obj) :to-equal "{\"payload\":{\"x\":1}}")))

(it-sequential "js-rt-json-raw-json-invalid"
  (signals error (cl-cc/javascript::%js-json-raw-json "{bad json}")))

(it-sequential "js-rt-json-raw-json-non-string"
  (signals error (cl-cc/javascript::%js-json-raw-json 42.0d0)))

;;; ─── JSON parse ──────────────────────────────────────────────────────────────

(it-sequential-each (("null") ("true") ("false") ("42") ("\"hello\""))
    "js-rt-json-parse-non-undefined ~S"
    (input)
  (let ((result (cl-cc/javascript::%js-json-parse input)))
    (expect (not (eq result cl-cc/javascript::+js-undefined+)) :to-be-truthy)))

(it-sequential "js-rt-json-parse-null"
  (expect (eq cl-cc/javascript::+js-null+ (cl-cc/javascript::%js-json-parse "null")) :to-be-truthy))

(it-sequential "js-rt-json-parse-booleans"
  (expect (eq t   (cl-cc/javascript::%js-json-parse "true")) :to-be-truthy)
  (expect (null (cl-cc/javascript::%js-json-parse "false")) :to-be-truthy))

(it-sequential-each (("42" 42.0d0) ("3.14" 3.14d0) ("-1" -1.0d0))
    "js-rt-json-parse-number ~A"
    (str expected)
  (expect (= expected (cl-cc/javascript::%js-json-parse str)) :to-be-truthy))

(it-sequential "js-rt-json-parse-string"
  (expect (cl-cc/javascript::%js-json-parse "\"hello\"") :to-equal "hello")
  (expect (cl-cc/javascript::%js-json-parse "\"a\\nb\"") :to-equal "a
b"))

(it-sequential "js-rt-json-parse-array"
  (let ((arr (cl-cc/javascript::%js-json-parse "[1,2,3]")))
    (expect (cl-cc/javascript::%js-vec-p arr) :to-be-truthy)
    (expect (= 3 (length arr)) :to-be-truthy)
    (expect (= 1.0d0 (aref arr 0)) :to-be-truthy)))

(it-sequential "js-rt-json-parse-object"
  (let ((obj (cl-cc/javascript::%js-json-parse "{\"x\":1,\"y\":2}")))
    (expect (cl-cc/javascript::%js-ht-p obj) :to-be-truthy)
    (expect (= 1.0d0 (gethash "x" obj)) :to-be-truthy)
    (expect (= 2.0d0 (gethash "y" obj)) :to-be-truthy)))

(it-sequential "js-rt-json-parse-nested"
  (let ((obj (cl-cc/javascript::%js-json-parse "{\"arr\":[1,2]}")))
    (let ((arr (gethash "arr" obj)))
      (expect (cl-cc/javascript::%js-vec-p arr) :to-be-truthy)
      (expect (= 2 (length arr)) :to-be-truthy))))

;;; Kept as separate forms rather than merged into an it-sequential-each: the
;;; shared body's (= expected result) branch does type-constrained arithmetic
;;; on EXPECTED, and mixing a string case ("x") with a numeric case (42.0d0)
;;; in the same quoted case list makes SBCL derive a NUMBER/VECTOR union type
;;; for EXPECTED that the (stringp expected) guard cannot narrow back down at
;;; compile time — a real compile-time type error, not just a style nit.

(it-sequential "js-rt-json-parse-whitespace number"
  (destructuring-bind (input expected) (list "  42  " 42.0d0)
    (let ((result (cl-cc/javascript::%js-json-parse input)))
    (if (stringp expected)
        (expect result :to-equal expected)
        (expect (= expected result) :to-be-truthy)))))

(it-sequential "js-rt-json-parse-whitespace string"
  (destructuring-bind (input expected) (list "  \"x\"  " "x")
    (let ((result (cl-cc/javascript::%js-json-parse input)))
    (if (stringp expected)
        (expect result :to-equal expected)
        (expect (= expected result) :to-be-truthy)))))

(it-sequential "js-rt-json-parse-invalid"
  ;; Real JSON.parse throws a SyntaxError on malformed input rather than
  ;; returning undefined -- the hand-rolled parser this runtime used to have
  ;; got this wrong (see CHANGELOG.md).
  (expect-rejects (lambda () (cl-cc/javascript::%js-json-parse "NOT_JSON"))
    :to-be-instance-of 'cl-cc/javascript:js-exception))

(it-sequential "js-rt-json-parse-unicode-escape"
  (expect (cl-cc/javascript::%js-json-parse "\"\\u0041\"") :to-equal "A")
  (expect (cl-cc/javascript::%js-json-parse "\"\\u00e9\"")
          :to-equal (string (code-char #x00e9))))

(it-sequential "js-rt-json-roundtrip"
  (let* ((orig     (cl-cc/javascript::%js-make-object "name" "Alice" "age" 30.0d0))
         (json     (cl-cc/javascript::%js-json-stringify orig))
         (reparsed (cl-cc/javascript::%js-json-parse json)))
    (expect (gethash "name" reparsed) :to-equal "Alice")
    (expect (= 30.0d0 (gethash "age" reparsed)) :to-be-truthy)))

;;; ─── Property: JSON.stringify / JSON.parse roundtrip ──────────────────────────
;;;
;;; Complements the one hand-picked flat-object case above with arbitrarily
;;; nested trees of every JSON-representable JS value kind (whole-number
;;; doubles -- this runtime's own number representation, strings, booleans,
;;; null, arrays, objects), up to 3 levels deep, across many generated
;;; shapes instead of one. Uses :to-equalp (CL EQUALP), not :to-equal (CL
;;; EQUAL) -- EQUAL only compares general vectors/hash-tables by EQ, so it
;;; would accept a completely wrong roundtrip; EQUALP recurses into both.
;;; Deliberately whole-number doubles only, not fractional -- fractional
;;; stringify/parse precision is a different property, already covered by
;;; the fixed 1.5d0 example near the top of this file, and mixing it in here
;;; would risk unrelated floating-point-representation noise in a property
;;; test that's really about STRUCTURE (nesting, arrays-of-objects,
;;; objects-with-arrays), not number formatting.
(defun %json-gen-value ()
  (gen-recursive
    (gen-one-of
      (gen-map (lambda (i) (coerce i 'double-float)) (gen-integer :min -1000 :max 1000))
      (gen-string :min-length 0 :max-length 6 :alphabet "abcXYZ019 ")
      (gen-boolean)
      (gen-member (list cl-cc/javascript::+js-null+)))
    (lambda (self)
      (gen-one-of
        (gen-map (lambda (items) (apply #'cl-cc/javascript::%js-make-array items))
                 (gen-list self :min-length 0 :max-length 4))
        (gen-map
          (lambda (pairs)
            (apply #'cl-cc/javascript::%js-make-object
                   (mapcan (lambda (pair) (list (first pair) (second pair))) pairs)))
          (gen-list
            (gen-tuple (gen-string :min-length 1 :max-length 4 :alphabet "abcXYZ") self)
            :min-length 0 :max-length 4))))
    :max-depth 3))

(it-property "js-rt-json-stringify-parse-roundtrip-property"
    ((value (%json-gen-value)))
  (expect
    (cl-cc/javascript::%js-json-parse (cl-cc/javascript::%js-json-stringify value))
    :to-equalp value))
