;;;; packages/javascript/src/parser-module-export.lisp — ES2026 export declaration parser
;;;;
;;;; export default expr/function/class
;;;; export { name, name as alias }
;;;; export { name } from "module"
;;;; export * from "module"
;;;; export * as ns from "module"
;;;; export const/let/var/function/class ...
;;;;
;;;; Needs: %js-lower-import, js-parse-import-specifiers (parser-module.lisp),
;;;;        js-parse-function-stmt, js-parse-class-decl.
;;;; Load order: after parser-module.lisp.

(in-package :cl-cc/javascript)

;;; ─── Export lowering helper ──────────────────────────────────────────────────

(defun %js-export-symbol-name (sym)
  "Return the JS source name represented by parser symbol SYM."
  (when sym
    (symbol-name sym)))

(defun %js-export-public-binding-symbol-p (sym)
  "True when SYM is a source-level JS binding, not a destructuring temp."
  (and (symbolp sym)
       (symbol-package sym)))

(defun %js-export-let-binding-names (decl)
  "Collect source-level binding names from a declaration let AST."
  (remove-duplicates
   (remove nil
           (mapcar (lambda (binding)
                     (let ((sym (car binding)))
                       (when (%js-export-public-binding-symbol-p sym)
                         (%js-export-symbol-name sym))))
                   (ast-let-bindings decl))
           :test #'equal)
   :test #'equal
   :from-end t))

(defun %js-export-declaration-names (decl)
  "Collect the public export names introduced by declaration AST node DECL."
  (cond
    ((ast-defun-p decl)
     (let ((name (%js-export-symbol-name (ast-defun-name decl))))
       (and name (list name))))
    ((ast-defclass-p decl)
     (let ((name (%js-export-symbol-name (ast-defclass-name decl))))
       (and name (list name))))
    ((ast-let-p decl)
     (%js-export-let-binding-names decl))
    (t nil)))

(defun %js-lower-export (kind specifiers-or-decl &optional from-module)
  "Lower an export declaration to an ast-call for %js-export.
KIND is one of :default :named :re-export :star :declaration.
SPECIFIERS-OR-DECL is the specifier list or a declaration AST node.
FROM-MODULE is the re-export source string or NIL."
  (let ((declaration-names (and (eq kind :declaration)
                                (%js-export-declaration-names specifiers-or-decl))))
    (make-ast-call
     :func (make-ast-var :name '%js-export)
     :args (list (make-ast-quote :value kind)
                 (if (or (listp specifiers-or-decl) (null specifiers-or-decl))
                     (make-ast-quote :value specifiers-or-decl)
                     specifiers-or-decl)           ; AST node for declarations
                 (make-ast-quote :value from-module)
                 (make-ast-quote :value declaration-names)))))

;;; ─── Export statement sub-parsers ───────────────────────────────────────────
;;;
;;; Exported declarations reuse the ordinary statement parsers so function
;;; bodies, parameters, destructuring bindings, and initializer expressions keep
;;; the same AST shape as non-exported declarations.

(defun %js-parse-export-function-decl (stream async-p)
  "Parse a function declaration in export context."
  (js-parse-function-decl stream :async-p async-p))

(defun %js-parse-export-lexical-decl (stream kind)
  "Parse const/let/var bindings in export context."
  (js-parse-var-decl stream kind))

;;; ─── js-parse-export-decl: one sub-parser per export form ──────────────────

(defun %js-parse-export-default-form (current)
  "export default function/async function/class/expr — CURRENT points past 'default'."
  (cond
    ;; export default function [name]() {}
    ((eq (js-peek-type current) :T-FUNCTION)
     (multiple-value-bind (defun-ast rest)
         (%js-parse-export-function-decl (cdr current) nil)
       (values (%js-lower-export :default defun-ast) rest)))
    ;; export default async function [name]() {}
    ((and (eq (js-peek-type current) :T-ASYNC)
          (cdr current)
          (eq (js-peek-type (cdr current)) :T-FUNCTION))
     (multiple-value-bind (defun-ast rest)
         (%js-parse-export-function-decl (cddr current) t)
       (values (%js-lower-export :default defun-ast) rest)))
    ;; export default class [Name] {}
    ((eq (js-peek-type current) :T-CLASS)
     (multiple-value-bind (class-nodes rest)
         (js-parse-class-decl (cdr current) :expression-p t)
       (values (%js-lower-export :default (first class-nodes)) rest)))
    ;; export default expr;
    (t
     (multiple-value-bind (expr-ast rest) (js-parse-expr current)
       (values (%js-lower-export :default expr-ast)
               (js-skip-semis rest))))))

(defun %js-parse-export-star-form (current)
  "export * from \"module\" / export * as ns from \"module\" — CURRENT points past '*'."
  (let ((ns-name nil))
    ;; optional: as ns
    (when (and current (eq (js-peek-type current) :T-AS))
      (setf current (cdr current))  ; consume 'as'
      (multiple-value-bind (ns-tok rest) (js-expect :T-IDENT current)
        (setf ns-name (js-tok-value ns-tok)
              current rest)))
    (multiple-value-bind (_ rest) (js-expect :T-FROM current)
      (declare (ignore _))
      (multiple-value-bind (mod-tok rest2) (js-expect :T-STRING rest)
        (values (%js-lower-export :star
                                  (when ns-name (list :namespace ns-name))
                                  (js-tok-value mod-tok))
                (js-skip-semis rest2))))))

(defun %js-parse-export-named-or-reexport-form (current)
  "export { a, b as c } [from \"module\"] — CURRENT points at the '{'."
  (multiple-value-bind (specs rest) (js-parse-export-specifiers current)
    (if (and rest (eq (js-peek-type rest) :T-FROM))
        ;; re-export
        (let ((rest (cdr rest)))  ; consume 'from'
          (multiple-value-bind (mod-tok rest2) (js-expect :T-STRING rest)
            (values (%js-lower-export :re-export specs (js-tok-value mod-tok))
                    (js-skip-semis rest2))))
        ;; local re-export
        (values (%js-lower-export :named specs)
                (js-skip-semis rest)))))

(defun %js-parse-export-lexical-form (current)
  "export const/let/var name [= expr] — CURRENT points at the T-CONST/T-LET/T-VAR token."
  (let ((kind (case (js-peek-type current)
                (:T-CONST :const)
                (:T-LET :let)
                (:T-VAR :var))))
    (multiple-value-bind (decl-ast rest)
        (%js-parse-export-lexical-decl (cdr current) kind)
      (values (%js-lower-export :declaration decl-ast) rest))))

(defun %js-parse-export-function-form (current async-p)
  "export [async] function name() {} — CURRENT points past 'function'."
  (multiple-value-bind (defun-ast rest)
      (%js-parse-export-function-decl current async-p)
    (values (%js-lower-export :declaration defun-ast) rest)))

(defun %js-parse-export-class-form (current)
  "export class Name {} — CURRENT points past 'class'."
  (multiple-value-bind (class-nodes rest)
      (js-parse-class-decl current :expression-p nil)
    (values (%js-lower-export :declaration (first class-nodes)) rest)))

(defun js-parse-export-decl (stream)
  "Parse all export statement forms (the 'export' keyword has already been
consumed by the caller, so STREAM points to the next token).

Forms handled:
  export default expr
  export default function foo() {}
  export default class Foo {}
  export { name, name as alias }
  export { name } from \"module\"
  export * from \"module\"
  export * as ns from \"module\"
  export const/let/var name [= expr]
  export function name() {}
  export async function name() {}
  export class Name {}

Lower to: (ast-call %js-export kind specifiers-or-decl from-module)

Returns (values ast rest)."
  (let ((current stream))
    (cond
      ((eq (js-peek-type current) :T-DEFAULT)
       (%js-parse-export-default-form (cdr current)))
      ((and (eq (js-peek-type current) :T-OP)
            (equal "*" (js-peek-value current)))
       (%js-parse-export-star-form (cdr current)))
      ((eq (js-peek-type current) :T-LBRACE)
       (%js-parse-export-named-or-reexport-form current))
      ((member (js-peek-type current) '(:T-CONST :T-LET :T-VAR))
       (%js-parse-export-lexical-form current))
      ((eq (js-peek-type current) :T-FUNCTION)
       (%js-parse-export-function-form (cdr current) nil))
      ((and (eq (js-peek-type current) :T-ASYNC)
            (cdr current)
            (eq (js-peek-type (cdr current)) :T-FUNCTION))
       (%js-parse-export-function-form (cddr current) t))
      ((eq (js-peek-type current) :T-CLASS)
       (%js-parse-export-class-form (cdr current)))
      (t
       (error "JS parse error: malformed export declaration near ~S"
              (js-peek current))))))
