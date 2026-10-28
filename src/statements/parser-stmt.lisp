;;;; packages/javascript/src/parser-stmt.lisp — ES2026 JavaScript Parser: Statement Layer
;;;;
;;;; Parses a JavaScript token stream (list of plists) into the common AST.
;;;; Token format: (:type :T-XXX :value val)
;;;;
;;;; Loop lowering uses the block/tagbody/go pattern (same as PHP frontend).
;;;; All loop constructs are lowered at parse time rather than emitting
;;;; symbolic :while/:for calls, because the compiler resolves the pre-built
;;;; AST directly without a macro expansion pass for frontend ASTs.
(in-package #:cl-cc/javascript/statements)

;;; ─── Token Stream Helpers ────────────────────────────────────────────────────
;;; %js-consume-expected and js-skip-semis are in parser-stmt-binding.lisp.
;;; js-tok-type, js-tok-value, js-peek*, js-consume, js-expect, js-at-eof-p,
;;; js-ident-sym, and js-try-consume are defined in parser.lisp (loaded first).
;;; ─── Dynamic Variables for Loop/Switch Control Flow ─────────────────────────
(progn
  (defvar *js-gdi-mode*
    nil)
  (defvar *js-gdi-lower-var-declarations*
    nil)
  (defvar *js-gdi-function-depth*
    0)
  (defvar *js-gdi-lexical-scope-depth*
    0)
  (defvar *js-gdi-collect-global-lexical-bindings*
    nil)
  (defvar *js-gdi-global-lexical-bindings*
    nil)
  (defun %js-gdi-record-global-class (node)
    (when
        (and *js-gdi-collect-global-lexical-bindings*
             (zerop *js-gdi-lexical-scope-depth*)
             (zerop *js-gdi-function-depth*))
      (cond
        ((cl-cc/ast:ast-defclass-p node)
         (push (cons (cl-cc/ast:ast-defclass-name node) :class) *js-gdi-global-lexical-bindings*))
        ((cl-cc/ast:ast-progn-p node)
         (dolist (form (cl-cc/ast:ast-progn-forms node))
           (%js-gdi-record-global-class form)))))
    node)
  (defvar *js-loop-continue-target*
    nil
    "Dynamically bound innermost loop continue target tag (gensym)."))

(defvar *js-loop-break-target*
  nil
  "Dynamically bound innermost loop/switch break target tag (gensym).")
(defvar *js-break-targets*
  nil
  "Stack of break targets for nested loops/switch, innermost first.")

(defvar *js-continue-targets*
  nil
  "Stack of continue targets for nested loops, innermost first.")

(defvar *js-label-break-targets*
  (make-hash-table :test #'equal)
  "Maps JS label name strings to their break target tags (for labeled break).")

(defvar *js-label-continue-targets*
  (make-hash-table :test #'equal)
  "Maps JS label name strings to their continue target tags (for labeled continue).")

(defmacro with-js-loop-tags ((loop-tag end-tag prefix) &body body)
  "Establish the loop-context protocol around BODY for one JS loop form.

Binds LOOP-TAG and END-TAG to fresh gensyms named \"PREFIX-\" and
\"PREFIX-END-\", then rebinds all four loop-control specials from them: the two
innermost-target variables and the two target stacks.  Every loop parser
(while, do-while, for, for-in, for-of) needs exactly this block, and each used
to spell it out; keeping it in one place means a change to the protocol — a new
special, a different stack discipline — cannot be applied to some loops and
forgotten in others. PREFIX may be a literal string or any form evaluating to
one at runtime — it only ever names a gensym for trace readability, so it is
concatenated at runtime rather than required to be a macroexpansion-time
constant, letting one caller share this macro across a family of loops that
picks its own prefix per call (see %js-parse-for-in-of-stmt)."
  `(let* ((,loop-tag (gensym (concatenate 'string ,prefix "-")))
          (,end-tag (gensym (concatenate 'string ,prefix "-END-")))
          (*js-loop-continue-target* ,loop-tag)
          (*js-loop-break-target* ,end-tag)
          (*js-break-targets* (cons ,end-tag *js-break-targets*))
          (*js-continue-targets* (cons ,loop-tag *js-continue-targets*)))
     ,@body))

;;; ─── Statement Dispatcher Table ──────────────────────────────────────────────
;;;
;;; Each define-js-stmt-parser call registers a handler for one token type.
;;; The handler receives STREAM positioned AFTER the keyword token was consumed.
;;; js-parse-stmt consults this table first before falling back to complex cases.
(defvar *js-stmt-parsers*
  (make-hash-table)
  "Maps token type keywords to (lambda (after-keyword-stream)) statement parsers.")

(defmacro define-js-stmt-parser (token-type (stream) &body body)
  "Register a statement parser for TOKEN-TYPE in *js-stmt-parsers*.
  STREAM is positioned AFTER the keyword token; BODY must return (values ast rest)."
  `(setf (gethash ,token-type *js-stmt-parsers*) (lambda (,stream)
                                                   ,@body)))

;;; Simple token-type → parser registrations (consume keyword, parse body)
(define-js-stmt-parser :T-VAR (s) (js-parse-var-decl s :var))

(define-js-stmt-parser :T-LET (s) (js-parse-var-decl s :let))

(define-js-stmt-parser :T-CONST (s) (js-parse-var-decl s :const))

(define-js-stmt-parser :T-FOR (s) (js-parse-for-stmt s))

(define-js-stmt-parser :T-SWITCH (s) (js-parse-switch-stmt s))

;;; ─── Loop Lowering Helpers ───────────────────────────────────────────────────
(defun %js-make-tagbody (items)
  "Build an AST-TAGBODY from a flat list of tags (symbols) and form AST nodes.
  Symbols start new tag sections; AST nodes accumulate under the current tag."
  (let ((tags nil)
        (current-tag nil)
        (current-forms nil))
    (labels ((flush ()
               (when current-tag
                 (push (cons current-tag (nreverse current-forms)) tags))))
      (dolist (item items)
        (if (symbolp item)
            (progn
              (flush)
              (setf current-tag item
                    current-forms nil))
            (progn
              (unless current-tag
                (setf current-tag (gensym "TAGBODY-")))
              (push item current-forms))))
      (flush)
      (make-ast-tagbody :tags (nreverse tags)))))

(defun %js-lower-while-with-tags (cond-expr body loop-tag end-tag)
  "Lower while with caller-supplied LOOP-TAG (continue) and END-TAG (break)."
  (make-ast-block :name
                  nil
                  :body
                  (list
                   (%js-make-tagbody
                    (append
                     (list loop-tag
                           (make-ast-if :cond
                                        cond-expr
                                        :then
                                        (make-ast-quote :value nil)
                                        :else
                                        (make-ast-return-from :name
                                                              nil
                                                              :value
                                                              (make-ast-quote :value nil))))
                     body
                     (list (make-ast-go :tag loop-tag) end-tag))))))

(defun %js-lower-do-while-with-tags (cond-expr body loop-tag end-tag)
  "Lower do{body}while(cond) with caller-supplied LOOP-TAG and END-TAG."
  (make-ast-block :name
                  nil
                  :body
                  (list
                   (%js-make-tagbody
                    (append (list loop-tag)
                            body
                            (list
                             (make-ast-if :cond
                                          cond-expr
                                          :then
                                          (make-ast-go :tag loop-tag)
                                          :else
                                          (make-ast-quote :value nil))
                             end-tag))))))

(defun %js-truthy-call (expr)
  "Wrap EXPR in a %js-truthy coercion call."
  (make-ast-call :func (make-ast-var :name '%js-truthy) :args (list expr)))

;;; ─── Block Parsing ───────────────────────────────────────────────────────────
(progn
  (defun %js-gdi-block-lexical-names (forms)
    (loop for form in forms
          append (cond
                   ((and (cl-cc/ast:ast-let-p form)
                         (intersection (cl-cc/ast:ast-let-declarations form)
                                       '(:let :const)
                                       :test
                                       #'eq)) (mapcar #'car (cl-cc/ast:ast-let-bindings form)))
                   ((cl-cc/ast:ast-defun-p form) (list (cl-cc/ast:ast-defun-name form)))
                   ((cl-cc/ast:ast-defclass-p form) (list (cl-cc/ast:ast-defclass-name form)))
                   (t nil))))
  (defun %js-parse-block-statements (stream)
    (let ((current stream)
          (stmts nil))
      (loop (setf current (js-skip-semis current)) (when
                                                       (or (js-at-eof-p current)
                                                           (eq (js-peek-type current) :T-RBRACE))
                                                     (return)) (multiple-value-bind (stmt rest)
                                                                   (js-parse-stmt current)
                                                                 (when stmt
                                                                   (push stmt stmts))
                                                                 (setf current rest)))
      (multiple-value-bind (_ rest) (js-expect :T-RBRACE current)
        (declare (ignore _))
        (values (nreverse stmts) rest))))
  (defun js-parse-block (stream)
    "Parse { stmt... } and return (values ast-progn rest)."
    (with-js-parse-depth
     (let ((*js-gdi-lexical-scope-depth* (1+ *js-gdi-lexical-scope-depth*))
           (body-stream (%js-consume-expected :T-LBRACE stream)))
       (multiple-value-bind (stmts rest)
           (if cl-cc/javascript/syntax:*js-gdi-global-reference-mode*
               (multiple-value-bind (raw-forms raw-rest)
                   (let ((cl-cc/javascript/syntax:*js-gdi-global-reference-mode* nil))
                     (%js-parse-block-statements body-stream))
                 (declare (ignore raw-rest))
                 (let ((cl-cc/javascript/syntax:*js-gdi-shadowed-names*
                        (append (%js-gdi-block-lexical-names raw-forms)
                                cl-cc/javascript/syntax:*js-gdi-shadowed-names*)))
                   (%js-parse-block-statements body-stream)))
               (%js-parse-block-statements body-stream))
         (values (make-ast-progn :forms (%js-finish-let-bindings stmts)) rest))))))

(defun %js-parse-stmt-body (stream)
  "Parse either a braced block or a single statement.
  Returns (values ast rest)."
  (if (eq (js-peek-type stream) :T-LBRACE)
      (js-parse-block stream)
      (js-parse-stmt stream)))

;;; ─── Variable / Binding Pattern Helpers ─────────────────────────────────────
;;; All binding helpers (%js-binding-sym, %js-parse-binding-pattern, etc.)
;;; and token helpers (%js-consume-expected, js-skip-semis) are in
;;; parser-stmt-binding.lisp (loaded before this file).
;;; ─── Variable Declaration Parsing ───────────────────────────────────────────
(defun js-parse-var-decl (stream kind)
  "Parse var/let/const declarations and return the declaration AST and rest."
  (let ((current stream)
        (binding-chunks nil))
    (loop (multiple-value-bind (binding rest) (%js-parse-binding-pattern current)
            (setf current rest)
            (let ((init-expr
                   (make-ast-quote :value
                                   (if (and *js-gdi-mode*
                                            (zerop *js-gdi-function-depth*)
                                            (eq kind :var))
                                       :js-gdi-no-initializer
                                       :js-undefined))))
              (when
                  (and current
                       (eq (js-peek-type current) :T-OP)
                       (equal (js-peek-value current) "="))
                (setf current (cdr current))
                (multiple-value-bind (expr rest2)
                    (js-call-parser-handler :assignment-expression current)
                  (setf init-expr expr
                        current rest2)))
              (multiple-value-bind (bindings extras)
                  (%js-emit-destructure-bindings binding init-expr)
                (declare (ignore extras))
                (push bindings binding-chunks)))) (if (and current
                                                           (eq (js-peek-type current) :T-COMMA))
                                                      (setf current (cdr current))
                                                      (return)))
    (setf current (js-skip-semis current))
    (let ((all-bindings (apply (function append) (nreverse binding-chunks))))
      (when
          (and *js-gdi-collect-global-lexical-bindings*
               (zerop *js-gdi-lexical-scope-depth*)
               (zerop *js-gdi-function-depth*)
               (member kind (quote (:let :const)) :test (function eq)))
        (dolist (binding all-bindings)
          (let ((name (car binding)))
            (when (and (symbolp name) (eq (symbol-package name) (find-package :cl-cc/javascript)))
              (push (cons name kind) *js-gdi-global-lexical-bindings*)))))
      (values
       (if (and *js-gdi-mode*
                *js-gdi-lower-var-declarations*
                (zerop *js-gdi-function-depth*)
                (eq kind :var))
           (let ((tail nil))
             (dolist (binding (reverse all-bindings))
               (let ((name (car binding))
                     (value (cdr binding)))
                 (if (eq (symbol-package name) (find-package :cl-cc/javascript))
                     (unless
                         (and (cl-cc/ast:ast-quote-p value)
                              (eq (cl-cc/ast:ast-quote-value value) :js-gdi-no-initializer))
                       (setf tail (cons (js-call-parser-handler :gdi-global-write-ast name value)
                                        tail)))
                     (setf tail (list (make-ast-let :bindings (list binding) :body tail))))))
             (if tail
                 (make-ast-progn :forms tail)
                 (make-ast-quote :value :js-undefined)))
           (make-ast-let :bindings all-bindings :body nil :declarations (list kind)))
       current))))

;;; Function declaration + if/while/do-while parsers -> see parser-stmt-fn.lisp
(eval-when (:load-toplevel :execute)
  (register-js-parser-handler :var-declaration (function js-parse-var-decl)))
