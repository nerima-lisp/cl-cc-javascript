;;;; packages/javascript/src/runtime-builtins-prelude.lisp — JS program prelude builder
;;;;
;;;; *js-prelude-global-specs*: declarative table of globals injected before every
;;;; compiled JS program. %js-prelude-form emits one AST defvar per entry.
;;;; js-program-forms: main entry point — parse JS source + prepend prelude.
;;;;
;;;; Load order: after runtime-builtins-table.lisp (needs *js-builtin-specs*,
;;;; %js-builtin-ref, and all the %js-make-* / *js-* symbols).
(in-package #:cl-cc/javascript/backend)

;;; -----------------------------------------------------------------------
;;;  JS program prelude — declarative global binding table
;;; -----------------------------------------------------------------------
;;;
;;; Each entry is (kind js-name cl-symbol-or-value):
;;;   :call      — AST call  (cl-symbol &rest no-args)    e.g. (%js-make-console)
;;;   :var       — AST var   cl-symbol                     e.g. *js-error-class*
;;;   :function  — AST function reference                  e.g. %js-parse-int
;;;   :namespace — namespace object built from the builtin dispatch table
;;;   :quote     — AST quote of cl-symbol-or-value         e.g. :js-undefined
;;;   :builtin   — %js-builtin-ref lookup by key string     e.g. "Set"
;;;
;;; Add new globals here; js-program-forms consumes this table automatically.
(defparameter *js-prelude-global-specs*
  '((:call      "console"             %js-make-console)
    (:var        "Symbol"              *js-symbol-global*)
    (:quote      "undefined"           :js-undefined)
    (:var        "Infinity"            *js-inf-float*)
    (:var        "NaN"                 *js-nan-float*)
    (:var        "Date"                *js-date-global*)
    ;; Namespace objects — built from *js-builtin-specs* entries whose key is PREFIX.PROP
    (:namespace  "JSON"                "JSON")
    (:namespace  "Math"                "Math")
    (:namespace  "Object"              "Object")
    (:namespace  "Reflect"             "Reflect")
    (:namespace  "Number"              "Number")
    (:namespace  "Array"               "Array")
    (:namespace  "String"              "String")
    (:namespace  "Promise"             "Promise")
    (:namespace  "Iterator"            "Iterator")
    (:namespace  "Intl"                "Intl")
    (:call "globalThis" %js-gdi-global-object)
    (:var        "Temporal"            *js-temporal-global*)
    (:var        "BigInt"              *js-bigint-global*)
    ;; URI helpers
    (:function   "encodeURIComponent"  %js-encode-uri-component)
    (:function   "decodeURIComponent"  %js-decode-uri-component)
    (:function   "encodeURI"           %js-encode-uri)
    (:function   "decodeURI"           %js-decode-uri)
    (:function   "btoa"                %js-btoa)
    (:function   "atob"                %js-atob)
    ;; Error class hierarchy
    (:var        "Error"               *js-error-class*)
    (:var        "TypeError"           *js-type-error-class*)
    (:var        "RangeError"          *js-range-error-class*)
    (:var        "ReferenceError"      *js-reference-error-class*)
    (:var        "SyntaxError"         *js-syntax-error-class*)
    (:var        "AggregateError"      *js-aggregate-error-class*)
    (:var        "EvalError"           *js-eval-error-class*)
    (:var        "URIError"            *js-uri-error-class*)
    ;; Collection constructors
    ;; Map/WeakMap/WeakSet/RegExp are defparameter vars, not defun symbols,
    ;; so (boundp sym) = t and seed-js-runtime-globals seeds them into the VM.
    (:var        "Map"                 *js-map-global*)
    (:var        "WeakMap"             *js-weak-map-global*)
    (:var        "WeakSet"             *js-weak-set-global*)
    (:var        "RegExp"              *js-regexp-global*)
    ;; Set/timer globals are inline lambdas with no dedicated %js-* symbol;
    ;; look them up via %js-builtin-ref so they stay in sync with *js-builtin-specs*.
    (:builtin    "Set"                 "Set")
    (:builtin    "AbortController"     "AbortController")
    (:builtin    "AbortSignal"         "AbortSignal")
    (:builtin    "Int8Array"           "Int8Array")
    (:builtin    "Uint8Array"          "Uint8Array")
    (:builtin    "Uint8ClampedArray"   "Uint8ClampedArray")
    (:builtin    "Int16Array"          "Int16Array")
    (:builtin    "Uint16Array"         "Uint16Array")
    (:builtin    "Int32Array"          "Int32Array")
    (:builtin    "Uint32Array"         "Uint32Array")
    (:builtin    "Float16Array"        "Float16Array")
    (:builtin    "Float32Array"        "Float32Array")
    (:builtin    "Float64Array"        "Float64Array")
    (:builtin    "BigInt64Array"       "BigInt64Array")
    (:builtin    "BigUint64Array"      "BigUint64Array")
    ;; Numeric parsing globals
    (:function   "parseInt"            %js-parse-int)
    (:function   "parseFloat"          %js-parse-float)
    (:function   "isNaN"               %js-is-nan)
    (:function   "isFinite"            %js-is-finite)
    ;; Standalone global builtins — bound via %js-builtin-ref (inline lambdas)
    (:builtin    "structuredClone"     "structuredClone")
    (:builtin    "queueMicrotask"      "queueMicrotask")
    (:builtin    "Atomics"             "Atomics")
    (:builtin    "crypto"              "crypto"))
  "Declarative prelude table: (kind js-name cl-symbol) emitted as defvar AST nodes
before every compiled JS program so standard globals are available.")

(defun %js-prelude-form (spec)
  "Emit a prelude AST declaration for one entry in *js-prelude-global-specs*."
  (destructuring-bind (kind js-name cl-sym) spec
    (make-ast-defvar :name
                     (js-ident-sym js-name)
                     :kind
                     (if (equal js-name "globalThis")
                         (quote defvar)
                         (quote defparameter))
                     :value
                     (ecase kind
                       (:call (%js-call cl-sym))
                       (:var (make-ast-var :name cl-sym))
                       (:function (make-ast-function :name cl-sym))
                       (:namespace
                        (%js-call (quote %js-make-namespace-object) (make-ast-quote :value cl-sym)))
                       (:quote (make-ast-quote :value cl-sym))
                       (:builtin (%js-call (quote %js-builtin-ref) (make-ast-quote :value cl-sym)))))))

(defun %js-gdi-build-script-forms (source)
  (multiple-value-bind (raw lexical-bindings)
      (let ((cl-cc/javascript/statements:*js-gdi-mode* t)
            (cl-cc/javascript/statements:*js-gdi-lower-var-declarations* nil)
            (cl-cc/javascript/statements:*js-gdi-lexical-scope-depth* 0)
            (cl-cc/javascript/statements:*js-gdi-collect-global-lexical-bindings* t)
            (cl-cc/javascript/statements:*js-gdi-global-lexical-bindings* nil)
            (cl-cc/javascript/syntax:*js-gdi-global-reference-mode* nil))
        (values (parse-js-source source)
                (nreverse cl-cc/javascript/statements:*js-gdi-global-lexical-bindings*)))
    (let* ((var-names (%js-gdi-var-names raw))
           (functions (%js-gdi-selected-functions raw))
           (function-names (mapcar (function cl-cc/ast:ast-defun-name) functions))
           (all-var-names (%js-gdi-unique-names (append var-names function-names)))
           (forms
            (let ((cl-cc/javascript/statements:*js-gdi-mode* t)
                  (cl-cc/javascript/statements:*js-gdi-lower-var-declarations* t)
                  (cl-cc/javascript/statements:*js-gdi-collect-global-lexical-bindings* nil)
                  (cl-cc/javascript/syntax:*js-gdi-global-reference-mode* t)
                  (cl-cc/javascript/syntax:*js-gdi-global-lexical-names*
                   (mapcar (function car) lexical-bindings))
                  (cl-cc/javascript/syntax:*js-gdi-global-var-names* all-var-names)
                  (cl-cc/javascript/syntax:*js-gdi-shadowed-names* nil))
              (parse-js-source source)))
           (selected-functions (%js-gdi-selected-functions forms))
           (selected-names (mapcar (function cl-cc/ast:ast-defun-name) selected-functions))
           (preflight
            (%js-call (quote %js-gdi-prepare)
                      (make-ast-quote :value lexical-bindings)
                      (make-ast-quote :value selected-names)
                      (make-ast-quote :value var-names)))
           (declare-vars
            (mapcar
             (lambda (name)
               (make-ast-defvar :name name :kind (quote defvar) :value nil))
             all-var-names))
           (initialize-functions
            (%js-call (quote %js-gdi-create-global-functions)
                      (make-ast-quote :value (%js-gdi-function-metadata selected-functions))))
           (create-vars
            (%js-call (quote %js-gdi-create-global-vars)
                      (make-ast-quote :value var-names)
                      (make-ast-quote :value selected-names)))
           (body
            (loop for form in forms
                  append (cond
                           ((cl-cc/ast:ast-defun-p form) nil)
                           ((and (cl-cc/ast:ast-let-p form)
                                 (member :var (cl-cc/ast:ast-let-declarations form)))
                            (list (%js-gdi-lower-declaration form :var)))
                           ((and (cl-cc/ast:ast-let-p form)
                                 (null (cl-cc/ast:ast-let-body form))
                                 (intersection (cl-cc/ast:ast-let-declarations form)
                                               (quote (:let :const))
                                               :test
                                               (function eq)))
                            (list
                             (%js-gdi-lower-declaration form
                                                        (if (member :const
                                                                    (cl-cc/ast:ast-let-declarations
                                                                     form))
                                                            :const
                                                            :let))))
                           ((cl-cc/ast:ast-defclass-p form) (%js-gdi-lower-class form))
                           (t (list form))))))
      (append (mapcar (function %js-prelude-form) *js-prelude-global-specs*)
              (list
               (%js-call (quote %js-gdi-initialize-prelude-global-properties)
                         (make-ast-quote :value
                                         (mapcar
                                          (lambda (spec)
                                            (js-ident-sym (second spec)))
                                          *js-prelude-global-specs*)))
               preflight)
              declare-vars
              selected-functions
              (list initialize-functions create-vars)
              body))))

(defun js-program-forms (source)
  "Parse a JavaScript script, instantiate its global declarations, then execute its body."
  (%js-gdi-build-script-forms source))
