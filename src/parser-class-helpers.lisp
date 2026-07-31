;;;; packages/javascript/src/parser-class-helpers.lisp — ES2026 class parser helpers
;;;;
;;;; Shared helper routines for class decorators, member names, accessors, and
;;;; member metadata.  Kept separate from parser-class.lisp so the latter can
;;;; focus on class-body lowering and stay below the giant-file threshold.
(in-package :cl-cc/javascript)

;;; ─── Symbol helpers ──────────────────────────────────────────────────────────
;;; js-tok-type, js-tok-value, js-peek*, js-consume, js-expect, js-at-eof-p,
;;; js-skip-semis, js-ident-sym — all defined in parser.lisp / parser-stmt.lisp.
(defun js-private-ident-sym (str)
  "Intern a JS private field name (without #) with a %JS-PRIV- prefix."
  (intern
    (concatenate
      'string
      "%JS-PRIV-"
      (string-upcase
        (if (stringp str) str
          (symbol-name str))))
    :cl-cc/javascript))

(defun %js-skip-balanced-until (stream delimiter-types)
  "Advance STREAM past tokens until reaching one whose type is in
DELIMITER-TYPES at paren/bracket/brace nesting depth 0 -- so a delimiter
token that is actually part of a nested call or bracketed literal (a
decorator argument or parameter default that is itself `foo(1,2)' or
`[1,2]') doesn't terminate the skip early. Returns STREAM positioned at the
matched delimiter, or at EOF if none was found before the token list ran
out."
  (let ((depth 0))
    (loop while (and stream
                     (or (plusp depth)
                         (not (member (js-peek-type stream) delimiter-types))))
          do (case (js-peek-type stream)
               ((:T-LPAREN :T-LBRACKET :T-LBRACE) (incf depth))
               ((:T-RPAREN :T-RBRACKET :T-RBRACE) (decf depth)))
             (setf stream (cdr stream))))
  stream)

;;; ─── Decorator parser ────────────────────────────────────────────────────────
(defun %js-parse-decorator-member-chain (sym stream)
  "Extend SYM with each dotted member access at STREAM (@foo.bar.baz folds
into one SYM named \"FOO.BAR.BAZ\"). Returns (values extended-sym rest)."
  (let ((current stream))
    (loop while (and current (eq (js-peek-type current) :T-DOT))
          do (setf current (cdr current))
             (multiple-value-bind (mem-tok rest) (js-expect :T-IDENT current)
               (setf sym (js-ident-sym
                          (concatenate 'string (symbol-name sym) "." (js-tok-value mem-tok)))
                     current rest)))
    (values sym current)))

(defun %js-parse-decorator-args (stream)
  "Parse the argument list of @decorator(args...) starting just AFTER the
opening '(' has been consumed. Each argument's real tokens are skipped
rather than parsed into a real expression -- every argument becomes the same
placeholder var (_decorator-arg_, never bound anywhere) -- because decorator
argument VALUES are never read at all: %js-lower-class-to-ast discards its
whole DECORATORS argument, so this AST is built and immediately discarded,
never evaluated. %JS-SKIP-BALANCED-UNTIL tracks paren/bracket/brace nesting
depth so an argument that is itself a call or literal (@dec(foo(1,2)),
@dec([1,2])) isn't mistaken for multiple arguments by its own internal
commas, nor its own closing delimiter for the decorator's. Returns
(values args-list rest)."
  (let ((args nil))
    (loop until (or (js-at-eof-p stream) (eq (js-peek-type stream) :T-RPAREN))
          do (push (make-ast-var :name (js-ident-sym "_decorator-arg_")) args)
             (setf stream (%js-skip-balanced-until stream '(:T-COMMA :T-RPAREN)))
             (when (and stream (eq (js-peek-type stream) :T-COMMA))
               (setf stream (cdr stream))))
    (values (nreverse args) stream)))

(defun %js-parse-decorator (stream)
  "Parse a single @expression decorator.
Returns (values decorator-ast rest) where DECORATOR-AST is an ast-call or
ast-var representing the decorator."
  ;; Consume the '@' token (already confirmed :T-AT by caller)
  (multiple-value-bind (_ rest) (js-consume stream)
    (declare (ignore _))
    ;; Decorator body: identifier optionally followed by member chain and/or call
    (multiple-value-bind (name-tok rest2) (js-expect :T-IDENT rest)
      (multiple-value-bind (sym current)
          (%js-parse-decorator-member-chain (js-ident-sym (js-tok-value name-tok)) rest2)
        ;; Optional argument list: @decorator(args...)
        (if (and current (eq (js-peek-type current) :T-LPAREN))
            (multiple-value-bind (args arg-rest) (%js-parse-decorator-args (cdr current))
              (multiple-value-bind (_ rest3) (js-expect :T-RPAREN arg-rest)
                (declare (ignore _))
                (values (make-ast-call :func (make-ast-var :name sym) :args args) rest3)))
            (values (make-ast-var :name sym) current))))))

(defun %js-parse-decorators (stream)
  "Parse zero or more @decorator lines.
Returns (values decorators-list rest)."
  (let ((decorators nil)
        (current stream))
    (loop while (and current (eq (js-peek-type current) :T-AT))
          do (multiple-value-bind (dec rest) (%js-parse-decorator current)
        (push dec decorators)
        (setf current rest)))
    (values (nreverse decorators) current)))

;;; ─── Computed member name ────────────────────────────────────────────────────
(defun %js-parse-computed-name (stream)
  "Parse a computed property name [expr]. STREAM points at '['.
Returns (values expr-ast rest) where EXPR-AST is the real parsed expression
AST for the bracketed key -- mirrors %js-parse-object-property-computed's
handling of object-literal computed keys ({[expr]: value}) so class and
object-literal computed names parse the same way. Downstream code
distinguishes a computed name from a plain/private member name via
(symbolp name): a computed name is an AST node, never a symbol."
  (multiple-value-bind (tok rest) (js-consume stream)
    (declare (ignore tok))
    (multiple-value-bind (expr-ast rest2) (js-parse-assignment-expr rest)
      (multiple-value-bind (tok2 rest3) (js-expect :T-RBRACKET rest2)
        (declare (ignore tok2))
        (values expr-ast rest3)))))

;;; ─── Member name parser ──────────────────────────────────────────────────────
(defun %js-parse-member-name (stream)
  "Parse a class member name. Returns (values name private-p rest orig-name).
NAME is a symbol for plain/private names or an AST node for computed names.
PRIVATE-P is T when the name was a #privateIdent. ORIG-NAME is the member name's
ORIGINAL-CASE string (js-ident-sym upcases the symbol, but JS property access is
case-sensitive and keys on the source string, so the class lowering stores
methods under ORIG-NAME); NIL for computed names."
  (cond
    ;; Computed name [expr]
    ((eq (js-peek-type stream) :T-LBRACKET)
     (multiple-value-bind (name-ast rest) (%js-parse-computed-name stream)
       (values name-ast nil rest nil)))
    ;; Private identifier #name
    ((eq (js-peek-type stream) :T-PRIVATE-IDENT)
     (multiple-value-bind (tok rest) (js-consume stream)
       (let ((v (js-tok-value tok)))
         (values (js-private-ident-sym v) t rest
                 (if (stringp v) v (symbol-name v))))))
    ;; Regular identifier — also accept keyword names used as method names
    ;; (e.g. class C { get() {} static() {} })
    (t
     (multiple-value-bind (tok rest) (js-consume stream)
       (let ((v (js-tok-value tok)))
         (values (js-ident-sym (if (stringp v) v (symbol-name v)))
                 nil rest
                 (if (stringp v) v (symbol-name v))))))))

;;; ─── Class body member kinds ─────────────────────────────────────────────────
;;; Internal helper: build a slot-def for a get/set accessor.
;;; KIND is :getter or :setter; STREAM points past the consumed 'get'/'set' token.
;;; Getters take no parameters; setters take one.
(defun %js-parse-accessor (kind static-p decorators stream)
  (multiple-value-bind (name private-p rest) (%js-parse-member-name stream)
    (multiple-value-bind (params body rest2) (%js-parse-method-params-body rest)
      (let* ((computed-p (not (symbolp name)))
             (sym
            (if computed-p (gensym
                (if (eq kind :getter) "JS-GETTER-"
                  "JS-SETTER-"))
              name))
             (slot
            (make-ast-slot-def
              :name
              sym
              :initform
              (make-ast-defun
                :name
                sym
                :params
                (unless (eq kind :getter)
                  params)
                :body
                (list body))
              :allocation
              (if static-p :class
                :instance)
              :imports
              (append
                (when computed-p
                  (list :js-computed-key-ast name))
                (%js-member-kind-metadata kind static-p private-p nil nil decorators)))))
        (values slot (js-skip-semis rest2))))))

(defun %js-parse-method-params-body (stream)
  "Parse ( params ) { body } for a method. Returns (values params body rest).
Params is a list of symbols; body is an ast-progn of properly-parsed AST nodes.

Previously this function collected method body tokens verbatim and stored them
as (ast-progn (ast-quote raw-token-list)). That meant class method bodies were
never compiled - every method silently became a no-op. Now the body is parsed
via js-parse-stmt-list (the real statement parser) so methods execute normally."
  ;; Parameter list
  (let ((rest (nth-value 1 (js-expect :T-LPAREN stream)))
        (params nil))
    (loop until (or (js-at-eof-p rest) (eq (js-peek-type rest) :T-RPAREN))
          do (cond
               ;; Rest parameter ...name
               ((eq (js-peek-type rest) :T-ELLIPSIS)
                (setf rest (cdr rest))
                (multiple-value-bind (tok rest2) (js-expect :T-IDENT rest)
                  (push (list :rest (js-ident-sym (js-tok-value tok))) params)
                  (setf rest rest2)))
               ;; Normal identifier param (ignore defaults for now)
               ((member (js-peek-type rest) '(:T-IDENT :T-THIS))
                (multiple-value-bind (tok rest2) (js-consume rest)
                  (push (js-ident-sym (js-tok-value tok)) params)
                  (setf rest rest2)
                  ;; Skip default value = expr. %JS-SKIP-BALANCED-UNTIL
                  ;; tracks nesting depth so a default that is itself a call
                  ;; or bracketed literal (m(a, b=foo(1,2))) doesn't stop at
                  ;; its own internal comma/close-paren instead of the
                  ;; parameter list's.
                  (when (and rest (eq (js-peek-type rest) :T-OP)
                             (equal "=" (js-peek-value rest)))
                    (setf rest (cdr rest))
                    (setf rest (%js-skip-balanced-until rest '(:T-COMMA :T-RPAREN))))))
               (t
                ;; Destructuring params or other complex params - skip token
                (setf rest (cdr rest))))
          ;; consume comma separator
          (when (and rest (eq (js-peek-type rest) :T-COMMA))
            (setf rest (cdr rest))))
    (multiple-value-bind (_ rest2) (js-expect :T-RPAREN rest)
      (declare (ignore _))
      ;; Method body { stmts... }
      ;; js-parse-stmt-list consumes the opening { and closing } and returns
      ;; (values stmt-list rest-after-rbrace) - the real statement parser used
      ;; by js-parse-block and js-parse-function-body.
      (multiple-value-bind (_ rest3) (js-expect :T-LBRACE rest2)
        (declare (ignore _))
        (multiple-value-bind (body-stmts rest4) (js-parse-stmt-list rest3)
          (let ((body-ast (make-ast-progn :forms (%js-callable-body body-stmts))))
            (values (nreverse params) body-ast rest4)))))))

(defun %js-member-kind-metadata (kind static-p private-p async-p generator-p decorators &optional orig-name)
  "Build the :imports plist for a class member slot.
ORIG-NAME is the original-case method name string (case-sensitive key for prototype)."
  (append
    (list :js-member-kind kind)
    (when orig-name
      (list :js-orig-name orig-name))
    (when static-p
      (list :js-static t))
    (when private-p
      (list :js-private t))
    (when async-p
      (list :js-async t))
    (when generator-p
      (list :js-generator t))
    (when decorators
      (list :js-decorators decorators))))
