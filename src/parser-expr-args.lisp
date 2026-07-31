;;;; packages/javascript/src/parser-expr-args.lisp — JS parameter and argument parsers
;;;;
;;;; Extracted from parser-expr.lisp.  These helpers belong together because
;;;; they both parse delimited comma-separated lists that recurse into
;;;; js-parse-assignment-expr.
;;;; Load order: after parser-expr.lisp, before parser-expr-literal.lisp and
;;;; parser-arrow.lisp (both call these helpers).

(in-package :cl-cc/javascript)

;;; ─── Parameter / Argument Parsers ────────────────────────────────────────────

(defun %js-comma-list-step (stream closer)
  "Advance STREAM past the separator that follows one element of a
comma-separated list terminated by CLOSER, and report whether another element
follows.  Returns (values new-stream more-p).

MORE-P is false in the two cases that end a list: no comma at all, and a
single trailing comma immediately before CLOSER (which JS allows in parameter
lists, argument lists and parenthesised arrow params).  CLOSER itself is never
consumed — the caller still has to expect it.  js-parse-params,
js-parse-arguments and %js-parse-paren-or-arrow each open-coded this same
two-case rule, so a fix to the trailing-comma handling had to be made three
times or not at all."
  (if (eq (js-peek-type stream) :T-COMMA)
      (multiple-value-bind (comma-tok rest) (js-consume stream)
        (declare (ignore comma-tok))
        (values rest (not (eq (js-peek-type rest) closer))))
      (values stream nil)))

(defun js-parse-params (stream)
  "Parse (a, b = default, ...rest) parameter list.
Consumes opening LPAREN through closing RPAREN.
Returns (values param-syms optional-specs rest-sym new-stream) where
  param-syms    — list of all parameter symbols (positional + optional)
  optional-specs — list of (sym . default-expr) for params with defaults
  rest-sym      — symbol for rest parameter, or NIL
  new-stream    — stream after closing RPAREN."
  (multiple-value-bind (tok rest) (js-expect :T-LPAREN stream)
    (declare (ignore tok))
    (if (eq (js-peek-type rest) :T-RPAREN)
        (multiple-value-bind (tok2 rest2) (js-consume rest)
          (declare (ignore tok2))
          (values nil nil nil rest2))
        (let ((params nil)
              (optionals nil)
              (rest-sym nil)
              (current rest))
          (loop
            ;; Rest parameter: ...name
            (when (eq (js-peek-type current) :T-ELLIPSIS)
              (multiple-value-bind (tok2 rest2) (js-consume current)
                (declare (ignore tok2))
                (multiple-value-bind (name-tok rest3) (js-expect :T-IDENT rest2)
                  (setf rest-sym (js-ident-sym (js-tok-value name-tok))
                        current rest3)
                  (return)))) ; rest param must be last
            ;; Normal or default parameter
            (multiple-value-bind (name-tok rest2) (js-expect :T-IDENT current)
              (let ((sym (js-ident-sym (js-tok-value name-tok))))
                (push sym params)
                (setf current rest2)
                ;; Default value?
                (when (js-at-op-p current "=")
                  (multiple-value-bind (eq-tok rest3) (js-consume current)
                    (declare (ignore eq-tok))
                    (multiple-value-bind (default-expr rest4)
                        (js-parse-assignment-expr rest3)
                      (push (cons sym default-expr) optionals)
                      (setf current rest4))))))
            ;; Continue on comma, stop otherwise
            (multiple-value-bind (next-stream more-p) (%js-comma-list-step current :T-RPAREN)
              (setf current next-stream)
              (unless more-p (return))))
          (multiple-value-bind (tok2 rest2) (js-expect :T-RPAREN current)
            (declare (ignore tok2))
            (values (nreverse params)
                    (nreverse optionals)
                    rest-sym
                    rest2))))))

(defun js-parse-arguments (stream)
  "Parse argument list after LPAREN. Handles spread (...expr).
Returns (values arg-list rest)."
  (multiple-value-bind (tok rest) (js-expect :T-LPAREN stream)
    (declare (ignore tok))
    (if (eq (js-peek-type rest) :T-RPAREN)
        (multiple-value-bind (tok2 rest2) (js-consume rest)
          (declare (ignore tok2))
          (values nil rest2))
        (let ((args nil)
              (current rest))
          (loop
            ;; Spread argument: ...expr
            (if (eq (js-peek-type current) :T-ELLIPSIS)
                (multiple-value-bind (tok2 rest2) (js-consume current)
                  (declare (ignore tok2))
                  (multiple-value-bind (expr rest3) (js-parse-assignment-expr rest2)
                    (push (%js-call '%js-spread expr) args)
                    (setf current rest3)))
                (multiple-value-bind (expr rest2) (js-parse-assignment-expr current)
                  (push expr args)
                  (setf current rest2)))
            (multiple-value-bind (next-stream more-p) (%js-comma-list-step current :T-RPAREN)
              (setf current next-stream)
              (unless more-p (return))))
          (multiple-value-bind (tok2 rest2) (js-expect :T-RPAREN current)
            (declare (ignore tok2))
            (values (nreverse args) rest2))))))
