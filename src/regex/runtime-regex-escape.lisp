(in-package #:cl-cc/javascript/regex)

(defun %js-regexp-ascii-alnum-p (ch)
  (or
    (and (char>= ch #\0) (char<= ch #\9))
    (and (char>= ch #\A) (char<= ch #\Z))
    (and (char>= ch #\a) (char<= ch #\z))))

(defun %js-regexp-hex2 (code out)
  (format out "\\x~2,'0X" code))

(defun %js-regexp-unicode-escape (code out)
  (format out "\\u~4,'0X" code))

(defun %js-regexp-escape (str)
  "ES2025 RegExp.escape: escape a string for literal use in a RegExp pattern."
  (with-output-to-string (out)
    (loop for ch across (%js-to-string str)
          for first = t then nil
          for code = (char-code ch)
          do (cond
        ((and first (%js-regexp-ascii-alnum-p ch)) (%js-regexp-hex2 code out))
        ((member
            ch
            '(#\^ #\$ #\\ #\. #\* #\+ #\? #\( #\) #\[ #\] #\{ #\} #\| #\/)
            :test
            #'char=)
          (write-char #\\ out)
          (write-char ch out))
        ((member
            ch
            '(#\, #\- #\= #\< #\> #\# #\& #\! #\% #\: #\; #\@ #\~ #\' #\` #\")
            :test
            #'char=)
          (%js-regexp-hex2 code out))
        ((char= ch #\Newline) (write-string "\\n" out))
        ((char= ch #\Return) (write-string "\\r" out))
        ((char= ch #\Tab) (write-string "\\t" out))
        ((char= ch #\Page) (write-string "\\f" out))
        ((char= ch #\Space) (write-string "\\x20" out))
        ((or (< code #x20) (= code #x2028) (= code #x2029))
          (if (< code #x100) (%js-regexp-hex2 code out)
            (%js-regexp-unicode-escape code out)))
        (t (write-char ch out))))))
