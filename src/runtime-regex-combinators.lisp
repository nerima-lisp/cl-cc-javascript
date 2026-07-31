;;;; packages/javascript/src/runtime-regex-combinators.lisp — JS RegExp building blocks
;;;;
;;;; The js-regexp struct, the escape-sequence data tables, the character-class
;;;; matcher, and the matcher-closure combinators (word boundary, capturing
;;;; group, greedy/bounded repetition) that %js-compile-pattern's recursive-
;;;; descent parser (runtime-regex.lisp) assembles into a compiled pattern.
;;;; Split out to keep that parser's own control flow — which combinator to
;;;; apply where — separate from what each combinator does.
;;;;
;;;; Load order: before runtime-regex.lisp, which calls every public name here.
(in-package :cl-cc/javascript)

;;; -----------------------------------------------------------------------
;;;  RegExp struct
;;; -----------------------------------------------------------------------
(defstruct (js-regexp (:conc-name js-regexp-))
  source     ; original pattern string
  flags      ; flags string "gim..."
  compiled   ; compiled NFA (a Lisp function for now)
  (num-groups 0) ; count of capturing groups (named + numbered) in the pattern
  group-names ; alist of (name . 1-based-index) for (?<name>...) groups
  global-p
  ignore-case-p
  multiline-p
  sticky-p
  last-index) ; for stateful matching with /g

(defun %js-regexp-p (x)
  (js-regexp-p x))

