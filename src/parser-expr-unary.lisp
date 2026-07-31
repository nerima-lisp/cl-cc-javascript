;;;; packages/javascript/src/parser-expr-unary.lisp — Template literals and unary operators
;;;;
;;;; Contains: %js-template-parts-and-rest, %js-parse-tagged-template,
;;;; %js-parse-template-literal, *js-unary-op-builders*, *js-unary-kw-builders*,
;;;; js-parse-unary.
;;;;
;;;; Load order: after parser-expr-postfix.lisp (needs js-parse-postfix,
;;;; %js-place-get-prop-p, %js-lower-place-incdec).
;;;; js-parse-primary is forward-referenced (defined in parser-expr-primary.lisp).
(in-package :cl-cc/javascript)

;;; ─── Template Literal ────────────────────────────────────────────────────────
(defun %js-template-parts-and-rest (stream)
  "Return (values PARTS rest) for a template literal at STREAM."
  (let ((tok (js-peek stream)))
    (case (js-tok-type tok)
      (:T-STRING
        (multiple-value-bind (str-tok rest) (js-consume stream)
          (values (list (js-tok-value str-tok)) rest)))
      (:T-TEMPLATE-PARTS
        (multiple-value-bind (parts-tok rest) (js-consume stream)
          (values (js-tok-value parts-tok) rest)))
      (:T-TEMPLATE-START
        (multiple-value-bind (tok2 rest) (js-consume stream)
          (declare (ignore tok2))
          (%js-template-parts-and-rest rest)))
      (t (error "JS parse error: expected template literal, got ~S" tok)))))

