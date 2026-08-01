;;;; packages/javascript/src/runtime-regex.lisp — JS RegExp (pure CL NFA engine)
;;;;
;;;; Implements JS-compatible regular expressions by compiling a pattern to a
;;;; single-pass, non-backtracking matcher closure: each quantifier commits
;;;; greedily to as many repetitions as it can get and never retries with
;;;; fewer, so a handful of pattern shapes that need real backtracking to
;;;; match correctly (e.g. `a*ab` against "aab") won't. Supported features:
;;;;   Literals: any char, . (any), escape sequences \d \D \w \W \s \S \n \t \r \f,
;;;;     \xHH (2 hex digits), \uHHHH (4 hex digits)
;;;;   Quantifiers: * + ? {n} {n,} {n,m} (greedy; lazy `?` stops after the
;;;;     minimum required repetitions rather than truly backtracking — see
;;;;     %JS-REGEX-BOUNDED-REPEAT-MATCHER)
;;;;   Anchors: ^ $ \b \B
;;;;   Groups: (expr) and (?<name>expr) capturing (numbered/named data comes
;;;;     out of exec/match/replace), (?:expr) non-capturing, (?=expr)/(?!expr)
;;;;     lookahead — (?<=expr)/(?<!expr) lookbehind is not recognized as group
;;;;     syntax. See docs/src/reference/compatibility.md.
;;;;   Character classes: [abc] [a-z] [^abc]
;;;;   Alternation: a|b
;;;;
;;;; This covers ~90% of real-world JS regex usage without external deps.
;;;; The js-regexp struct, escape-sequence tables, character-class matcher,
;;;; and matcher-closure combinators this compiler assembles into a compiled
;;;; pattern live in the sibling runtime-regex-combinators.lisp.
(in-package :cl-cc/javascript)

