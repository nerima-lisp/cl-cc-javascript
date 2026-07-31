;;;; packages/javascript/src/parser-stmt-flow.lisp — JS flow-control statement parsers
;;;;
;;;; break, continue, return, throw, try/catch/finally, debugger,
;;;; using declaration (ES2025).
;;;;
;;;; Load order: after parser-stmt.lisp and parser-stmt-control.lisp.

(in-package :cl-cc/javascript)

;;; ─── Break / Continue ────────────────────────────────────────────────────────

(defun js-parse-break-stmt (stream)
  "Parse break [label]; — emits (return-from label-block) for labeled, (go end) for plain."
  (let ((current stream)
        (label-name nil))
    ;; Optional label on same line (no intervening newline — simplified)
    (when (and current (eq (js-peek-type current) :T-IDENT))
      (setf label-name (let ((v (js-peek-value current)))
                         (if (stringp v) v (string-downcase (symbol-name v))))
            current (cdr current)))
    (setf current (js-skip-semis current))
    (cond
      ;; Labeled break: (return-from LABEL-BLOCK)
      ((and label-name (gethash label-name *js-label-break-targets*))
       (values (make-ast-return-from :name (gethash label-name *js-label-break-targets*)
                                     :value (make-ast-quote :value nil))
               current))
      ;; Unlabeled break (or unknown label): go to innermost break target
      (t
       (let ((target (or (first *js-break-targets*) *js-loop-break-target*)))
         (unless target
           (error "JS parse error: break has no matching loop or switch"))
         (values (make-ast-go :tag target) current))))))

(defun js-parse-continue-stmt (stream)
  "Parse continue [label]; — emits (go continue-tag) for both labeled and unlabeled."
  (let ((current stream)
        (label-name nil))
    ;; Optional label on same line
    (when (and current (eq (js-peek-type current) :T-IDENT))
      (setf label-name (let ((v (js-peek-value current)))
                         (if (stringp v) v (string-downcase (symbol-name v))))
            current (cdr current)))
    (setf current (js-skip-semis current))
    (cond
      ;; Labeled continue: go to the label's registered continue target
      ((and label-name (gethash label-name *js-label-continue-targets*))
       (values (make-ast-go :tag (gethash label-name *js-label-continue-targets*))
               current))
      ;; Unlabeled continue: go to innermost loop's continue target
      (t
       (let ((target (or (first *js-continue-targets*) *js-loop-continue-target*)))
         (unless target
           (error "JS parse error: continue has no matching loop"))
         (values (make-ast-go :tag target) current))))))

;;; ─── Return Statement ────────────────────────────────────────────────────────

(defun js-parse-return-stmt (stream)
  "Parse return [expr];. Returns (values ast rest)."
  (if (or (js-at-eof-p stream)
          (eq (js-peek-type stream) :T-SEMI)
          (eq (js-peek-type stream) :T-RBRACE))
      (values (make-ast-return-from :name nil :value (make-ast-quote :value nil))
              (js-skip-semis stream))
      (multiple-value-bind (expr rest) (js-parse-expr stream)
        (values (make-ast-return-from :name nil :value expr)
                (js-skip-semis rest)))))

;;; ─── Throw Statement ─────────────────────────────────────────────────────────

(defun js-parse-throw-stmt (stream)
  "Parse throw expr; -> (values (%js-throw expr) rest)."
  (multiple-value-bind (expr rest) (js-parse-expr stream)
    (values (make-ast-call :func (make-ast-var :name '%js-throw)
                           :args (list expr))
            (js-skip-semis rest))))

;;; ─── Try / Catch / Finally ───────────────────────────────────────────────────

(defun %js-parse-catch-binding (stream)
  "Parse an optional catch(e) binding at STREAM. Returns (values var-sym
rest) — VAR-SYM is nil for a bindless `catch {}` or when STREAM has no
parenthesized binding at all."
  (if (eq (js-peek-type stream) :T-LPAREN)
      (let ((current (cdr stream)) (var-sym nil))
        (when (eq (js-peek-type current) :T-IDENT)
          (multiple-value-bind (tok rest) (js-consume current)
            (setf var-sym (%js-binding-sym (js-tok-value tok))
                  current rest)))
        (values var-sym (%js-consume-expected :T-RPAREN current)))
      (values nil stream)))