(defun %js-parse-tagged-template (tag-ast stream)
  "Lower a tagged template tag`...` to
(call TAG (%js-make-tagged-template-strings cooked-array raw-array) value1 value2 ...),
per the TC39 tagged-template protocol -- the tag function's first argument
carries both the escapes-processed COOKED strings (ordinary array access,
`strings[0]`) and, via its `.raw` property, the as-written RAW strings
(`strings.raw[0]`), which String.raw and any other raw-reading tag function
need. Text parts are (:text cooked raw); unlike the plain (non-tagged)
template literal path, per-part cooked/raw text here must stay 1:1 with the
lexer's own PARTS boundaries (not merged across parts the way consecutive
literal text is elsewhere) since TC39 defines each array ELEMENT as one
lexer segment, not one concatenated run."
  (multiple-value-bind (parts rest) (%js-template-parts-and-rest stream)
    (let ((cooked nil)
          (raw nil)
          (values nil))
      (dolist (part parts)
        (cond
          ((and (consp part) (eq (car part) :text))
           (push (make-ast-quote :value (second part)) cooked)
           (push (make-ast-quote :value (third part)) raw))
          ((and (consp part) (eq (car part) :template-expr))
           (multiple-value-bind (expr _r) (js-parse-assignment-expr (cadr part))
             (declare (ignore _r))
             (push expr values)))))
      (values
        (make-ast-call
          :func
          tag-ast
          :args
          (cons
            (%js-call
              '%js-make-tagged-template-strings
              (apply #'%js-call '%js-make-array (nreverse cooked))
              (apply #'%js-call '%js-make-array (nreverse raw)))
            (nreverse values)))
        rest))))

(defun %js-parse-template-literal (stream)
  "Parse a template literal starting at :T-TEMPLATE-START or :T-STRING.
Returns (values ast rest)."
  (let ((tok (js-peek stream)))
    (cond
      ;; Simple string template (no interpolation)
      ((eq (js-tok-type tok) :T-STRING)
       (multiple-value-bind (str-tok rest) (js-consume stream)
         (values (make-ast-quote :value (js-tok-value str-tok)) rest)))
      ;; Template with parts: :T-TEMPLATE-PARTS
      ((eq (js-tok-type tok) :T-TEMPLATE-PARTS)
       (multiple-value-bind (parts-tok rest) (js-consume stream)
         (let ((parts (js-tok-value parts-tok))
               (segments nil))
           (dolist (part parts)
             (cond
               ((and (consp part) (eq (car part) :text))
                (push (make-ast-quote :value (second part)) segments))
               ((and (consp part) (eq (car part) :template-expr))
                (let ((inner-tokens (cadr part)))
                  (multiple-value-bind (expr _rest)
                      (js-parse-assignment-expr inner-tokens)
                    (declare (ignore _rest))
                    (push (%js-call '%js-to-string expr) segments))))))
           (let ((parts-list (nreverse segments)))
             (values (if (cdr parts-list) (reduce (lambda (l r) (%js-call '%js-add l r))
                                 parts-list) (car parts-list))
                     rest)))))
      ;; :T-TEMPLATE-START — consumed by the template lexer inline
      ((eq (js-tok-type tok) :T-TEMPLATE-START)
       (multiple-value-bind (tok2 rest) (js-consume stream)
         (declare (ignore tok2))
         (%js-parse-template-literal rest)))
      (t
       (error "JS parse error: expected template literal, got ~S" tok)))))

;;; ─── Unary ───────────────────────────────────────────────────────────────────
;;;
;;; Data-driven dispatch for simple OP-string and keyword unary operators.
;;; Prefix ++/--, unary -, and yield have special logic and are handled explicitly.
;;; OP-string unaries: maps operator string -> (lambda (expr) -> ast).
;;; Excludes - (constant folding), ++ and -- (place/var dispatch).
(define-builder-table
  *js-unary-op-builders*
  (:documentation
    "Data table: JS unary OP string -> AST builder (lambda (expr) -> ast).
Only for simple single-argument operators; -, ++, --, yield handled separately.")
  ("!"
    (lambda (expr)
      (%js-not (%js-call '%js-truthy expr))))
  ("~"
    (lambda (expr)
      (%js-call '%js-bitwise-not expr)))
  ("+"
    (lambda (expr)
      (%js-call '%js-unary-plus expr))))

;;; Keyword unaries: maps token type -> (lambda (expr) -> ast).
;;; typeof/void/delete/await all follow the same consume-one-token pattern.
(define-builder-table
  *js-unary-kw-builders*
  (:test
    #'eq
    :documentation
    "Data table: keyword unary token type -> AST builder (lambda (expr) -> ast).
typeof/void/delete/await all consume one token and wrap the sub-expression.")
  (:T-TYPEOF
    (lambda (expr)
      (%js-call '%js-typeof expr)))
  (:T-DELETE
    (lambda (expr)
      (%js-call '%js-delete expr)))
  (:T-AWAIT
    (lambda (expr)
      (%js-call '%js-await expr)))
  (:T-VOID
    (lambda (expr)
      (make-ast-progn :forms (list expr (make-ast-quote :value :js-undefined))))))

(defun %js-parse-yield-expr (stream)
  "Parse 'yield', 'yield expr', or 'yield* expr'. STREAM points at the yield
token itself. Shared by prefix-unary parsing (js-parse-unary) and primary
parsing (js-parse-primary in parser-expr-primary.lisp), which each reach a
bare/leading `yield' through a different dispatch path.
Returns (values ast rest)."
  (multiple-value-bind (tok rest) (js-consume stream)
    (declare (ignore tok))
    ;; yield* iterable
    (if (and (eq (js-peek-type rest) :T-OP) (string= (js-peek-value rest) "*"))
        (multiple-value-bind (tok2 rest2) (js-consume rest)
          (declare (ignore tok2))
          (multiple-value-bind (expr rest3) (js-parse-assignment-expr rest2)
            (values (%js-call '%js-yield-from expr) rest3)))
        ;; yield expr or bare yield
        (if (or (js-at-eof-p rest)
                (member (js-peek-type rest)
                        '(:T-SEMI :T-COMMA :T-RBRACE :T-RPAREN :T-RBRACKET) :test #'eq))
            (values (%js-call '%js-yield) rest)
            (multiple-value-bind (expr rest2) (js-parse-assignment-expr rest)
              (values (%js-call '%js-yield expr) rest2))))))

(defun js-parse-unary (stream)
  "Parse prefix unary: ! ~ + - ++ -- typeof void delete await yield.
Returns (values ast rest)."
  (let ((type (js-peek-type stream))
        (val  (js-peek-value stream)))
    ;; CPS helper: consume one token, recurse into sub-expression, apply BUILDER.
    (labels ((consume-and-build (builder)
               (multiple-value-bind (tok rest) (js-consume stream)
                 (declare (ignore tok))
                 (multiple-value-bind (expr rest2) (js-parse-unary rest)
                   (values (funcall builder expr) rest2)))))
      (cond
        ;; Table-driven: simple OP-string unary operators (!, ~, +)
        ((and (eq type :T-OP) (gethash val *js-unary-op-builders*))
         (consume-and-build (gethash val *js-unary-op-builders*)))
        ;; Unary - : constant-fold integer literals, else negate
        ((and (eq type :T-OP) (string= val "-"))
         (multiple-value-bind (tok rest) (js-consume stream)
           (declare (ignore tok))
           (multiple-value-bind (expr rest2) (js-parse-unary rest)
             (if (ast-int-p expr)
                 (values (make-ast-int :value (- (ast-int-value expr))) rest2)
                 (values (make-ast-call :func (make-ast-var :name '-)
                                        :args (list expr))
                         rest2)))))
        ;; Table-driven: keyword unary operators (typeof, void, delete, await)
        ((gethash type *js-unary-kw-builders*)
         (consume-and-build (gethash type *js-unary-kw-builders*)))
        ;; Prefix ++ (var or place)
        ((and (eq type :T-OP) (string= val "++"))
         (multiple-value-bind (tok rest) (js-consume stream)
           (declare (ignore tok))
           (multiple-value-bind (expr rest2) (js-parse-unary rest)
             (values (%js-lower-incdec expr '+ t '%js-prefix-inc) rest2))))
        ;; Prefix -- (var or place)
        ((and (eq type :T-OP) (string= val "--"))
         (multiple-value-bind (tok rest) (js-consume stream)
           (declare (ignore tok))
           (multiple-value-bind (expr rest2) (js-parse-unary rest)
             (values (%js-lower-incdec expr '- t '%js-prefix-dec) rest2))))
        ;; yield (prefix usage)
        ((eq type :T-YIELD)
         (%js-parse-yield-expr stream))
        ;; Fall through to postfix
        (t
         (multiple-value-bind (ast rest) (js-parse-primary stream)
           (js-parse-postfix ast rest)))))))