(defparameter *js-regex-max-compile-depth* 1000
  "Maximum group nesting depth %js-compile-pattern's mutually recursive
compile-atom/compile-seq/compile-alt will descend before signalling a
graceful parse error, rather than exhausting the control stack (CWE-674 DoS)
on a pattern like \"(((((...)))))\" with thousands of levels of nesting —
the same protection with-js-parse-depth (parser.lisp) already gives the
JS statement/expression parser, applied to the one other place in this
codebase that recurses on untrusted, attacker-controlled nesting depth.")

;;; -----------------------------------------------------------------------
;;;  Escape predicate data table
;;; -----------------------------------------------------------------------
(defparameter *%js-regex-escape-predicates* (list
    (cons
      #\d
      (lambda (c)
        (digit-char-p c)))
    (cons
      #\D
      (lambda (c)
        (not (digit-char-p c))))
    (cons
      #\w
      (lambda (c)
        (or (alphanumericp c) (char= c #\_))))
    (cons
      #\W
      (lambda (c)
        (not (or (alphanumericp c) (char= c #\_)))))
    (cons
      #\s
      (lambda (c)
        (member c '(#\Space #\Tab #\Newline #\Return #\Page))))
    (cons
      #\S
      (lambda (c)
        (not (member c '(#\Space #\Tab #\Newline #\Return #\Page)))))))

(defun %js-regex-escape-predicate (esc)
  "Return the character predicate for escape \\ESC, or nil for non-class escapes."
  (cdr (assoc esc *%js-regex-escape-predicates* :test #'char=)))

(defparameter *%js-regex-escape-literals* (list (cons #\n #\Newline) (cons #\t #\Tab) (cons #\r #\Return))
  "Control-character escapes that stand for a single literal character, the
counterpart of *%js-regex-escape-predicates* for escapes that match exactly
one char.  Every other escape denotes itself.")

(defun %js-regex-escape-literal (esc)
  "Return the literal character escape \\ESC stands for.  Escapes with no
entry in *%js-regex-escape-literals* are self-denoting (\\. is `.'), which is
what makes this total."
  (or (cdr (assoc esc *%js-regex-escape-literals* :test #'char=)) esc))

;;; -----------------------------------------------------------------------
;;;  Matcher-closure combinators — shared by every atom/quantifier %JS-COMPILE-
;;;  PATTERN's compile-atom/compile-seq build, kept separate from the parsing
;;;  logic that decides which combinator to apply where.
;;; -----------------------------------------------------------------------
(defun %js-regex-char-at (str i ic)
  "The character at STR[I], lowercased first when IC (case-insensitive
matching) is true. Every atom matcher that tests a character against a
predicate or literal reads it through here, instead of repeating the
case-fold conditional at each call site."
  (if ic (char-downcase (char str i))
    (char str i)))

(defun %js-regex-word-char-p (ch)
  "True when CH counts as a \\w word character for \\b/\\B boundary testing:
alphanumeric or underscore, JS's own \\w definition (*%JS-REGEX-ESCAPE-
PREDICATES* above uses the same rule for the \\w/\\W escapes)."
  (and ch (or (alphanumericp ch) (char= ch #\_))))

(defun %js-regex-word-boundary-p (str i)
  "True at zero-width position I in STR iff exactly one of the characters
immediately before and after it is a word character (JS's \\b) — a string
edge counts as a non-word character on that side."
  (let ((before (and (plusp i) (%js-regex-word-char-p (char str (1- i)))))
        (after (and (< i (length str)) (%js-regex-word-char-p (char str i)))))
    (if before (not after)
      (and after t))))

(defun %js-regex-capturing-group-matcher (inner-fn idx)
  "Wrap INNER-FN (a compiled group body) so that, on a successful match, it
records its (start . end) span at 0-based index (1- IDX) in the caller's
GROUPS vector before returning INNER-FN's own result unchanged. A repeated
group (under `*`/`+`) simply overwrites the span on each successful
iteration, so the final call before the quantifier stops wins — the same
last-iteration-captures rule JS itself uses. GROUPS may be nil (callers that
don't need capture data, like split, pass nil throughout), in which case this
degrades to INNER-FN with no side effect."
  (lambda (str i groups)
    (let ((result (funcall inner-fn str i groups)))
      (when (and result groups) (setf (aref groups (1- idx)) (cons i result)))
      result)))

(defun %js-regex-parse-brace-quantifier (pat pos)
  "Parse a `{n}`/`{n,}`/`{n,m}` bounded-repetition quantifier at POS (the
`{`). Returns (values min max end) when POS begins a well-formed one — MAX is
nil for the unbounded `{n,}` form — or nil when it doesn't (an invalid or
incomplete `{...}`, which JS's own Annex B grammar treats as literal
characters rather than a syntax error, so a non-match here must consume
nothing and let `{` fall through to compile-atom's literal-character case)."
  (let ((close (position #\} pat :start pos)))
    (when close
      (let* ((body (subseq pat (1+ pos) close))
             (comma (position #\, body)))
        (flet ((digits-or-empty-p (s) (or (zerop (length s)) (every #'digit-char-p s))))
          (when (and (plusp (length body))
                     (if comma
                         (and (plusp comma)
                              (every #'digit-char-p (subseq body 0 comma))
                              (digits-or-empty-p (subseq body (1+ comma))))
                         (every #'digit-char-p body)))
            (values (parse-integer body :end (or comma (length body)))
                    (cond ((null comma) (parse-integer body))
                          ((= (1+ comma) (length body)) nil)
                          (t (parse-integer body :start (1+ comma))))
                    (1+ close))))))))

(defun %js-regex-bounded-repeat-matcher (fn min max lazy)
  "Wrap FN (a compiled atom) to match between MIN and MAX times (inclusive;
MAX nil means unbounded), MIN of them mandatory — any failure before MIN
matches fails the whole repetition, consistent with this no-backtracking
engine's other quantifiers. The lazy variant stops right after the MIN
mandatory matches, the same simplification `*?` already applies (see
%JS-REGEX-GREEDY-MATCH's callers in runtime-regex.lisp: `*`'s MIN is 0, so
`*?` already 'matches 0 first') rather than backtracking to find the
shortest match the rest of the pattern needs."
  (lambda (str i groups)
    (block match
      (let ((pos i) (count 0))
        (dotimes (rep min)
          (declare (ignore rep))
          (let ((next (funcall fn str pos groups)))
            (unless next (return-from match))
            (setf pos next)
            (incf count)))
        (unless lazy
          (loop
            (when (and max (>= count max)) (return))
            (let ((next (funcall fn str pos groups)))
              (unless next (return))
              (setf pos next)
              (incf count))))
        pos))))

(defun %js-regex-greedy-match (fn str pos groups)
  "Repeatedly apply FN (a matcher closure: str pos groups -> new-pos-or-nil)
starting at POS, advancing as long as it keeps matching. Returns the final
position reached — POS itself if the very first attempt fails. Shared by the
`*`/`+` quantifier wrappers in compile-seq: `*` calls this directly (zero or
more matches), `+` calls it only after one required match already succeeded
(one or more)."
  (loop for next = (funcall fn str pos groups) then (funcall fn str next groups)
        while next
        do (setf pos next)
        finally (return pos)))

;;; -----------------------------------------------------------------------
;;;  Character-class matcher
;;; -----------------------------------------------------------------------
(defun %js-char-class-match-p (chars complement-p ch)
  "Test CH against a parsed char-class CHARS list (strings/ranges/predicates).
COMPLEMENT-P inverts the result."
  (let ((match
        (loop for item in chars
              thereis (cond
            ((characterp item) (char= ch item))
            ((and (consp item) (eq (car item) :range)) (char<= (cadr item) ch (caddr item)))
            ((functionp item) (funcall item ch))
            (t nil)))))
    (if complement-p (not match)
      match)))

(defun %js-compile-char-class (pattern pos)
  "Parse [...] at POS (after the [). Returns (values match-fn new-pos)."
  (let ((complement-p (and (< pos (length pattern))
                           (char= (char pattern pos) #\^)))
        (chars nil))
    (when complement-p (incf pos))
    (loop while (and (< pos (length pattern))
                     (not (char= (char pattern pos) #\])))
          do (let ((ch (char pattern pos)))
               (cond
                 ((char= ch #\\)
                  (incf pos)
                  (let* ((esc  (char pattern pos))
                         (item (or (%js-regex-escape-predicate esc)
                                   (%js-regex-escape-literal esc))))
                    (push item chars)
                    (incf pos)))
                 ;; Range a-z
                 ((and (< (+ pos 2) (length pattern))
                       (char= (char pattern (1+ pos)) #\-)
                       (not (char= (char pattern (+ pos 2)) #\])))
                  (let ((from ch) (to (char pattern (+ pos 2))))
                    (push (list :range from to) chars)
                    (incf pos 3)))
                 (t (push ch chars) (incf pos)))))
    (when (and (< pos (length pattern)) (char= (char pattern pos) #\]))
      (incf pos))
    (let ((chars-snap (nreverse chars)) (comp complement-p))
      (values (lambda (c) (%js-char-class-match-p chars-snap comp c)) pos))))
