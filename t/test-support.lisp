(in-package #:cl-cc-javascript/test)

;;; ─── Shared helpers (used across all runtime-*-test files) ───────────────────

(defun %jr-arr (&rest els)
  "Build a JS array (adjustable vector) from ELS."
  (apply #'cl-cc/javascript::%js-make-array els))

(defun %jr-list (vec)
  "Coerce a JS array (vector) to a CL list for easy comparison."
  (coerce vec 'list))

(defun %jr-set (&rest vals)
  "Build a JS Set from VALS in insertion order."
  (let ((s (cl-cc/javascript::%js-make-set)))
    (dolist (v vals s)
      (cl-cc/javascript::%js-set-add s v))))

(defun %js-parse (src)
  "Parse SRC and return the list of top-level AST nodes."
  (cl-cc/javascript:parse-js-source src))

(defun %js-first (src)
  "Parse SRC and return the first top-level AST node."
  (first (%js-parse src)))

(defun %js-call-name (ast)
  "Return the upcased symbol name for an AST-CALL whose func is an AST-VAR."
  (when (and (cl-cc/ast:ast-call-p ast)
             (cl-cc/ast:ast-var-p (cl-cc/ast:ast-call-func ast)))
    (symbol-name (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func ast)))))
