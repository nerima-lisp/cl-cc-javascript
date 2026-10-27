;;;; packages/javascript/src/parser-module.lisp — ES2026 JavaScript module parser
;;;;
;;;; Parses ES2026 import and export declarations into the common CL-CC AST.
;;;;
;;;; Import forms supported:
;;;;   import "module"
;;;;   import name from "module"
;;;;   import * as ns from "module"
;;;;   import { a, b as c } from "module"
;;;;   import name, { a, b } from "module"
;;;;   import name, * as ns from "module"
;;;;   import ... with { type: "json" }    (ES2025 import attributes)
;;;;   import(expr)                         (dynamic import — expression level)
;;;;
;;;; Export forms supported:
;;;;   export default expr
;;;;   export default function foo() {}
;;;;   export default class Foo {}
;;;;   export { name, name as alias }
;;;;   export { name } from "module"
;;;;   export * from "module"
;;;;   export * as ns from "module"
;;;;   export const/let/var/function/class ...
;;;;
;;;; AST lowering strategy:
;;;;   All import/export statements lower to ast-call nodes whose :func is
;;;;   ast-var naming %JS-IMPORT or %JS-EXPORT.  The arguments encode the
;;;;   module specifier and the specifier list as quoted data so that the
;;;;   VM's %js-import / %js-export host-bridge functions can interpret them
;;;;   at runtime.  This mirrors how the PHP parser lowers require/include.
(in-package :cl-cc/javascript)

;;; ─── Token stream helpers (re-used from parser-class.lisp) ──────────────────
;;;
;;; js-peek, js-peek-type, js-peek-value, js-consume, js-expect, js-at-eof-p,
;;; js-skip-semis, js-ident-sym are all defined in parser-class.lisp which is
;;; loaded before this file in the ASDF serial component list.
;;; ─── Import-attribute helpers ────────────────────────────────────────────────
(defun %js-parse-import-attributes (stream)
  "Parse an ES2025 import-attributes clause:  with { key: \"value\", ... }
Returns (values attrs-alist rest) where ATTRS-ALIST is an association list
of (string . string) pairs."
  ;; Consume 'with' — represented as a plain :T-IDENT with value \"with\"
  ;; or as :T-WITH, depending on the lexer path.
  (when (and stream
             (or (eq (js-peek-type stream) :T-WITH)
                 (and (eq (js-peek-type stream) :T-IDENT)
                      (equal "with" (js-peek-value stream)))))
    (setf stream (cdr stream))  ; consume 'with'
    (%js-consume-then (rest (js-expect :T-LBRACE stream))
      (let ((attrs nil)
            (current rest))
        (loop until (or (js-at-eof-p current)
                        (eq (js-peek-type current) :T-RBRACE))
              do ;; key: "value"
              (let ((key nil))
                ;; key can be a string or identifier
                (cond
                  ((eq (js-peek-type current) :T-STRING)
                   (multiple-value-bind (tok rest2) (js-consume current)
                     (setf key (js-tok-value tok)
                           current rest2)))
                  ((eq (js-peek-type current) :T-IDENT)
                   (multiple-value-bind (tok rest2) (js-consume current)
                     (setf key (js-tok-value tok)
                           current rest2)))
                  (t
                   (error "JS parse error: expected attribute key, got ~S"
                          (js-peek current))))
                ;; colon
                (%js-consume-then (rest2 (js-expect :T-COLON current))
                  (setf current rest2))
                ;; value (string)
                (multiple-value-bind (val-tok rest2) (js-expect :T-STRING current)
                  (push (cons key (js-tok-value val-tok)) attrs)
                  (setf current rest2)))
              ;; optional trailing comma
              (when (and current (eq (js-peek-type current) :T-COMMA))
                (setf current (cdr current))))
        (%js-consume-then (rest2 (js-expect :T-RBRACE current))
          (return-from %js-parse-import-attributes
            (values (nreverse attrs) rest2))))))
  ;; No 'with' clause
  (values nil stream))

