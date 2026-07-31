;;;; packages/javascript/src/runtime-json.lisp — JSON.stringify / JSON.parse
;;;;
;;;; JSON parsing and serialization delegate to json-kit (nerima-lisp/cl-
;;;; json-kit), an RFC-8259-conformant engine (95/95 JSONTestSuite must-
;;;; accept, 188/188 must-reject) used directly through its own parse/write
;;;; hooks — :null-value/:false-value/:true-value map JS's null/false/true
;;;; straight onto its own value model, and :number-encoder reproduces this
;;;; runtime's existing "integer when whole, ~F otherwise" number formatting
;;;; (json-kit's own default always keeps a float's decimal point, for
;;;; round-trip fidelity between CL's integer and float types — a
;;;; distinction JS numbers don't make). This file supplies only what JSON
;;;; itself has no concept of: JS `undefined`/function/Symbol values (dropped
;;;; from JSON.stringify output — omitted from an object property, become
;;;; `null` in an array, make a top-level call return `undefined` itself
;;;; rather than any string), NaN/Infinity (also `null`), and JSON.rawJSON
;;;; fragment splicing.
;;;;
;;;; Depends on runtime.lisp (%js-typeof, %js-float-nan-p, %js-float-
;;;; infinity-p, JS value constants), runtime-object.lisp
;;;; (%js-internal-key-p), runtime-class.lisp (*js-syntax-error-class*,
;;;; %js-make-error-instance) and runtime-string.lisp
;;;; (%js-string-replace-all) — both referenced here before those files load;
;;;; resolved at call time, the same forward-reference pattern
;;;; runtime-array-es2023.lisp already uses for *js-range-error-class*.
(in-package :cl-cc/javascript)

;;; -----------------------------------------------------------------------
;;;  Raw JSON wrapper (JSON.rawJSON / JSON.isRawJSON, ES2024)
;;; -----------------------------------------------------------------------
(defstruct (js-raw-json (:constructor %js-make-raw-json (text)) (:conc-name js-raw-json-)) text)

(defun %js-json-raw-json-p (val)
  "True when VAL is a JSON.rawJSON wrapper."
  (js-raw-json-p val))

(defun %js-json-raw-json-text (val)
  (js-raw-json-text val))

(defun %js-json-parse-full-p (str)
  "True when STR is valid JSON text with no trailing non-whitespace data
(json-kit:parse itself rejects trailing data, so no separate check is
needed)."
  (and (stringp str)
       (handler-case (progn (parse str) t)
         (json-parse-error () nil))))

(defun %js-json-raw-json (str)
  "Wrap STR as a raw JSON fragment after validating it."
  (unless (%js-json-parse-full-p str)
    (error "JS SyntaxError: invalid JSON.rawJSON text"))
  (%js-make-raw-json str))

(defun %js-json-is-raw-json (val)
  (%js-json-raw-json-p val))

;;; -----------------------------------------------------------------------
;;;  JSON.stringify
;;; -----------------------------------------------------------------------
(defun %js-json-number-encoder (n)
  "json-kit's :number-encoder hook: N formatted the way this runtime always
has — bare digits when N has no fractional part, ~F otherwise — rather than
json-kit's own default of always keeping a float's decimal point."
  (if (= n (floor n))
      (write-to-string (floor n) :base 10 :radix nil)
      (format nil "~F" n)))

(defun %js-json-unrepresentable-p (val)
  "True when VAL has no JSON representation at all — JS `undefined`,
functions, and Symbols are all dropped from JSON.stringify output, never
encoded as any JSON token (JSON.rawJSON wrappers ARE representable — they
splice their own raw text in, handled separately by
%JS-JSON-STRINGIFY-NORMALIZE)."
  (member (%js-typeof val) '("undefined" "function" "symbol") :test #'string=))

(defun %js-json-stringify-normalize (val fragments)
  "Rebuild VAL (a JS value tree) into an equivalent tree JSON-KIT:STRINGIFY
can serialize directly. Each JSON.rawJSON wrapper found is registered as a
(marker . raw-text) pair pushed onto FRAGMENTS (an adjustable vector) and
replaced with a unique marker string — json-kit has no concept of a raw
passthrough leaf, so the marker is swapped back for the real text after
stringification, see %JS-JSON-SPLICE-RAW-FRAGMENTS. NaN/Infinity become
+JS-NULL+ here (JSON has no numeric token for either), same as an
unrepresentable array element; an unrepresentable object property is omitted
entirely, by simply never adding it to the rebuilt hash table below."
  (cond
    ((%js-json-raw-json-p val)
     (let ((marker (symbol-name (gensym "JSON-RAW-FRAGMENT-"))))
       (vector-push-extend (cons marker (%js-json-raw-json-text val)) fragments)
       marker))
    ((or (%js-float-nan-p val) (%js-float-infinity-p val)) +js-null+)
    ((%js-vec-p val)
     (let ((result (make-array (length val))))
       (dotimes (i (length val) result)
         (let ((item (aref val i)))
           (setf (aref result i)
                 (if (%js-json-unrepresentable-p item)
                     +js-null+
                     (%js-json-stringify-normalize item fragments)))))))
    ((%js-ht-p val)
     ;; %JS-OBJECT-OWN-STRING-PROPERTY-KEYS, not a raw MAPHASH: gives the
     ;; correct ES2015+ [[OwnPropertyKeys]] order (array-index keys
     ;; numerically ascending first) and already excludes internal runtime
     ;; keys while translating an accessor's __get_X/__set_X storage key to
     ;; its real property name. %JS-GET-PROP (not a raw GETHASH) then reads
     ;; each value through any getter, exactly like real JSON.stringify's
     ;; own [[Get]] on each own enumerable key -- a plain MAPHASH+GETHASH
     ;; here would both scramble key order and silently omit every
     ;; getter/setter property entirely (its raw stored value is the
     ;; accessor FUNCTION, and its key was `__get_X`, already filtered out
     ;; as an "internal" key rather than recognized as a property).
     (let ((result (%js-make-ht)))
       (loop for k across (%js-object-own-string-property-keys val)
             for v = (%js-get-prop val k)
             unless (%js-json-unrepresentable-p v)
               do (setf (gethash k result) (%js-json-stringify-normalize v fragments)))
       result))
    (t val)))

(defun %js-json-splice-raw-fragments (text fragments)
  "Undo %JS-JSON-STRINGIFY-NORMALIZE's marker substitution: each marker
appears in TEXT as an ordinary JSON-quoted string (JSON-KIT:STRINGIFY had no
idea it meant anything special) — replace that quoted form with the raw
fragment text verbatim."
  (loop for (marker . raw) across fragments
        do (setf text (%js-string-replace-all text (stringify marker) raw)))
  text)

(defun %js-json-stringify (val)
  "JSON.stringify(value). Replacer/space are accepted but ignored by the
caller (JSON.stringify's own binding in runtime-builtins-table-specs.lisp) —
see docs/src/compatibility.md."
  (if (%js-json-unrepresentable-p val)
      +js-undefined+
      (let ((fragments (make-array 0 :adjustable t :fill-pointer 0)))
        (%js-json-splice-raw-fragments
          (stringify (%js-json-stringify-normalize val fragments)
                     :null-value +js-null+ :false-value nil
                     :number-encoder #'%js-json-number-encoder)
          fragments))))

;;; -----------------------------------------------------------------------
;;;  JSON.parse
;;; -----------------------------------------------------------------------
(defun %js-json-parse (str)
  "JSON.parse(text) — full RFC 8259 parsing via json-kit, with JS's own
null/false/true value mapping applied directly through its own parser hooks.
Invalid JSON raises a real JS SyntaxError (the hand-rolled parser this
replaced silently returned `undefined` instead, which is not what JSON.parse
does)."
  (handler-case
      (parse (%js-to-string str) :null-value +js-null+ :false-value nil :true-value t)
    (json-parse-error (e)
      (%js-throw
        (%js-make-error-instance *js-syntax-error-class*
                                  (format nil "Unexpected token in JSON at position ~D"
                                          (json-parse-error-position e)))))))