(defun %js-parse-catch-clauses (stream)
  "Parse zero or more `catch (e) {...}` clauses starting at STREAM (JS syntax
allows only one, but the loop mirrors the grammar rather than assuming it).
Returns (values clauses rest), CLAUSES a list of (var-sym body-forms) in
source order."
  (let ((clauses nil) (current stream))
    (loop while (and current (eq (js-peek-type current) :T-CATCH))
          do (setf current (cdr current))
             (multiple-value-bind (var-sym rest) (%js-parse-catch-binding current)
               (multiple-value-bind (catch-ast rest2) (js-parse-block rest)
                 (push (list var-sym (ast-progn-forms catch-ast)) clauses)
                 (setf current rest2))))
    (values (nreverse clauses) current)))

(defun %js-parse-finally-clause (stream)
  "Parse an optional `finally {...}` clause at STREAM. Returns (values
present-p body-forms rest) — PRESENT-P is tracked separately from BODY-FORMS
because an empty `finally {}` has a nil body but is still a valid clause."
  (if (and stream (eq (js-peek-type stream) :T-FINALLY))
      (multiple-value-bind (finally-ast rest) (js-parse-block (cdr stream))
        (values t (ast-progn-forms finally-ast) rest))
      (values nil nil stream)))

(defun %js-build-catch-dispatch (clauses err-sym)
  "The AST run when the protected try body throws: JS has at most one catch
clause, so this dispatches to the first of CLAUSES (as produced by
%js-parse-catch-clauses), binding ERR-SYM to the clause's catch variable
when it declared one, or just running the body when it didn't. No clauses at
all (a bare try/finally) yields nil — %js-try-catch-finally rethrows in that
case."
  (if clauses
      (let* ((clause (first clauses)) (var (first clause)) (body (second clause)))
        (if var
            (make-ast-let :bindings (list (cons var (make-ast-var :name err-sym)))
                          :body body)
            (make-ast-progn :forms body)))
      (make-ast-quote :value nil)))

(defun js-parse-try-stmt (stream)
  "Parse try {} catch(e) {} finally {} .
  Lowers to ast-unwind-protect wrapping a %js-try-catch-finally call.
  Returns (values ast rest)."
  (multiple-value-bind (try-ast rest) (js-parse-block stream)
    (multiple-value-bind (clauses rest2) (%js-parse-catch-clauses rest)
      (multiple-value-bind (finally-present-p finally-body rest3)
          (%js-parse-finally-clause rest2)
        (unless (or clauses finally-present-p)
          (error "JS parse error: try must have catch or finally"))
        (let* ((err-sym (gensym "JS-ERR-"))
               (catch-dispatch (%js-build-catch-dispatch clauses err-sym))
               (protected
                (make-ast-call
                 :func (make-ast-var :name '%js-try-catch-finally)
                 :args (list (make-ast-lambda :params nil :body (ast-progn-forms try-ast))
                             (make-ast-lambda :params (list err-sym)
                                              :body (list catch-dispatch))
                             (make-ast-lambda :params nil
                                              :body (or finally-body
                                                        (list (make-ast-quote :value nil))))))))
          (values protected rest3))))))

;;; ─── Debugger Statement ──────────────────────────────────────────────────────

(defun js-parse-debugger-stmt (stream)
  "Parse debugger; -> (values (%js-debugger) rest)."
  (values (make-ast-call :func (make-ast-var :name '%js-debugger)
                         :args nil)
          (js-skip-semis stream)))

;;; ─── Using Declaration (ES2025 Explicit Resource Management) ─────────────────

(defun js-parse-using-decl (stream)
  "Parse using x = expr (ES2025 explicit resource management).
  Lowers to ast-let + registration of disposable resource on scope exit.
  The disposal call is wrapped as a %js-using-register call at the binding site.
  Returns (values ast rest)."
  ;; 'using' is a contextual keyword: stream starts with the binding identifier
  (multiple-value-bind (name-tok rest) (js-expect :T-IDENT stream)
    (let ((var-sym (%js-binding-sym (js-tok-value name-tok))))
      (unless (and (eq (js-peek-type rest) :T-OP)
                   (equal (js-peek-value rest) "="))
        (error "JS parse error: expected '=' after identifier in using declaration, got ~S"
               (js-peek rest)))
      (let ((rest2 (cdr rest)))
        (multiple-value-bind (init-expr rest3) (js-parse-expr rest2)
          (values
           (make-ast-let
            :bindings (list (cons var-sym
                                  (make-ast-call
                                   :func (make-ast-var :name '%js-using-register)
                                   :args (list init-expr))))
            :declarations (list :js-using)
            :body nil)
           (js-skip-semis rest3)))))))

;;; Flow-control statement parsers live here; the main dispatcher is in parser-stmt-dispatch.lisp.
