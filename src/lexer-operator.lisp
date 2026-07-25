;;;; packages/javascript/src/lexer-operator.lisp — JS operator/punctuation lexer + main tokenizer
;;;;
;;;; lex-js-operator: table-driven dispatch for all JS multi-character operators
;;;; tokenize-js-source: main tokenizer assembling all sub-lexers into a token list
;;;;
;;;; Load order: after lexer.lisp (needs make-js-token, js-*-p predicates,
;;;;             skip-js-whitespace-and-comments, lex-js-string, lex-js-identifier,
;;;;             lex-js-private-ident, js-regex-follows-p).

(in-package :cl-cc/javascript)

;;; Operator lexer

(defparameter *%js-single-char-punctuator-tokens*
  '((#\( :T-LPAREN   . "(")
    (#\) :T-RPAREN   . ")")
    (#\{ :T-LBRACE   . "{")
    (#\} :T-RBRACE   . "}")
    (#\[ :T-LBRACKET . "[")
    (#\] :T-RBRACKET . "]")
    (#\; :T-SEMI     . ";")
    (#\, :T-COMMA    . ",")
    (#\@ :T-AT       . "@")
    (#\~ :T-OP       . "~")
    (#\: :T-COLON    . ":"))
  "JS punctuators with no multi-character extension — every other operator
character (. ? = ! < > + - * / % &amp; | ^) starts a case arm of its own in
LEX-JS-OPERATOR because at least one longer operator begins with it.
Entry shape: (char token-type . token-value).")

(defun lex-js-operator (source pos)
  "Lex an operator or punctuation token at POS.
Handles all multi-character JS operators.
Returns (values token new-pos)."
  (let ((ch  (char source pos))
        (ch2 (%js-lex-peek-char2 source pos))
        (ch3 (when (< (+ pos 2) (length source)) (char source (+ pos 2)))))
    (macrolet ((tok3 (str type val)
                 `(when (and ch2 ch3
                             (char= ch2 ,(char str 1))
                             (char= ch3 ,(char str 2)))
                    (return-from lex-js-operator
                      (values (make-js-token ,type ,val) (+ pos 3)))))
               (tok2 (str type val)
                 `(when (and ch2 (char= ch2 ,(char str 1)))
                    (return-from lex-js-operator
                      (values (make-js-token ,type ,val) (+ pos 2)))))
               (tok1 (type val)
                 `(return-from lex-js-operator
                    (values (make-js-token ,type ,val) (1+ pos)))))
      (case ch
        (#\.
         ;; ... ellipsis
         (when (and ch2 ch3 (char= ch2 #\.) (char= ch3 #\.))
           (return-from lex-js-operator
             (values (make-js-token :T-ELLIPSIS "...") (+ pos 3))))
         (tok1 :T-DOT "."))
        (#\?
         ;; ??= null-coalescing assignment
         (when (and ch2 ch3 (char= ch2 #\?) (char= ch3 #\=))
           (return-from lex-js-operator
             (values (make-js-token :T-OP "??=") (+ pos 3))))
         ;; ?. optional chaining
         (tok2 "?." :T-OP "?.")
         ;; ?? null-coalescing
         (tok2 "??" :T-OP "??")
         (tok1 :T-QUESTION "?"))
        (#\=
         ;; === strict equality
         (tok3 "===" :T-OP "===")
         ;; => arrow
         (tok2 "=>" :T-ARROW "=>")
         ;; == equality
         (tok2 "==" :T-OP "==")
         (tok1 :T-OP "="))
        (#\!
         ;; !==
         (tok3 "!==" :T-OP "!==")
         ;; !=
         (tok2 "!=" :T-OP "!=")
         (tok1 :T-OP "!"))
        (#\<
         ;; <<=
         (when (and ch2 ch3 (char= ch2 #\<) (char= ch3 #\=))
           (return-from lex-js-operator
             (values (make-js-token :T-OP "<<=") (+ pos 3))))
         ;; <<
         (tok2 "<<" :T-OP "<<")
         ;; <=
         (tok2 "<=" :T-OP "<=")
         (tok1 :T-OP "<"))
        (#\>
         ;; >>>= unsigned right-shift assign
         (let ((ch4 (when (< (+ pos 3) (length source)) (char source (+ pos 3)))))
           (when (and ch2 ch3 ch4
                      (char= ch2 #\>) (char= ch3 #\>) (char= ch4 #\=))
             (return-from lex-js-operator
               (values (make-js-token :T-OP ">>>=") (+ pos 4)))))
         ;; >>>
         (when (and ch2 ch3 (char= ch2 #\>) (char= ch3 #\>))
           (return-from lex-js-operator
             (values (make-js-token :T-OP ">>>") (+ pos 3))))
         ;; >>=
         (when (and ch2 ch3 (char= ch2 #\>) (char= ch3 #\=))
           (return-from lex-js-operator
             (values (make-js-token :T-OP ">>=") (+ pos 3))))
         ;; >>
         (tok2 ">>" :T-OP ">>")
         ;; >=
         (tok2 ">=" :T-OP ">=")
         (tok1 :T-OP ">"))
        (#\+
         ;; ++
         (tok2 "++" :T-OP "++")
         ;; +=
         (tok2 "+=" :T-OP "+=")
         (tok1 :T-OP "+"))
        (#\-
         ;; --
         (tok2 "--" :T-OP "--")
         ;; -=
         (tok2 "-=" :T-OP "-=")
         (tok1 :T-OP "-"))
        (#\*
         ;; **= exponent assign
         (when (and ch2 ch3 (char= ch2 #\*) (char= ch3 #\=))
           (return-from lex-js-operator
             (values (make-js-token :T-OP "**=") (+ pos 3))))
         ;; **
         (tok2 "**" :T-OP "**")
         ;; *=
         (tok2 "*=" :T-OP "*=")
         (tok1 :T-OP "*"))
        (#\/
         ;; /=
         (tok2 "/=" :T-OP "/=")
         (tok1 :T-OP "/"))
        (#\%
         ;; %=
         (tok2 "%=" :T-OP "%=")
         (tok1 :T-OP "%"))
        (#\&
         ;; &&=
         (when (and ch2 ch3 (char= ch2 #\&) (char= ch3 #\=))
           (return-from lex-js-operator
             (values (make-js-token :T-OP "&&=") (+ pos 3))))
         ;; &&
         (tok2 "&&" :T-OP "&&")
         ;; &=
         (tok2 "&=" :T-OP "&=")
         (tok1 :T-OP "&"))
        (#\|
         ;; ||=
         (when (and ch2 ch3 (char= ch2 #\|) (char= ch3 #\=))
           (return-from lex-js-operator
             (values (make-js-token :T-OP "||=") (+ pos 3))))
         ;; ||
         (tok2 "||" :T-OP "||")
         ;; |=
         (tok2 "|=" :T-OP "|=")
         (tok1 :T-OP "|"))
        (#\^
         ;; ^=
         (tok2 "^=" :T-OP "^=")
         (tok1 :T-OP "^"))
        (otherwise
         (let ((entry (assoc ch *%js-single-char-punctuator-tokens*)))
           (if entry
               (tok1 (cadr entry) (cddr entry))
               (error "JS lex error: unexpected character ~S at position ~D" ch pos))))))))

;;; Main tokenizer

(defun %js-lex-template-fallback-scan (source pos)
  "Scan raw template-literal content starting at POS (just past the opening
backtick) until the closing backtick, honoring simple backslash escapes. Used
only when js-lex-template (lexer-template.lisp) is not loaded.
Returns (values content new-pos) where NEW-POS is just past the closing
backtick."
  (let ((len (length source))
        (buf (make-array 64 :element-type 'character
                         :fill-pointer 0 :adjustable t)))
    (loop
      (when (>= pos len)
        (error "JS lex error: unterminated template literal"))
      (let ((tc (char source pos)))
        (cond
          ((char= tc #\`)
           (return (values (copy-seq buf) (1+ pos))))
          ((and (char= tc #\\) (< (1+ pos) len))
           (vector-push-extend (char source (1+ pos)) buf)
           (incf pos 2))
          (t
           (vector-push-extend tc buf)
           (incf pos)))))))

(defun %js-lex-hash-token (source pos)
  "Handle a '#' at POS: a mid-source hashbang comment (#!...), a private
identifier (#name), or a lex error. Returns (values tok new-pos); TOK is nil
when the character sequence is a comment to skip (no token emitted)."
  (let ((len (length source)))
    (cond
      ;; Hashbang #! at non-zero position: skip the line
      ((and (< (1+ pos) len) (char= (char source (1+ pos)) #\!))
       (values nil (skip-js-line-comment source (+ pos 2))))
      ;; Private identifier: # followed by identifier start
      ((and (< (1+ pos) len) (js-id-start-p (char source (1+ pos))))
       (lex-js-private-ident source (1+ pos)))
      (t
       (error "JS lex error: unexpected # at position ~D" pos)))))

(defun %js-lex-slash-token (source pos prev-token-type)
  "Handle a '/' at POS: a regex literal (when PREV-TOKEN-TYPE indicates a
value cannot precede, per js-regex-follows-p) or the division operator/'/='.
Returns (values tok new-pos new-prev-token-type)."
  (if (js-regex-follows-p prev-token-type)
      ;; js-lex-regex expects POS to be AFTER the opening '/', so skip it with
      ;; (1+ pos) — otherwise it sees the opening slash as an empty pattern's
      ;; closing slash and reads the pattern body as flags ("/ab+c/gi" ->
      ;; unknown flag 'a').
      (if (fboundp 'js-lex-regex)
          (multiple-value-bind (tok new-pos) (js-lex-regex source (1+ pos))
            (values tok new-pos :T-REGEX))
          (values (make-js-token :T-OP "/") (1+ pos) :T-OP))
      (multiple-value-bind (tok new-pos) (lex-js-operator source pos)
        (values tok new-pos (getf tok :type)))))

(defun tokenize-js-source (source)
  "Tokenize JavaScript SOURCE string into a list of token plists.
Returns a list ending with (:type :T-EOF :value nil).

Handles: identifiers, keywords, numbers, strings, operators, regex literals
(using js-regex-follows-p for disambiguation), template literals, private
identifiers, and hashbang comments at position 0."
  (let ((tokens nil)
        (pos 0)
        (len (length source))
        (prev-token-type nil))
    (loop
      ;; Skip whitespace and comments, with special hashbang handling.
      ;; The skip-js-whitespace-and-comments function handles hashbang at pos=0.
      (setf pos (skip-js-whitespace-and-comments source pos))
      (when (>= pos len)
        (push (make-js-token :T-EOF nil) tokens)
        (return))
      (let ((ch (char source pos)))
        (cond
          ;; String: double-quoted
          ((char= ch #\")
           (multiple-value-bind (str new-pos)
               (lex-js-string source (1+ pos) #\")
             (let ((tok (make-js-token :T-STRING str)))
               (push tok tokens)
               (setf prev-token-type :T-STRING
                     pos new-pos))))
          ;; String: single-quoted
          ((char= ch #\')
           (multiple-value-bind (str new-pos)
               (lex-js-string source (1+ pos) #\')
             (let ((tok (make-js-token :T-STRING str)))
               (push tok tokens)
               (setf prev-token-type :T-STRING
                     pos new-pos))))
          ;; Template literal: backtick
          ((char= ch #\`)
           (cond
             ;; If js-lex-template is available (defined in lexer-template.lisp), use it
             ((fboundp 'js-lex-template)
              ;; js-lex-template returns a SINGLE token (:T-STRING for a simple
              ;; template, or :T-TEMPLATE-PARTS for an interpolated one) — push it
              ;; as one token, not as a list of its plist elements.
              (multiple-value-bind (tok new-pos)
                  (js-lex-template source (1+ pos))
                (push tok tokens)
                (setf prev-token-type (getf tok :type)
                      pos new-pos)))
             ;; Otherwise emit :T-TEMPLATE-START and scan inline to closing backtick
             (t
              (let ((tok (make-js-token :T-TEMPLATE-START "`")))
                (push tok tokens)
                (setf prev-token-type :T-TEMPLATE-START)
                (incf pos)
                (multiple-value-bind (content new-pos)
                    (%js-lex-template-fallback-scan source pos)
                  (push (make-js-token :T-STRING content) tokens)
                  (setf prev-token-type :T-STRING
                        pos new-pos))))))
          ;; Number
          ((js-digit-p ch)
           (multiple-value-bind (tok new-pos) (lex-js-number source pos)
             (push tok tokens)
             (setf prev-token-type (getf tok :type)
                   pos new-pos)))
          ;; Identifier or keyword
          ((js-id-start-p ch)
           (multiple-value-bind (tok new-pos) (lex-js-identifier source pos)
             (push tok tokens)
             (setf prev-token-type (getf tok :type)
                   pos new-pos)))
          ;; Private identifier or hashbang
          ((char= ch #\#)
           (multiple-value-bind (tok new-pos) (%js-lex-hash-token source pos)
             (if tok
                 (progn (push tok tokens)
                        (setf prev-token-type :T-PRIVATE-IDENT
                              pos new-pos))
                 (setf pos new-pos))))
          ;; Slash: regex or division
          ((char= ch #\/)
           (multiple-value-bind (tok new-pos new-prev)
               (%js-lex-slash-token source pos prev-token-type)
             (push tok tokens)
             (setf prev-token-type new-prev
                   pos new-pos)))
          ;; Operators and punctuation
          (t
           (multiple-value-bind (tok new-pos) (lex-js-operator source pos)
             (push tok tokens)
             (setf prev-token-type (getf tok :type)
                   pos new-pos))))))
    (nreverse tokens)))
