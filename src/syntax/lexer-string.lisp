(in-package #:cl-cc/javascript/syntax)

;;; String literal lexer
(defun %js-lex-string-escape-char (source pos buf)
  "Process the escape-sequence body starting at POS (the position right after
the backslash), pushing the resulting character(s) onto BUF.
Handles \\uXXXX, \\u{XXXXXX}, \\xXX, and the standard single-char escapes.
Returns NEW-POS just past the consumed escape."
  (let ((esc (char source pos)))
    (incf pos)
    (cond
      ;; Unicode escape \uXXXX or \u{XXXXXX}
      ((char= esc #\u)
       (cond
         ;; \u{hex-digits} — ES2015 code point escape
         ((and (< pos (length source)) (char= (char source pos) #\{))
          (incf pos)
          (let ((hex-start pos))
            (loop while (and (< pos (length source))
                             (js-hex-digit-p (char source pos)))
                  do (incf pos))
            (unless (and (< pos (length source))
                         (char= (char source pos) #\}))
              (error "JS lex error: expected } in \\u{} escape"))
            (let* ((hex-str (subseq source hex-start pos))
                   (code-point (parse-integer hex-str :radix 16)))
              (incf pos) ; consume }
              (vector-push-extend (code-char code-point) buf))))
         ;; \uXXXX — 4 hex digits
         (t
          (when (> (+ pos 4) (length source))
            (error "JS lex error: incomplete \\uXXXX escape"))
          (let* ((hex-str (subseq source pos (+ pos 4)))
                 (code-point (parse-integer hex-str :radix 16)))
            (incf pos 4)
            (vector-push-extend (code-char code-point) buf)))))
      ;; Hex escape \xXX
      ((char= esc #\x)
       (when (> (+ pos 2) (length source))
         (error "JS lex error: incomplete \\xXX escape"))
       (let* ((hex-str (subseq source pos (+ pos 2)))
              (code-point (parse-integer hex-str :radix 16)))
         (incf pos 2)
         (vector-push-extend (code-char code-point) buf)))
      ;; Standard single-char escapes
      (t
       (vector-push-extend
        (case esc
          (#\n  #\Newline)
          (#\r  #\Return)
          (#\t  #\Tab)
          (#\b  #\Backspace)
          (#\f  #\Page)
          (#\v  (code-char 11))    ; vertical tab
          (#\0  #\Null)
          (#\\  #\\)
          (#\'  #\')
          (#\"  #\")
          (otherwise esc))
        buf)))
    pos))

(defun lex-js-string (source pos quote-char)
  "Lex a quoted string starting AFTER the opening quote character.
QUOTE-CHAR is either #\\' or #\\\".
Handles escape sequences including \\uXXXX, \\u{XXXXXX}, \\xXX.
Returns (values string-content new-pos)."
  (let ((buf (make-array 64 :element-type 'character :fill-pointer 0 :adjustable t)))
    (loop
      (when (>= pos (length source))
        (error "JS lex error: unterminated string literal"))
      (let ((ch (char source pos)))
        (cond
          ;; Closing quote
          ((char= ch quote-char)
           (return (values (copy-seq buf) (1+ pos))))
          ;; Newline in string (not allowed in non-template strings)
          ((or (char= ch #\Newline) (char= ch #\Return))
           (error "JS lex error: unterminated string literal (newline)"))
          ;; Escape sequence
          ((char= ch #\\)
           (incf pos)
           (when (>= pos (length source))
             (error "JS lex error: trailing backslash in string"))
           (setf pos (%js-lex-string-escape-char source pos buf)))
          ;; Normal character
          (t
           (vector-push-extend ch buf)
           (incf pos)))))))