;;; ─── Specifier list parsers ──────────────────────────────────────────────────
;;;
;;; import's `{ a, b as c }' and export's `{ a, b as c }' share the identical
;;; "comma-separated NAME [as ALIAS]" grammar; they differ only in what each
;;; parsed pair is turned into (an :imported/:local plist vs. a :local/:exported
;;; plist, with the "as" default flipped accordingly). CPS-style: the shared
;;; loop consumes/recurses over the token stream and hands each (primary
;;; . alias) pair to a per-caller BUILDER, instead of duplicating the loop.
(defun %js-parse-as-alias-specifiers (stream builder)
  "Parse a `{ name [as alias], ... }' specifier list common to import/export
declarations. STREAM points at the opening '{' (consumed here).  For each
entry, calls (FUNCALL BUILDER primary alias) — ALIAS defaults to PRIMARY when
no `as' clause is present — and collects the results.
Returns (values specifiers rest)."
  (%js-consume-then (rest (js-expect :T-LBRACE stream))
    (let ((specifiers nil)
          (current rest))
      (loop until (or (js-at-eof-p current)
                      (eq (js-peek-type current) :T-RBRACE))
            do (multiple-value-bind (tok rest2) (js-consume current)
                 (let ((primary (js-tok-value tok))
                       (alias nil))
                   (setf current rest2)
                   ;; optional: as alias
                   (if (and current (eq (js-peek-type current) :T-AS))
                       (progn
                         (setf current (cdr current))  ; consume 'as'
                         (multiple-value-bind (tok2 rest3) (js-consume current)
                           (setf alias (js-tok-value tok2)
                                 current rest3)))
                       (setf alias primary))
                   (push (funcall builder primary alias) specifiers))
                 ;; optional trailing comma
                 (when (and current (eq (js-peek-type current) :T-COMMA))
                   (setf current (cdr current)))))
      (%js-consume-then (rest2 (js-expect :T-RBRACE current))
        (values (nreverse specifiers) rest2)))))

(defun js-parse-import-specifiers (stream)
  "Parse a named-imports specifier list:  { a, b as c, ... }
Consumes the enclosing braces.
Returns (values specifiers rest) where SPECIFIERS is a list of plists:
  (:imported \"a\" :local \"a\")
  (:imported \"b\" :local \"c\")"
  (%js-parse-as-alias-specifiers
    stream
    (lambda (imported local)
      (list
        :imported
        (if (stringp imported) imported
          (string-downcase (princ-to-string imported)))
        :local
        (if (stringp local) local
          (string-downcase (princ-to-string local)))))))

(defun js-parse-export-specifiers (stream)
  "Parse a named-exports specifier list:  { a, b as c, ... }
Consumes the enclosing braces.
Returns (values specifiers rest) where SPECIFIERS is a list of plists:
  (:local \"a\" :exported \"a\")
  (:local \"b\" :exported \"c\")"
  (%js-parse-as-alias-specifiers
    stream
    (lambda (local exported)
      (list :local (princ-to-string local) :exported (princ-to-string exported)))))

;;; ─── Import lowering helper ──────────────────────────────────────────────────
(defun %js-lower-import (module-str specifiers attrs)
  "Lower an import declaration to an ast-call for %js-import.
SPECIFIERS is a list of plists or the keywords :default, :namespace, or NIL.
ATTRS is an alist of import attributes (or NIL)."
  (make-ast-call
    :func
    (make-ast-var :name '%js-import)
    :args
    (list
      (make-ast-quote :value module-str)
      (make-ast-quote :value specifiers)
      (make-ast-quote :value attrs))))

;;; ─── js-parse-import-decl ────────────────────────────────────────────────────
;;; ─── js-parse-import-decl: one sub-parser per import form ──────────────────
(defun %js-parse-import-bare-form (current)
  "import \"module\" — bare side-effect import. CURRENT points at the string token."
  (multiple-value-bind (tok rest) (js-consume current)
    (multiple-value-bind (attrs rest2) (%js-parse-import-attributes rest)
      (values (%js-lower-import (js-tok-value tok) nil attrs) (js-skip-semis rest2)))))

(defun %js-parse-import-namespace-form (current)
  "import * as ns from \"module\" — CURRENT points past '*'."
  (%js-consume-then (rest (js-expect :T-AS current))
    (multiple-value-bind (ns-tok rest2) (js-expect :T-IDENT rest)
      (%js-consume-then (rest3 (js-expect :T-FROM rest2))
        (multiple-value-bind (mod-tok rest4) (js-expect :T-STRING rest3)
          (multiple-value-bind (attrs rest5) (%js-parse-import-attributes rest4)
            (values
              (%js-lower-import
                (js-tok-value mod-tok)
                (list (list :namespace (js-tok-value ns-tok)))
                attrs)
              (js-skip-semis rest5))))))))

(defun %js-parse-import-named-form (current)
  "import { a, b as c } from \"module\" — CURRENT points at the '{'."
  (multiple-value-bind (specifiers rest) (js-parse-import-specifiers current)
    (%js-consume-then (rest2 (js-expect :T-FROM rest))
      (multiple-value-bind (mod-tok rest3) (js-expect :T-STRING rest2)
        (multiple-value-bind (attrs rest4) (%js-parse-import-attributes rest3)
          (values
            (%js-lower-import (js-tok-value mod-tok) specifiers attrs)
            (js-skip-semis rest4)))))))

(defun %js-parse-import-default-and-namespace-form (current default-spec)
  "import name, * as ns from \"module\" — CURRENT points past the comma and '*'."
  (%js-consume-then (rest (js-expect :T-AS current))
    (multiple-value-bind (ns-tok rest2) (js-expect :T-IDENT rest)
      (%js-consume-then (rest3 (js-expect :T-FROM rest2))
        (multiple-value-bind (mod-tok rest4) (js-expect :T-STRING rest3)
          (multiple-value-bind (attrs rest5) (%js-parse-import-attributes rest4)
            (values
              (%js-lower-import
                (js-tok-value mod-tok)
                (list default-spec (list :namespace (js-tok-value ns-tok)))
                attrs)
              (js-skip-semis rest5))))))))

(defun %js-parse-import-default-and-named-form (current default-spec)
  "import name, { a, b } from \"module\" — CURRENT points past the comma, at '{'."
  (multiple-value-bind (named-specs rest) (js-parse-import-specifiers current)
    (%js-consume-then (rest2 (js-expect :T-FROM rest))
      (multiple-value-bind (mod-tok rest3) (js-expect :T-STRING rest2)
        (multiple-value-bind (attrs rest4) (%js-parse-import-attributes rest3)
          (values
            (%js-lower-import (js-tok-value mod-tok) (cons default-spec named-specs) attrs)
            (js-skip-semis rest4)))))))

(defun %js-parse-import-default-only-form (current default-spec)
  "import name from \"module\" — CURRENT points past the default identifier."
  (%js-consume-then (rest (js-expect :T-FROM current))
    (multiple-value-bind (mod-tok rest2) (js-expect :T-STRING rest)
      (multiple-value-bind (attrs rest3) (%js-parse-import-attributes rest2)
        (values
          (%js-lower-import (js-tok-value mod-tok) (list default-spec) attrs)
          (js-skip-semis rest3))))))

(defun %js-parse-import-default-form (current)
  "import name ... — CURRENT points at the default-binding identifier. Covers
import name from \"module\", import name, { a } from \"module\", and
import name, * as ns from \"module\"."
  (multiple-value-bind (default-tok rest) (js-consume current)
    (let ((default-spec (list :default (js-tok-value default-tok))))
      (if (and rest (eq (js-peek-type rest) :T-COMMA)) (let ((after-comma (cdr rest)))
          (cond
            ((and
                (eq (js-peek-type after-comma) :T-OP)
                (equal "*" (js-peek-value after-comma)))
              (%js-parse-import-default-and-namespace-form (cdr after-comma) default-spec))
            ((eq (js-peek-type after-comma) :T-LBRACE)
              (%js-parse-import-default-and-named-form after-comma default-spec))
            (t (error "JS parse error: expected { or * after import default and comma"))))
        (%js-parse-import-default-only-form rest default-spec)))))

(defun js-parse-import-decl (stream)
  "Parse all import statement forms (the 'import' keyword has already been
consumed by the caller, so STREAM points to the next token).

Forms handled:
  import \"module\"
  import name from \"module\"
  import * as ns from \"module\"
  import { a, b as c } from \"module\"
  import name, { a, b } from \"module\"
  import name, * as ns from \"module\"
  import ... with { type: \"json\" }   (ES2025 import attributes)

Lower to: (ast-call %js-import module specifiers attrs)

Returns (values ast rest)."
  (let ((current stream))
    (cond
      ((eq (js-peek-type current) :T-STRING) (%js-parse-import-bare-form current))
      ((and (eq (js-peek-type current) :T-OP) (equal "*" (js-peek-value current)))
        (%js-parse-import-namespace-form (cdr current)))
      ((eq (js-peek-type current) :T-LBRACE) (%js-parse-import-named-form current))
      ((eq (js-peek-type current) :T-IDENT) (%js-parse-import-default-form current))
      (t
        (error "JS parse error: malformed import declaration near ~S" (js-peek current))))))

;;; Export declarations → see parser-module-export.lisp
