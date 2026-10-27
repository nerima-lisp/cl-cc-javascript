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

(define-builder-table *js-operator-tokens*
    (:documentation
     "Every JS operator and punctuator spelling mapped to its token type.  A
token's value is always its own spelling, so the spelling is the only key
needed.  LEX-JS-OPERATOR consults this by maximal munch, which is why the
table needs no ordering: the longest spelling that matches the source wins.")
  ;; 4 characters
  (">>>=" :T-OP)
  ;; 3 characters
  ("..." :T-ELLIPSIS)
  ("??=" :T-OP)  ("===" :T-OP)  ("!==" :T-OP)  ("<<=" :T-OP)
  (">>>" :T-OP)  (">>=" :T-OP)  ("**=" :T-OP)  ("&&=" :T-OP)  ("||=" :T-OP)
  ;; 2 characters
  ("=>" :T-ARROW)
  ("?." :T-OP)  ("??" :T-OP)  ("==" :T-OP)  ("!=" :T-OP)
  ("<<" :T-OP)  ("<=" :T-OP)  (">>" :T-OP)  (">=" :T-OP)
  ("++" :T-OP)  ("+=" :T-OP)  ("--" :T-OP)  ("-=" :T-OP)
  ("**" :T-OP)  ("*=" :T-OP)  ("/=" :T-OP)  ("%=" :T-OP)
  ("&&" :T-OP)  ("&=" :T-OP)  ("||" :T-OP)  ("|=" :T-OP)  ("^=" :T-OP)
  ;; 1 character — operators
  ("." :T-DOT)  ("?" :T-QUESTION)
  ("=" :T-OP)  ("!" :T-OP)  ("<" :T-OP)  (">" :T-OP)
  ("+" :T-OP)  ("-" :T-OP)  ("*" :T-OP)  ("/" :T-OP)  ("%" :T-OP)
  ("&" :T-OP)  ("|" :T-OP)  ("^" :T-OP)  ("~" :T-OP)
  ;; 1 character — punctuators with no multi-character extension
  ("(" :T-LPAREN)    (")" :T-RPAREN)
  ("{" :T-LBRACE)    ("}" :T-RBRACE)
  ("[" :T-LBRACKET)  ("]" :T-RBRACKET)
  (";" :T-SEMI)      ("," :T-COMMA)
  ("@" :T-AT)        (":" :T-COLON))

(defconstant +js-max-operator-length+ 4
  "Length of the longest entry in *js-operator-tokens* (`>>>='), and so the
number of characters LEX-JS-OPERATOR's maximal munch starts from.")

(defun lex-js-operator (source pos)
  "Lex an operator or punctuation token at POS by maximal munch: try the
longest spelling in *js-operator-tokens* that fits, then shorter ones.
Returns (values token new-pos)."
  (loop with limit = (min +js-max-operator-length+ (- (length source) pos))
        for n from limit downto 1
        for spelling = (subseq source pos (+ pos n))
        for type = (gethash spelling *js-operator-tokens*)
        when type
          do (return (values (make-js-token type spelling) (+ pos n)))
        finally (error "JS lex error: unexpected character ~S at position ~D"
                       (char source pos) pos)))

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
