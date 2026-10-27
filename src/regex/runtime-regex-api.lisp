;;;; packages/javascript/src/runtime-regex-api.lisp — JS RegExp public API
;;;;
;;;; Public matching API: %js-make-regex, %js-regex-exec, %js-regex-test,
;;;; %js-string-match-regex, %js-string-search-regex, %js-string-replace-regex,
;;;; regex-replace-placeholders, %js-string-replace-all-regex, %js-string-split-regex.
;;;;
;;;; Load order: after runtime-regex.lisp (needs js-regexp struct, compiled slot,
;;;; %js-compile-pattern, and js-regexp-* accessors).

(in-package :cl-cc/javascript)

;;; -----------------------------------------------------------------------
;;;  Public API — matching
;;; -----------------------------------------------------------------------

(defun %js-make-regex (pattern &optional (flags ""))
  "Create a JS RegExp from PATTERN and FLAGS strings."
  (let* ((ic (find #\i flags))
         (ml (find #\m flags))
         (gl (find #\g flags))
         (st (find #\y flags)))
    (multiple-value-bind (compiled num-groups group-names)
        (handler-case (%js-compile-pattern pattern :ignore-case-p ic :multiline-p ml)
          (error () (values nil 0 nil)))
      (make-js-regexp
       :source pattern :flags flags
       :compiled compiled
       :num-groups num-groups
       :group-names group-names
       :global-p (not (null gl))
       :ignore-case-p (not (null ic))
       :multiline-p (not (null ml))
       :sticky-p (not (null st))
       :last-index 0))))

(defun %js-regex-capture-substring (str span)
  "The captured substring for SPAN (a (start . end) cons), or +js-undefined+
when the group did not participate in the match (SPAN is nil — e.g. the
losing side of an alternation, or an unexercised iteration of a quantified
group)."
  (if span (subseq str (car span) (cdr span)) +js-undefined+))

(defun %js-regex-build-match-groups-object (re str groups)
  "The `groups' property of a match-result object: undefined when RE has no
named capturing groups, else a null-prototype object mapping each name to
its captured substring (or undefined, per %js-regex-capture-substring)."
  (let ((names (js-regexp-group-names re)))
    (if names
        (let ((go (%js-object-create +js-null+)))
          (dolist (pair names go)
            (setf (gethash (car pair) go)
                  (%js-regex-capture-substring str (aref groups (1- (cdr pair)))))))
        +js-undefined+)))

(defun %js-regex-build-match-object (re str index match-str groups)
  "Assemble the match-result object exec/match/replace share: `index',
`input', the whole match as \"0\", each capturing group as \"1\"..\"N\", and
`groups' for named captures."
  (let ((m (%js-make-object "index" (coerce index 'double-float)
                             "input" str
                             "0" match-str)))
    (loop for i from 1 to (length groups)
          do (setf (gethash (princ-to-string i) m)
                   (%js-regex-capture-substring str (aref groups (1- i)))))
    (setf (gethash "groups" m) (%js-regex-build-match-groups-object re str groups))
    m))

(defun %js-regex-exec (re str &optional (start 0))
  "Execute RE against STR starting at START. Returns a match-result object
(see %js-regex-build-match-object) or null."
  (let ((fn (js-regexp-compiled re))
        (n (length str))
        (num-groups (js-regexp-num-groups re)))
    (unless fn (return-from %js-regex-exec +js-null+))
    (loop for i from start to n
          for groups = (make-array num-groups :initial-element nil)
          for end = (funcall fn str i groups)
          when end
            do (let ((match-str (subseq str i end)))
                 (when (js-regexp-global-p re)
                   (setf (js-regexp-last-index re) end))
                 (return (%js-regex-build-match-object re str i match-str groups)))
          finally (progn
                    (when (js-regexp-global-p re)
                      (setf (js-regexp-last-index re) 0))
                    (return +js-null+)))))

(defun %js-regex-test (re str)
  "RegExp.prototype.test(str) — return t if match found."
  (not (eq +js-null+ (%js-regex-exec re str 0))))

(defun %js-collect-regex-matches (re str wrap-fn)
  "Scan STR for every match of RE, advancing past each match's end so a /g
scan never re-finds the same match. Each raw match string is passed through
WRAP-FN before being collected. Returns an adjustable vector of the wrapped
values (possibly empty)."
  (let ((results (make-array 0 :element-type t :adjustable t :fill-pointer 0))
        (pos 0))
    (loop
      (let ((m (%js-regex-exec re str pos)))
        (when (eq m +js-null+) (return))
        (let* ((match (gethash "0" m))
               (idx (truncate (gethash "index" m))))
          (vector-push-extend (funcall wrap-fn match) results)
          (setf pos (max (1+ pos) (+ idx (max 1 (length match))))))))
    results))

(defun %js-string-match-regex (str re)
  "String.prototype.match(regexp)."
  (if (js-regexp-p re)
      (if (js-regexp-global-p re)
          ;; /g flag: collect all matches rather than just the first.
          (let ((results (%js-collect-regex-matches re str #'identity)))
            (if (zerop (length results)) +js-null+ results))
          ;; No /g: return first match object
          (%js-regex-exec re str 0))
      ;; String pattern: use substring search
      (%js-string-match str (%js-to-string re))))

(defun %js-string-match-all-regex (str re)
  "String.prototype.matchAll — collect all matches (regexp or string pattern)."
  (if (js-regexp-p re)
      (%js-collect-regex-matches re str #'%js-make-array)
      (%js-string-match-all str (%js-to-string re))))

(defun %js-string-search-regex (str re)
  "String.prototype.search(regexp) — return index or -1."
  (if (js-regexp-p re)
      (let ((m (%js-regex-exec re str 0)))
        (if (eq m +js-null+) -1 (truncate (gethash "index" m))))
      (%js-string-search str (%js-to-string re))))

(defun %js-string-replace-regex (str re replacement)
  "String.prototype.replace(regexp, replacement)."
  (if (js-regexp-p re)
      (let ((fn (js-regexp-compiled re))
            (result (make-array 0 :adjustable t :fill-pointer 0 :element-type 'character))
            (pos 0))
        (if fn
            (loop
              (let ((m (%js-regex-exec re str pos)))
                (when (eq m +js-null+)
                  (loop for i from pos below (length str)
                        do (vector-push-extend (char str i) result))
                  (return (coerce result 'string)))
                (let* ((match-start (truncate (gethash "index" m)))
                       (match-str (gethash "0" m))
                       (match-end (+ match-start (length match-str)))
                       (next-pos (if (= match-end pos) (1+ pos) match-end))
                       (repl (if (functionp replacement)
                                 (%js-to-string (%js-funcall replacement match-str match-start str))
                                 (let ((r (%js-to-string replacement)))
                                   (regex-replace-placeholders r m)))))
                  (loop for i from pos below match-start
                        do (vector-push-extend (char str i) result))
                  (loop for c across repl
                        do (vector-push-extend c result))
                  (setf pos next-pos)
                  (unless (js-regexp-global-p re)
                    (loop for i from match-end below (length str)
                          do (vector-push-extend (char str i) result))
                    (return (coerce result 'string))))))
            (%js-string-replace str (%js-to-string (js-regexp-source re)) replacement)))
      (%js-string-replace str (%js-to-string re) replacement)))

(defun %js-regex-numbered-group-value (m n)
  "The captured substring for group N (1-based; N=0 is never a group
reference — \"0\" names the whole match in M, not a capture), or nil when N
is not a group this pattern's match object M carries at all (an out-of-range
$N is left as literal text in the replacement, per the JS spec) — as opposed
to a group that exists but did not participate, whose value is
+js-undefined+ and which this expands to the empty string."
  (multiple-value-bind (v found) (and (plusp n) (gethash (princ-to-string n) m))
    (cond ((not found) nil)
          ((eq v +js-undefined+) "")
          (t v))))

(defun %js-regex-named-escape-text (template m i)
  "$<name> starting at I (TEMPLATE[I]=$, TEMPLATE[I+1]=<): (values text
new-i), or NIL if the $<name> is unterminated (no closing >), in which case
it is not a recognized escape at all."
  (let ((close (position #\> template :start (+ i 2))))
    (when close
      (let* ((name (subseq template (+ i 2) close))
             (groups (gethash "groups" m))
             (v (and (%js-ht-p groups) (gethash name groups))))
        (values (if (or (null v) (eq v +js-undefined+)) "" v) (1+ close))))))

(defun %js-regex-numbered-escape-text (template m i len next-char)
  "$N or $NN starting at I (TEMPLATE[I]=$, NEXT-CHAR=TEMPLATE[I+1], a digit):
(values text new-i), greedily preferring a 2-digit group number over a
1-digit one per the JS spec, or NIL if neither digit count names a group
this pattern actually has."
  (let* ((two-digit-p (and (< (+ i 2) len) (digit-char-p (char template (+ i 2)))))
         (two-digit-v (and two-digit-p
                            (%js-regex-numbered-group-value
                              m (parse-integer template :start (1+ i) :end (+ i 3))))))
    (if two-digit-v
        (values two-digit-v (+ i 3))
        (let ((one-digit-v (%js-regex-numbered-group-value m (digit-char-p next-char))))
          (when one-digit-v (values one-digit-v (+ i 2)))))))

(defun %js-regex-dollar-escape-text (template m i len)
  "If TEMPLATE has a recognized $-escape starting at I (TEMPLATE[I]=$),
return (values replacement-text new-i); NIL when TEMPLATE[I+1] doesn't start
one of $&/$$/$<name>/$N, meaning the $ is copied through literally instead."
  (when (< (1+ i) len)
    (let ((next (char template (1+ i))))
      (cond
        ((char= next #\&) (values (gethash "0" m) (+ i 2)))
        ((char= next #\$) (values "$" (+ i 2)))
        ((char= next #\<) (%js-regex-named-escape-text template m i))
        ((digit-char-p next) (%js-regex-numbered-escape-text template m i len next))))))

(defun regex-replace-placeholders (template m)
  "Expand $&, $$, $1-$99, and $<name> in TEMPLATE against match-result object
M (see %js-regex-build-match-object). An escape that doesn't resolve — an
out-of-range group number, an unterminated $<name>, or $ followed by
anything else — is copied through literally."
  (let ((out (make-array 0 :adjustable t :fill-pointer 0 :element-type 'character))
        (len (length template)))
    (loop with i = 0
          while (< i len)
          do (multiple-value-bind (text next-i)
                 (and (char= (char template i) #\$)
                      (%js-regex-dollar-escape-text template m i len))
               (if text
                   (progn (loop for c across text do (vector-push-extend c out))
                          (setf i next-i))
                   (progn (vector-push-extend (char template i) out) (incf i)))))
    (coerce out 'string)))

(defun %js-string-replace-all-regex (str re replacement)
  "String.prototype.replaceAll with regex (must have /g flag)."
  (if (js-regexp-p re)
      (%js-string-replace-regex str re replacement)
      (%js-string-replace-all str (%js-to-string re) replacement)))

(defun %js-string-split-regex (str &optional re limit)
  "String.prototype.split with regex separator. A capturing group in RE
splices its captured substring (or undefined, if that group didn't
participate) into the result array right after the field it separates, per
the spec -- e.g. \"2023-01-15\".split(/(-)/) -> [\"2023\",\"-\",\"01\",\"-\",\"15\"]."
  (if (or (null re) (eq re +js-undefined+))
      (%js-string-split str)
  (if (js-regexp-p re)
      (let* ((fn (js-regexp-compiled re))
             (num-groups (js-regexp-num-groups re))
             (results (make-array 0 :element-type t :adjustable t :fill-pointer 0))
             (max-count (if (and limit (not (eq limit +js-undefined+)))
                            (truncate limit)
                            most-positive-fixnum))
             (pos 0))
        (when (or (null fn) (string= str ""))
          (return-from %js-string-split-regex
            (%js-string-split str (%js-to-string (js-regexp-source re)) limit)))
        ;; Scan forward for each separator match; the text between matches is
        ;; a field. Zero-width matches only split between characters.
        (let ((n (length str)))
          (loop
            (let ((found nil) (found-end nil) (found-groups nil))
              (loop for i from pos to n
                    do (let* ((groups (make-array num-groups :initial-element nil))
                              (end (funcall fn str i groups)))
                         (when (and end
                                    (or (> end i)
                                        (and (> i pos) (< i n))))
                           (setf found i found-end (max end i) found-groups groups)
                           (return))))
              (if found
                  (progn
                    (vector-push-extend (subseq str pos found) results)
                    (loop for g across found-groups
                          while (< (length results) max-count)
                          do (vector-push-extend
                              (if g (subseq str (car g) (cdr g)) +js-undefined+)
                              results))
                    (setf pos found-end))
                  (progn
                    (vector-push-extend (subseq str pos) results)
                    (return)))
              (when (>= (length results) max-count) (return)))))
        results)
      (%js-string-split str (%js-to-string re) limit))))
