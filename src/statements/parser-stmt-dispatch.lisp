;;;; packages/javascript/src/parser-stmt-dispatch.lisp — JS statement dispatcher
;;;;
;;;; Main statement dispatcher and statement-list parser.
;;;;
;;;; Load order: after parser-stmt-flow.lisp.

(in-package #:cl-cc/javascript/statements)

;;; ─── Main Statement Dispatcher ───────────────────────────────────────────────
;;;
;;; Consults *js-stmt-parsers* for simple token-type dispatch. Complex cases
;;; requiring lookahead or multi-step processing are handled inline.

(defun js-parse-stmt (stream)
  "Main statement dispatcher. Returns (values ast rest)."
  (setf stream (js-skip-semis stream))
  (when (js-at-eof-p stream)
    (return-from js-parse-stmt (values nil stream)))
  (let ((type  (js-peek-type  stream))
        (value (js-peek-value stream)))
    (cond
      ;; Braced block — not in table (no keyword to consume before block)
      ((eq type :T-LBRACE)
       (js-parse-block stream))
      ;; async function / async arrow — requires 2-token lookahead
      ((and (eq type :T-ASYNC)
            (eq (js-peek-type (cdr stream)) :T-FUNCTION))
       (js-call-parser-handler :statement-async-function (cddr stream)))
      ;; decorated class declaration — requires parsing decorators first
      ((eq type :T-AT)
       (js-call-parser-handler :statement-decorated-class stream))
      ;; using x = expr (ES2025 contextual keyword) — requires ident lookahead
      ((and (eq type :T-USING)
            (eq (js-peek-type (cdr stream)) :T-IDENT))
       (js-call-parser-handler (list :statement :T-USING) (cdr stream)))
      ;; import(...) and import.meta are expressions even at statement start.
      ;; Other leading import forms remain module import declarations.
      ((and (eq type :T-IMPORT)
            (member (js-peek-type (cdr stream)) '(:T-LPAREN :T-DOT)))
       (multiple-value-bind (expr rest) (js-call-parser-handler :expression stream)
         (values expr (js-skip-semis rest))))
      ;; Labelled statement: ident : stmt — requires colon lookahead
      ;; break LABEL → (return-from label-block); continue LABEL → (go continue-tag)
      ((and (eq type :T-IDENT)
            (eq (js-peek-type (cdr stream)) :T-COLON))
       (let* ((label-name (if (stringp value) value (string-downcase (symbol-name value))))
              (label-block (intern (concatenate 'string "JS-LABEL-" label-name) :keyword))
              (label-continue-tag (gensym (concatenate 'string "LABEL-" label-name "-CONTINUE-")))
              (rest (cddr stream)))
         ;; Register this label's break target (the block exit) so `break LABEL`
         ;; can emit (return-from label-block). Register a continue tag too for
         ;; `continue LABEL` inside nested loops.
         (setf (gethash label-name *js-label-break-targets*) label-block
               (gethash label-name *js-label-continue-targets*) label-continue-tag)
         (unwind-protect
             (multiple-value-bind (stmt rest2) (js-parse-stmt rest)
               (values (make-ast-block
                        :name label-block
                        :body (list stmt))
                       rest2))
           (remhash label-name *js-label-break-targets*)
           (remhash label-name *js-label-continue-targets*))))
      ;; Table-driven dispatch: token-type → registered parser
      (t
       (let ((parser (or (gethash type *js-stmt-parsers*)
                          (js-parser-handler (list :statement type)))))
         (if parser
             (funcall parser (cdr stream))    ; pass stream after keyword
             ;; Expression statement (assignments, calls, etc.)
             (multiple-value-bind (expr rest) (js-call-parser-handler :expression stream)
               (values expr (js-skip-semis rest)))))))))

;;; ─── Top-Level Statement List Parser ────────────────────────────────────────

(defun %js-parse-all-stmts (stream)
  "Parse all statements until EOF.
  Returns (values ast-list rest)."
  (let ((stmts nil)
        (current stream))
    (loop
      (setf current (js-skip-semis current))
      (when (js-at-eof-p current)
        (return))
      (multiple-value-bind (stmt rest) (js-parse-stmt current)
        (when stmt (push stmt stmts))
        ;; Safety guard: a statement parser must consume at least one token.
        ;; If REST did not advance past CURRENT, signal rather than spin forever.
        (when (eq rest current)
          (error "JS parse error: no progress at ~S" (js-peek current)))
        (setf current rest)))
    (values (%js-finish-let-bindings (nreverse stmts)) current)))

(defun js-parse-stmt-list (stream)
  "Parse statements until a closing } (which is consumed) or EOF.
Returns (values stmt-list rest-after-rbrace). Used for function, method, and
block bodies; STREAM is positioned just after the opening {. This is the real
statement parser that js-parse-function-body (parser-expr.lisp) dispatches to
via fboundp."
  (let ((stmts nil)
        (current stream))
    (loop
      (setf current (js-skip-semis current))
      (when (or (js-at-eof-p current)
                (eq (js-peek-type current) :T-RBRACE))
        (return))
      (multiple-value-bind (stmt rest) (js-parse-stmt current)
        (when stmt (push stmt stmts))
        ;; Same no-progress guard as %js-parse-all-stmts: never spin forever.
        (when (eq rest current)
          (error "JS parse error: no progress in statement list at ~S"
                 (js-peek current)))
        (setf current rest)))
    (multiple-value-bind (_ rest) (js-expect :T-RBRACE current)
      (declare (ignore _))
      (values (%js-finish-let-bindings (nreverse stmts)) rest))))

(eval-when (:load-toplevel :execute)
  (register-js-source-parser (function %js-parse-all-stmts))
  (register-js-parser-handler :statement-list (function js-parse-stmt-list)))
