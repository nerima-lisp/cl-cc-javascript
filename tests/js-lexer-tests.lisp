;;;; packages/javascript/tests/js-lexer-tests.lisp — ES2026 JavaScript Lexer Tests
;;;;
;;;; Token format: (:type :T-XXX :value val)

(in-package :cl-cc-javascript/test)

;;; ─── Helpers ──────────────────────────────────────────────────────────────────

(defun %js-lex (src)
  "Tokenize SRC and return the token list (including :T-EOF)."
  (cl-cc/javascript:tokenize-js-source src))

(defun %js-lex-types (src)
  "Return only the :type field of each token produced from SRC."
  (mapcar (lambda (tok) (getf tok :type)) (%js-lex src)))

(defun %js-lex-values (src)
  "Return only the :value field of each token produced from SRC."
  (mapcar (lambda (tok) (getf tok :value)) (%js-lex src)))

(defun %js-first-token (src)
  "Return the first token produced from SRC."
  (first (%js-lex src)))

(defun %js-first-type (src)
  "Return the :type of the first token produced from SRC."
  (getf (%js-first-token src) :type))

(defun %js-first-value (src)
  "Return the :value of the first token produced from SRC."
  (getf (%js-first-token src) :value))

(defun %js-signals-error-p (thunk)
  "True if calling THUNK (a zero-arg function) signals an error."
  (handler-case (progn (funcall thunk) nil)
    (error () t)))

;;; ─── Numeric literals ─────────────────────────────────────────────────────────

(it-sequential-each (("42" 42) ("0" 0) ("255" 255) ("0xFF" 255)
                     ("0o777" 511) ("0b1010" 10) ("1_000_000" 1000000))
    "lex-integer-literal ~A"
    (src expected)
  (expect (%js-first-type src) :to-be :T-NUMBER)
  (expect (= expected (%js-first-value src)) :to-be-truthy))

