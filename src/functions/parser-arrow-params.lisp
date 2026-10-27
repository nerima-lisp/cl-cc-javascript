(in-package #:cl-cc/javascript/functions)

;;; ─── Parenthesized Expression / Arrow Function ───────────────────────────────
(defun %js-call-callee-name (ast)
  "If AST is (ast-call (ast-var NAME) …), return NAME; else NIL."
  (when (and (ast-call-p ast) (ast-var-p (ast-call-func ast)))
    (ast-var-name (ast-call-func ast))))

(defun %js-spread-array-elements (expr)
  "If EXPR is the spread lowering of an array literal — (apply #'%js-make-array
(append (list e1) (%js-spread r) …)) — return the original element ASTs (a plain
element, or a (%js-spread …) marker for ...rest), else NIL.  Reverses
%js-spread-list-expr so [a,...r] arrow params can be recovered."
  (when (and (ast-apply-p expr) (eq (ast-apply-func expr) '%js-make-array))
    (let ((append-call (first (ast-apply-args expr))))
      (when (eq (%js-call-callee-name append-call) 'append)
        (mapcar (lambda (item)
                  (if (%js-spread-marker-p item)
                      item                              ; keep ...rest marker
                      (first (ast-call-args item))))    ; (list e) -> e
                (ast-call-args append-call))))))

(defun %js-object-fold-fields (expr)
  "Recover object-pattern fields from the spread-fold lowering of {…, ...rest}:
a left-nested chain of (%js-object-spread-set acc key val) / (%js-object-assign
acc src) over (%js-make-object).  Returns the fields in source order
((key local nil) … (:rest sym)), or :fail if EXPR is not such a chain."
  (let ((callee (%js-call-callee-name expr)))
    (cond
      ((eq callee '%js-make-object) nil)
      ((member callee '(%js-object-spread-set %js-object-assign))
        (let* ((args (ast-call-args expr))
               (prefix (%js-object-fold-fields (first args))))
          (if (eq prefix :fail) :fail
            (append
              prefix
              (list
                (if (eq callee '%js-object-spread-set) (list
                    (and (ast-quote-p (second args)) (ast-quote-value (second args)))
                    (%js-expr-to-binding-pattern (third args))
                    nil)
                  (list :rest (%js-expr-to-binding-pattern (second args)))))))))
      (t :fail))))

(defun %js-expr-to-binding-pattern (expr)
  "Convert an arrow CoverGrammar parameter EXPR — already parsed as an expression
— into a destructuring binding pattern for %js-emit-destructure-bindings, or NIL
if EXPR is not a pattern.  A plain var becomes its symbol; an array literal
(%js-make-array …, or its (apply #'%js-make-array (append …)) spread form) becomes
an :array-pattern (holes/spread/nesting preserved); an object literal
(%js-make-object k v …, or its spread-fold chain) becomes an :object-pattern.
This is how ([a,b])=>…, ([a,...r])=>… and ({x,...rest})=>… recover their patterns,
since the paren contents were parsed as a literal before the => was seen."
  (cond
    ((ast-var-p expr) (ast-var-name expr))
    ;; array literal, with or without spread
    ((or (eq (%js-call-callee-name expr) '%js-make-array)
         (and (ast-apply-p expr) (eq (ast-apply-func expr) '%js-make-array)))
     (let ((els (if (ast-apply-p expr)
                    (%js-spread-array-elements expr)
                    (ast-call-args expr))))
       (list :array-pattern (gensym "ARR-DEST-")
             (mapcar
              (lambda (el)
                (cond
                  ((and (ast-quote-p el) (eq (ast-quote-value el) :js-hole)) :hole)
                  ((%js-spread-marker-p el)
                   (list :rest (%js-expr-to-binding-pattern (first (ast-call-args el)))))
                  (t (%js-expr-to-binding-pattern el))))
              els))))
    ;; object literal without spread
    ((eq (%js-call-callee-name expr) '%js-make-object)
     (list :object-pattern (gensym "OBJ-DEST-")
           (loop for (k v) on (ast-call-args expr) by #'cddr
                 collect (list (and (ast-quote-p k) (ast-quote-value k))
                               (%js-expr-to-binding-pattern v)
                               nil))))
    ;; object literal with spread (...rest) — recovered from the fold chain
    ((member (%js-call-callee-name expr) '(%js-object-spread-set %js-object-assign))
     (let ((fields (%js-object-fold-fields expr)))
       (unless (eq fields :fail)
         (list :object-pattern (gensym "OBJ-DEST-") fields))))
    (t nil)))