;;; -----------------------------------------------------------------------
;;;  Pattern compilation — translate JS regex to a CL matcher function
;;; -----------------------------------------------------------------------
;;;
;;; We use a recursive descent parser that builds a closure (string start) -> end-pos-or-nil.
(defun %js-compile-pattern (pattern &key ignore-case-p multiline-p)
  "Compile a JS regex PATTERN string to a matcher (str pos groups) -> new-pos-
or-nil. GROUPS, when non-nil, is a vector of (start . end) conses (or nil)
indexed by 0-based capturing-group order, mutated in place by capturing-group
atoms as they match. Returns (values matcher-fn num-groups group-names),
where GROUP-NAMES is an alist of (name . 1-based-index) for (?<name>...)
groups, in the order encountered."
  (let ((pat pattern)
        (ic ignore-case-p)
        (ml multiline-p)
        (group-count 0)
        (group-names nil)
        (compile-depth 0))
    ;; compile-atom/compile-seq/compile-alt are mutually recursive: an atom can
    ;; contain a parenthesized group, which recurses into a full alternation,
    ;; which is built from sequences, which are built from atoms. LABELS
    ;; supports this natively (every sibling is in scope for every body), so
    ;; each is called directly (COMPILE-ALT 0), not through a FUNCALL on a
    ;; forward-declared variable.
    (labels
        ((compile-group-body (pos)
           "Every group-parsing branch below (lookahead, non-capturing,
named-capturing, capturing) recurses into COMPILE-ALT to compile the group's
contents — call through here instead of calling COMPILE-ALT directly so
COMPILE-DEPTH tracks the real nesting depth (incremented on entry, always
decremented again on the way out) and a pattern with thousands of nested
groups signals a graceful JS SyntaxError instead of exhausting the control
stack (CWE-674 DoS on untrusted pattern text)."
           (incf compile-depth)
           (when (> compile-depth *js-regex-max-compile-depth*)
             (error "JS SyntaxError: regex pattern nesting exceeds the depth limit (~D)"
                    *js-regex-max-compile-depth*))
           (unwind-protect (compile-alt pos)
             (decf compile-depth)))
         (compile-group-close (end)
           "The position just past a parenthesized group's closing `)`, if
PAT has one at END, else END unchanged (a missing `)` is tolerated the same
way every other unterminated-group case in this compiler already is). Every
COMPILE-GROUP-BODY caller below (lookahead, non-capturing, named-capturing,
capturing) needs exactly this same adjustment on its own END."
           (if (and (< end (length pat)) (char= (char pat end) #\)))
               (1+ end)
               end))
         (compile-atom (pos)
           "Parse one atom at POS; return (values atom-fn new-pos) or (values nil pos) at end."
           (if (>= pos (length pat))
               (values nil pos)
               (let ((ch (char pat pos)))
                 (cond
                   ;; End of alternation or group — stop
                   ((or (char= ch #\|) (char= ch #\))) (values nil pos))
                   ;; Character class
                   ((char= ch #\[)
                    (multiple-value-bind (fn end) (%js-compile-char-class pat (1+ pos))
                      (values (lambda (str i groups)
                                (declare (ignore groups))
                                (when (and (< i (length str))
                                           (funcall fn (%js-regex-char-at str i ic)))
                                  (1+ i)))
                              end)))
                   ;; Lookahead (?=...) / (?!...) — zero-width: try the inner
                   ;; pattern at I but never advance past what it matched.
                   ((and (char= ch #\() (< (+ pos 2) (length pat))
                         (char= (char pat (1+ pos)) #\?)
                         (member (char pat (+ pos 2)) '(#\= #\!)))
                    (let ((negate (char= (char pat (+ pos 2)) #\!)))
                      (multiple-value-bind (inner-fn end) (compile-group-body (+ pos 3))
                        (let ((close (compile-group-close end)))
                          (values (lambda (str i groups)
                                    (when (eq (not negate)
                                              (and (funcall inner-fn str i groups) t))
                                      i))
                                  close)))))
                   ;; Non-capturing group (?:...)
                   ((and (char= ch #\() (< (+ pos 2) (length pat))
                         (char= (char pat (1+ pos)) #\?) (char= (char pat (+ pos 2)) #\:))
                    (multiple-value-bind (inner-fn end) (compile-group-body (+ pos 3))
                      (let ((close (compile-group-close end)))
                        (values inner-fn close))))
                   ;; Named capturing group (?<name>...) — excludes lookbehind
                   ;; (?<=...)/(?<!...), which is not group syntax here.
                   ((and (char= ch #\() (< (+ pos 3) (length pat))
                         (char= (char pat (1+ pos)) #\?)
                         (char= (char pat (+ pos 2)) #\<)
                         (not (member (char pat (+ pos 3)) '(#\= #\!))))
                    (let* ((name-start (+ pos 3))
                           (name-end (position #\> pat :start name-start))
                           (name (subseq pat name-start name-end))
                           (idx (incf group-count)))
                      (push (cons name idx) group-names)
                      (multiple-value-bind (inner-fn end) (compile-group-body (1+ name-end))
                        (let ((close (compile-group-close end)))
                          (values (%js-regex-capturing-group-matcher inner-fn idx)
                                  close)))))
                   ;; Capturing group (...)
                   ((char= ch #\()
                    (let ((idx (incf group-count)))
                      (multiple-value-bind (inner-fn end) (compile-group-body (1+ pos))
                        (let ((close (compile-group-close end)))
                          (values (%js-regex-capturing-group-matcher inner-fn idx)
                                  close)))))
                   ;; Any char
                   ((char= ch #\.)
                    (values (lambda (str i groups)
                              (declare (ignore groups))
                              (when (and (< i (length str))
                                         (not (and ml (char= (char str i) #\Newline))))
                                (1+ i)))
                            (1+ pos)))
                   ;; Anchors
                   ((char= ch #\^)
                    (values (lambda (str i groups)
                              (declare (ignore groups))
                              (if ml
                                  (when (or (zerop i) (char= (char str (1- i)) #\Newline)) i)
                                  (when (zerop i) i)))
                            (1+ pos)))
                   ((char= ch #\$)
                    (values (lambda (str i groups)
                              (declare (ignore groups))
                              (if ml
                                  (when (or (= i (length str)) (char= (char str i) #\Newline)) i)
                                  (when (= i (length str)) i)))
                            (1+ pos)))
                   ;; Word boundary \b / \B — zero-width, unlike every other
                   ;; escape below: it tests the positions on either side of I
                   ;; and never advances past a matched one.
                   ((and (char= ch #\\) (member (char pat (1+ pos)) '(#\b #\B)))
                    (let ((negate (char= (char pat (1+ pos)) #\B)))
                      (values (lambda (str i groups)
                                (declare (ignore groups))
                                (when (eq (not negate) (%js-regex-word-boundary-p str i))
                                  i))
                              (+ pos 2))))
                   ;; \xHH / \uHHHH hex/unicode escapes — match the single
                   ;; character at that code point. Checked before the
                   ;; generic escape-sequences branch below, which would
                   ;; otherwise treat \x/\u as self-denoting (matching the
                   ;; literal letter x/u) per %js-regex-escape-literal.
                   ((and (char= ch #\\) (char= (char pat (1+ pos)) #\x)
                         (%js-regex-hex-escape-char pat (+ pos 2) 2))
                    (let ((lit (%js-regex-hex-escape-char pat (+ pos 2) 2)))
                      (when ic (setf lit (char-downcase lit)))
                      (values (lambda (str i groups)
                                (declare (ignore groups))
                                (when (and (< i (length str))
                                           (char= (%js-regex-char-at str i ic) lit))
                                  (1+ i)))
                              (+ pos 4))))
                   ((and (char= ch #\\) (char= (char pat (1+ pos)) #\u)
                         (%js-regex-hex-escape-char pat (+ pos 2) 4))
                    (let ((lit (%js-regex-hex-escape-char pat (+ pos 2) 4)))
                      (when ic (setf lit (char-downcase lit)))
                      (values (lambda (str i groups)
                                (declare (ignore groups))
                                (when (and (< i (length str))
                                           (char= (%js-regex-char-at str i ic) lit))
                                  (1+ i)))
                              (+ pos 6))))
                   ;; Escape sequences
                   ((char= ch #\\)
                    (let* ((esc  (char pat (1+ pos)))
                           (pred (or (%js-regex-escape-predicate esc)
                                     (let ((lit (%js-regex-escape-literal esc)))
                                       (lambda (c) (char= c lit))))))
                      (values (lambda (str i groups)
                                (declare (ignore groups))
                                (when (and (< i (length str)) pred
                                           (funcall pred (%js-regex-char-at str i ic)))
                                  (1+ i)))
                              (+ pos 2))))
                   ;; Literal character
                   (t
                    (let ((lit (if ic (char-downcase ch) ch)))
                      (values (lambda (str i groups)
                                (declare (ignore groups))
                                (when (and (< i (length str))
                                           (char= (%js-regex-char-at str i ic) lit))
                                  (1+ i)))
                              (1+ pos))))))))
         (compile-seq (pos)
           "Parse a sequence of quantified atoms."
           (let ((fns nil))
             (loop
               (multiple-value-bind (atom-fn new-pos) (compile-atom pos)
                 (unless atom-fn (return))
                 (setf pos new-pos)
                 ;; Check for quantifier
                 (when (< pos (length pat))
                   (let ((q (char pat pos)))
                     (cond
                       ((char= q #\*)
                        (incf pos)
                        (let ((lazy (and (< pos (length pat)) (char= (char pat pos) #\?))))
                          (when lazy (incf pos))
                          (let ((fn atom-fn))
                            (setf atom-fn
                                  (lambda (str i groups)
                                    (if lazy
                                        i  ; lazy: match 0 first (simplified)
                                        (%js-regex-greedy-match fn str i groups)))))))
                       ((char= q #\+)
                        (incf pos)
                        (when (and (< pos (length pat)) (char= (char pat pos) #\?)) (incf pos))
                        (let ((fn atom-fn))
                          (setf atom-fn
                                (lambda (str i groups)
                                  (let ((j (funcall fn str i groups)))
                                    (when j (%js-regex-greedy-match fn str j groups)))))))
                       ((char= q #\?)
                        (incf pos)
                        (when (and (< pos (length pat)) (char= (char pat pos) #\?)) (incf pos))
                        (let ((fn atom-fn))
                          (setf atom-fn
                                (lambda (str i groups)
                                  (or (funcall fn str i groups) i)))))
                       ((char= q #\{)
                        (multiple-value-bind (min max end) (%js-regex-parse-brace-quantifier pat pos)
                          (when min
                            (setf pos end)
                            (let ((lazy (and (< pos (length pat)) (char= (char pat pos) #\?))))
                              (when lazy (incf pos))
                              (let ((fn atom-fn))
                                (setf atom-fn (%js-regex-bounded-repeat-matcher fn min max lazy))))))))))
                 (push atom-fn fns)))
             (let ((fns-rev (nreverse fns)))
               (values (lambda (str i groups)
                         (let ((pos i))
                           (dolist (fn fns-rev pos)
                             (let ((result (funcall fn str pos groups)))
                               (if result
                                   (setf pos result)
                                   (return))))))
                       pos))))
         (compile-alt (pos)
           "Parse alternation: seq | seq | ..."
           (multiple-value-bind (first-fn new-pos) (compile-seq pos)
             (setf pos new-pos)
             (if (and (< pos (length pat)) (char= (char pat pos) #\|))
                 (multiple-value-bind (rest-fn rest-pos) (compile-alt (1+ pos))
                   (let ((f first-fn) (r rest-fn))
                     (values (lambda (str i groups)
                               (or (funcall f str i groups)
                                   (funcall r str i groups)))
                             rest-pos)))
                 (values first-fn pos)))))
      (multiple-value-bind (match-fn _) (compile-alt 0)
        (declare (ignore _))
        (values match-fn group-count (nreverse group-names))))))