(it-sequential "lex-float-pi"
  (expect (%js-first-type "3.14") :to-be :T-NUMBER)
  (expect (typep (%js-first-value "3.14") 'double-float) :to-be-truthy)
  (expect (< (abs (- 3.14d0 (%js-first-value "3.14"))) 1.0d-10) :to-be-truthy))

(it-sequential "lex-float-scientific"
  (expect (%js-first-type "1.5e-3") :to-be :T-NUMBER)
  (expect (< (abs (- 1.5d-3 (%js-first-value "1.5e-3"))) 1.0d-15) :to-be-truthy))

(it-sequential "lex-bigint-literal"
  (expect (%js-first-type "42n") :to-be :T-BIGINT)
  (expect (= 42 (%js-first-value "42n")) :to-be-truthy))

;;; ─── String literals ──────────────────────────────────────────────────────────

(it-sequential-each (("'hello'" "hello") ("\"world\"" "world"))
    "lex-string-literal ~A"
    (src expected)
  (expect (%js-first-type src) :to-be :T-STRING)
  (expect (%js-first-value src) :to-equal expected))

;;; ─── Keyword tokens ───────────────────────────────────────────────────────────

(it-sequential-each (("if" :T-IF) ("for" :T-FOR) ("class" :T-CLASS)
                     ("async" :T-ASYNC) ("await" :T-AWAIT) ("using" :T-USING)
                     ("true" :T-TRUE) ("false" :T-FALSE) ("null" :T-NULL)
                     ("undefined" :T-UNDEFINED))
    "lex-keyword ~A"
    (src expected-type)
  (expect (%js-first-type src) :to-be expected-type))

;;; ─── Identifiers ──────────────────────────────────────────────────────────────

(it-sequential-each (("foo" "foo") ("_bar" "_bar") ("$baz" "$baz")
                     ("camelCase" "camelCase"))
    "lex-identifier ~A"
    (src expected)
  (expect (%js-first-type src) :to-be :T-IDENT)
  (expect (%js-first-value src) :to-equal expected))

;;; ─── Private identifiers ──────────────────────────────────────────────────────

(it-sequential-each (("#field" "field") ("#privateMethod" "privateMethod"))
    "lex-private-identifier ~A"
    (src expected)
  (expect (%js-first-type src) :to-be :T-PRIVATE-IDENT)
  (expect (%js-first-value src) :to-equal expected))

;;; ─── Decorator ────────────────────────────────────────────────────────────────

(it-sequential "lex-decorator-at"
  (let ((types (%js-lex-types "@decorator")))
    (expect (first  types) :to-be :T-AT)
    (expect (second types) :to-be :T-IDENT)))

;;; ─── Multi-character operators ────────────────────────────────────────────────

(it-sequential-each (("===" "===") ("!==" "!==") ("??" "??") ("?." "?.")
                     ("&&=" "&&=") ("||=" "||=") ("??=" "??=") ("**=" "**="))
    "lex-operator ~A"
    (src expected)
  (expect (%js-first-type src) :to-be :T-OP)
  (expect (%js-first-value src) :to-equal expected))

;;; ─── Special punctuation ──────────────────────────────────────────────────────

(it-sequential "lex-ellipsis"
  (expect (%js-first-type "...") :to-be :T-ELLIPSIS)
  (expect (%js-first-value "...") :to-equal "..."))

(it-sequential "lex-arrow"
  (expect (%js-first-type "=>") :to-be :T-ARROW)
  (expect (%js-first-value "=>") :to-equal "=>"))

;;; ─── Comments ─────────────────────────────────────────────────────────────────

(it-sequential "lex-line-comment-skipped"
  (let ((types (%js-lex-types "// this is a comment")))
    (expect (= 1 (length types)) :to-be-truthy)
    (expect (first types) :to-be :T-EOF)))

(it-sequential "lex-line-comment-newline-consumed"
  (let ((tokens (%js-lex (format nil "// comment~%foo"))))
    (expect (getf (first tokens) :type) :to-be :T-IDENT)
    (expect (getf (first tokens) :value) :to-equal "foo")))

(it-sequential "lex-block-comment-skipped"
  (let ((tokens (%js-lex "/* skip me */ foo")))
    (expect (getf (first tokens) :type) :to-be :T-IDENT)
    (expect (getf (first tokens) :value) :to-equal "foo")))

(it-sequential "lex-block-comment-unterminated"
  (expect (%js-signals-error-p (lambda () (%js-lex "/* unterminated"))) :to-be-truthy))

(it-sequential "lex-hashbang-skipped-at-start"
  (let ((tokens (%js-lex (format nil "#!/usr/bin/env js~%foo"))))
    (expect (getf (first tokens) :type) :to-be :T-IDENT)
    (expect (getf (first tokens) :value) :to-equal "foo")))

(it-sequential-each (("\\n\\r\\t\\\\\\'\\\"\\0z'"
                      #.(coerce (list #\Newline #\Return #\Tab #\\ #\' #\" #\Null #\z) 'string))
                     ("\\u0041'" "A")
                     ("\\u{263A}'" #.(string (code-char #x263A)))
                     ("\\x41'" "A")
                     ("abc'" "abc"))
    "lex-string-escape-branches ~S"
    (src expected)
  (multiple-value-bind (value new-pos) (cl-cc/javascript::lex-js-string src 0 #\')
    (expect value :to-equal expected)
    (expect (= (length src) new-pos) :to-be-truthy)))

(it-sequential-each (("\\") (#.(format nil "line1~%line2'")) ("abc"))
    "lex-string-error-branches ~S"
    (src)
  (expect (%js-signals-error-p (lambda () (cl-cc/javascript::lex-js-string src 0 #\')))
          :to-be-truthy))

;;; ─── Multi-token sequence ─────────────────────────────────────────────────────

(it-sequential "lex-const-statement-sequence"
  (expect (%js-lex-types "const x = 42 + y;") :to-equal '(:T-CONST :T-IDENT :T-OP :T-NUMBER :T-OP :T-IDENT :T-SEMI :T-EOF)))

;;; ─── Regex literals ───────────────────────────────────────────────────────────

(it-sequential-each (("/ab+c/gi" "ab+c" "gi")
                     ("/hello/" "hello" "")
                     ("/[a-z]+/" "[a-z]+" "")
                     ("/x/dgimsuy" "x" "dgimsuy"))
    "lex-regex-pattern ~S"
    (src expected-pattern expected-flags)
  (let* ((tok (first (%js-lex src)))
         (val (getf tok :value)))
    (expect (getf tok :type) :to-be :T-REGEX)
    (expect (second val) :to-equal expected-pattern)
    (expect (third  val) :to-equal expected-flags)))

(it-sequential "lex-division-not-regex"
  (let ((types (%js-lex-types "a / b")))
    (expect (member :T-OP    types) :to-be-truthy)
    (expect (member :T-REGEX types) :to-be-falsy)))

;;; ─── Template literals ───────────────────────────────────────────────────────

(it-sequential "lex-template-simple"
  (let* ((tok (first (%js-lex "`hello`")))
         (parts (getf tok :value)))
    (expect (getf tok :type) :to-be :T-TEMPLATE-PARTS)
    (expect parts :to-equal '("hello"))))

(it-sequential "lex-template-escaped-cook"
  (let* ((tok (first (%js-lex "`a\\n\\r\\t\\\\\\`\\$\\0z`")))
         (parts (getf tok :value))
         (expected (coerce (list #\a #\Newline #\Return #\Tab #\\ #\` #\$ #\Null #\z)
                           'string)))
    (expect (getf tok :type) :to-be :T-TEMPLATE-PARTS)
    (expect parts :to-equal (list expected))))

(it-sequential "lex-template-interpolated"
  (let* ((tok (first (%js-lex "`hi ${name + 1}!`")))
         (parts (getf tok :value))
         (expr-part (second parts))
         (inner (second expr-part))
         (inner-types (mapcar (lambda (tk) (getf tk :type))
                              inner)))
    (expect (getf tok :type) :to-be :T-TEMPLATE-PARTS)
    (expect (first parts) :to-equal "hi ")
    (expect (and (consp expr-part)
                      (eq (first expr-part) :template-expr)) :to-be-truthy)
    (expect (third parts) :to-equal "!")
    (expect inner-types :to-equal '(:T-IDENT :T-OP :T-NUMBER))))

(it-sequential "lex-template-nested-interpolation"
  (let* ((tok (first (%js-lex "`a ${\"{\" + `inner ${x}` + \"}\"} b`")))
         (parts (getf tok :value))
         (inner (second (second parts)))
         (inner-types (mapcar (lambda (tk) (getf tk :type)) inner)))
    (expect (getf tok :type) :to-be :T-TEMPLATE-PARTS)
    (expect (first parts) :to-equal "a ")
    (expect (third parts) :to-equal " b")
    (expect (member :T-TEMPLATE-PARTS inner-types) :to-be-truthy)))

(it-sequential-each (("n" 0 #\Newline 1)
                     ("r" 0 #\Return 1)
                     ("t" 0 #\Tab 1)
                     ("\\" 0 #\\ 1)
                     ("`" 0 #\` 1)
                     ("$" 0 #\$ 1)
                     ("0" 0 #\Null 1)
                     ("u0041" 0 #\A 5)
                     ("u{1F600}" 0 #.(code-char #x1F600) 8)
                     ("x41" 0 #\A 3)
                     ("a" 0 #\a 1))
    "lex-template-escape-processor ~S"
    (src pos expected-char expected-pos)
  (multiple-value-bind (ch new-pos) (cl-cc/javascript::js-lex-template-escape src pos)
    (expect ch :to-be expected-char)
    (expect (= expected-pos new-pos) :to-be-truthy)))

(it-sequential-each (("") ("u") ("u{}") ("u{1F4") ("u{1F4x")
                     ("u{110000}") ("x4") ("u12x4") ("xg1"))
    "lex-template-escape-errors ~S"
    (src)
  (expect (%js-signals-error-p (lambda () (cl-cc/javascript::js-lex-template-escape src 0)))
          :to-be-truthy))
