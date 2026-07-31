;;;; t/runtime-regex-test.lisp
;;;;
;;;; Split from runtime-method-resolver-test.lisp: the RegExp public API —
;;;; test/exec, flags/lastIndex, the String.prototype regex-taking methods
;;;; (match/search/replace/replaceAll/split), and pattern-branch coverage
;;;; (char classes, groups, anchors, lazy quantifiers).
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr)

(in-package :cl-cc-javascript/test)

;;; ─── RegExp public API ───────────────────────────────────────────────────────

(it-sequential "js-rt-regex-test-match"
  (let ((re (cl-cc/javascript::%js-make-regex "hello")))
    (expect (cl-cc/javascript::%js-regex-test re "say hello world") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test re "goodbye") :to-be-falsy)))

(it-sequential "js-rt-regex-exec-returns-match"
  (let* ((re (cl-cc/javascript::%js-make-regex "lo"))
         (m  (cl-cc/javascript::%js-regex-exec re "hello" 0)))
    (expect (eq m cl-cc/javascript::+js-null+) :to-be-falsy)
    (expect (gethash "0" m) :to-equal "lo")
    (expect (= 3 (truncate (gethash "index" m))) :to-be-truthy)))

(it-sequential "js-rt-regex-exec-no-match"
  (let* ((re (cl-cc/javascript::%js-make-regex "xyz"))
         (m  (cl-cc/javascript::%js-regex-exec re "hello" 0)))
    (expect m :to-be cl-cc/javascript::+js-null+)))

(it-sequential "js-rt-regex-flags-and-last-index"
  (let ((re (cl-cc/javascript::%js-make-regex "l" "gimy")))
    (expect (cl-cc/javascript::js-regexp-ignore-case-p re) :to-be-truthy)
    (expect (cl-cc/javascript::js-regexp-multiline-p re) :to-be-truthy)
    (expect (cl-cc/javascript::js-regexp-global-p re) :to-be-truthy)
    (expect (cl-cc/javascript::js-regexp-sticky-p re) :to-be-truthy)
    (let* ((exec-re (cl-cc/javascript::make-js-regexp
                     :source "l"
                     :flags "g"
                     :compiled (lambda (str i groups)
                                 (declare (ignore str groups))
                                 (when (and (string= str "hello") (= i 2)) 3))
                     :global-p t
                     :ignore-case-p nil
                     :multiline-p nil
                     :sticky-p nil
                     :last-index 0))
           (m1 (cl-cc/javascript::%js-regex-exec exec-re "hello" 0)))
      (expect (eq m1 cl-cc/javascript::+js-null+) :to-be-falsy)
      (expect (= 3 (cl-cc/javascript::js-regexp-last-index exec-re)) :to-be-truthy)
      (let ((m2 (cl-cc/javascript::%js-regex-exec exec-re "zzzz" 0)))
        (expect m2 :to-be cl-cc/javascript::+js-null+))
      (expect (zerop (cl-cc/javascript::js-regexp-last-index exec-re)) :to-be-truthy))))

(it-sequential "js-rt-regex-exec-uncompiled-pattern"
  (let* ((re (cl-cc/javascript::make-js-regexp
              :source "("
              :flags ""
              :compiled nil
              :global-p nil
              :ignore-case-p nil
              :multiline-p nil
              :sticky-p nil
              :last-index 0))
         (m  (cl-cc/javascript::%js-regex-exec re "hello" 0)))
    (expect m :to-be cl-cc/javascript::+js-null+)))

(it-sequential "js-rt-regex-string-match-global"
  (let ((result (cl-cc/javascript::%js-string-match-regex
                 "hello" (cl-cc/javascript::%js-make-regex "l" "g"))))
    (expect (= 2 (length result)) :to-be-truthy)
    (expect (aref result 0) :to-equal "l")
    (expect (aref result 1) :to-equal "l")))

(it-sequential "js-rt-regex-string-match-global-empty"
  (let ((result (cl-cc/javascript::%js-string-match-regex
                 "abc" (cl-cc/javascript::%js-make-regex "" "g"))))
    (expect (= 4 (length result)) :to-be-truthy)
    (dotimes (i (length result))
      (expect (aref result i) :to-equal ""))))

(it-sequential "js-rt-regex-string-pattern-branches"
  (let ((replaced (cl-cc/javascript::%js-string-replace-regex "hello" "l" "-")))
    (expect replaced :to-equal "he-lo"))
  (expect (= 3 (cl-cc/javascript::%js-string-search-regex "hello" "lo")) :to-be-truthy)
  (let ((matched (cl-cc/javascript::%js-string-match-regex "hello" "lo")))
    (expect (= 1 (length matched)) :to-be-truthy)
    (expect (aref matched 0) :to-equal "lo"))
  (let ((replaced-all (cl-cc/javascript::%js-string-replace-all-regex "hello" "l" "-")))
    (expect replaced-all :to-equal "he--o"))
  (let ((parts (cl-cc/javascript::%js-string-split-regex "hello" "l")))
    (expect (%jr-list parts) :to-equal '("he" "" "o"))))

(it-sequential "js-rt-regex-string-search"
  (expect (= 3 (cl-cc/javascript::%js-string-search-regex
               "hello" (cl-cc/javascript::%js-make-regex "lo"))) :to-be-truthy))

(it-sequential "js-rt-regex-string-replace"
  (expect (cl-cc/javascript::%js-string-replace-regex
                   "hello" (cl-cc/javascript::%js-make-regex "l") "-") :to-equal "he-lo"))

(it-sequential "js-rt-regex-string-replace-placeholders"
  (expect (cl-cc/javascript::%js-string-replace-regex
                   "hello" (cl-cc/javascript::%js-make-regex "l") "$&-") :to-equal "hel-lo"))

(it-sequential "js-rt-regex-string-replace-fn-and-fallback"
  (let ((re (cl-cc/javascript::make-js-regexp
             :source "he"
             :flags ""
             :compiled (lambda (str i groups)
                         (declare (ignore str groups))
                         (when (zerop i) 2))
             :global-p nil
             :ignore-case-p nil
             :multiline-p nil
             :sticky-p nil
             :last-index 0)))
    (expect (cl-cc/javascript::%js-string-replace-regex
                     "hello"
                     re
                     (lambda (match-str match-start source)
                       (declare (ignore match-str match-start source))
                       "X")) :to-equal "Xllo"))
  (let ((re (cl-cc/javascript::make-js-regexp
             :source "l"
             :flags ""
             :compiled nil
             :global-p nil
             :ignore-case-p nil
             :multiline-p nil
             :sticky-p nil
             :last-index 0)))
    (expect (cl-cc/javascript::%js-string-replace-regex
                     "hello" re "-") :to-equal "he-lo")))

(it-sequential "js-rt-regex-string-replace-all"
  (expect (cl-cc/javascript::%js-string-replace-all-regex
                   "hello" (cl-cc/javascript::%js-make-regex "l" "g") "-") :to-equal "he--o"))

(it-sequential "js-rt-regex-string-split"
  (let ((parts (cl-cc/javascript::%js-string-split-regex
                "a,b,c" (cl-cc/javascript::%js-make-regex ","))))
    (expect (= 3 (length parts)) :to-be-truthy)
    (expect (aref parts 0) :to-equal "a")
    (expect (aref parts 1) :to-equal "b")
    (expect (aref parts 2) :to-equal "c")))

(it-sequential "js-rt-regex-string-split-limit-and-empty"
  (let ((parts (cl-cc/javascript::%js-string-split-regex
                "ab" (cl-cc/javascript::%js-make-regex "a") 1)))
    (expect (= 1 (length parts)) :to-be-truthy)
    (expect (aref parts 0) :to-equal ""))
  (let ((parts (cl-cc/javascript::%js-string-split-regex
                "ab" (cl-cc/javascript::%js-make-regex ""))))
    (expect (= 2 (length parts)) :to-be-truthy)
    (expect (aref parts 0) :to-equal "a")
    (expect (aref parts 1) :to-equal "b")))

(it-sequential "js-rt-regex-string-split-fallback"
  (let ((parts (cl-cc/javascript::%js-string-split-regex
                "a(b)c"
                (cl-cc/javascript::make-js-regexp
                 :source "b"
                 :flags ""
                 :compiled nil
                 :global-p nil
                 :ignore-case-p nil
                 :multiline-p nil
                 :sticky-p nil
                 :last-index 0))))
    (expect (%jr-list parts) :to-equal '("a(" ")c"))))

(it-sequential "js-rt-regex-pattern-branches"
  (let ((range-re (cl-cc/javascript::%js-make-regex "^[a-cx]+$")))
    (expect (cl-cc/javascript::%js-regex-test range-re "abcx") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test range-re "abdz") :to-be-falsy))
  (let ((complement-re (cl-cc/javascript::%js-make-regex "[^a-c]+")))
    (expect (cl-cc/javascript::%js-regex-test complement-re "z") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test complement-re "b") :to-be-falsy))
  (let ((class-escape-re (cl-cc/javascript::%js-make-regex "[\\d\\w\\s]+")))
    (expect (cl-cc/javascript::%js-regex-test class-escape-re "a_9 ") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test class-escape-re "!") :to-be-falsy))
  (let ((group-re (cl-cc/javascript::%js-make-regex "^(?:cat|dog)?$")))
    (expect (cl-cc/javascript::%js-regex-test group-re "cat") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test group-re "") :to-be-truthy))
  (let ((literal-escape-re (cl-cc/javascript::%js-make-regex "a\\+b")))
    (expect (cl-cc/javascript::%js-regex-test literal-escape-re "a+b") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test literal-escape-re "ab") :to-be-falsy))
  (let ((dot-re (cl-cc/javascript::%js-make-regex "a.b" "m")))
    (expect (cl-cc/javascript::%js-regex-test dot-re "acb") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test dot-re (format nil "a~%b")) :to-be-falsy))
  (let ((lazy-star-re (cl-cc/javascript::%js-make-regex "a*?")))
    (expect (cl-cc/javascript::%js-regex-test lazy-star-re "aaa") :to-be-truthy)
    (expect (gethash "0" (cl-cc/javascript::%js-regex-exec lazy-star-re "aaa" 0)) :to-equal "")))

(it-sequential "js-rt-regex-word-boundary"
  (let ((boundary-re (cl-cc/javascript::%js-make-regex "\\bcat\\b")))
    (expect (cl-cc/javascript::%js-regex-test boundary-re "the cat sat") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test boundary-re "concatenate") :to-be-falsy))
  (let ((non-boundary-re (cl-cc/javascript::%js-make-regex "\\Bcat\\B")))
    (expect (cl-cc/javascript::%js-regex-test non-boundary-re "concatenate") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test non-boundary-re "the cat sat") :to-be-falsy)))

(it-sequential "js-rt-regex-lookahead"
  (let ((positive-re (cl-cc/javascript::%js-make-regex "foo(?=bar)")))
    (expect (gethash "0" (cl-cc/javascript::%js-regex-exec positive-re "foobar" 0))
            :to-equal "foo")
    (expect (cl-cc/javascript::%js-regex-test positive-re "foobaz") :to-be-falsy))
  (let ((negative-re (cl-cc/javascript::%js-make-regex "foo(?!bar)")))
    (expect (cl-cc/javascript::%js-regex-test negative-re "foobar") :to-be-falsy)
    (expect (gethash "0" (cl-cc/javascript::%js-regex-exec negative-re "foobaz" 0))
            :to-equal "foo")))

;;; ─── Capturing groups: numbered, named, nested, quantified ────────────────────

(it-sequential "js-rt-regex-numbered-groups"
  (let* ((re (cl-cc/javascript::%js-make-regex "(\\d+)-(\\d+)"))
         (m  (cl-cc/javascript::%js-regex-exec re "12-34" 0)))
    (expect (gethash "0" m) :to-equal "12-34")
    (expect (gethash "1" m) :to-equal "12")
    (expect (gethash "2" m) :to-equal "34")
    (expect (gethash "groups" m) :to-be-js-undefined)))

(it-sequential "js-rt-regex-nested-groups-number-by-open-paren"
  (let* ((re (cl-cc/javascript::%js-make-regex "((a)(b))"))
         (m  (cl-cc/javascript::%js-regex-exec re "ab" 0)))
    (expect (gethash "1" m) :to-equal "ab")
    (expect (gethash "2" m) :to-equal "a")
    (expect (gethash "3" m) :to-equal "b")))

(it-sequential "js-rt-regex-alternation-unmatched-group-is-undefined"
  (let* ((re (cl-cc/javascript::%js-make-regex "(a)|(b)"))
         (m  (cl-cc/javascript::%js-regex-exec re "b" 0)))
    (expect (gethash "1" m) :to-be-js-undefined)
    (expect (gethash "2" m) :to-equal "b")))

(it-sequential "js-rt-regex-quantified-group-captures-last-iteration"
  (let* ((re (cl-cc/javascript::%js-make-regex "(a)+"))
         (m  (cl-cc/javascript::%js-regex-exec re "aaa" 0)))
    (expect (gethash "0" m) :to-equal "aaa")
    (expect (gethash "1" m) :to-equal "a")))

(it-sequential "js-rt-regex-named-groups"
  (let* ((re (cl-cc/javascript::%js-make-regex "(?<year>\\d+)?-(?<month>\\d\\d)"))
         (m  (cl-cc/javascript::%js-regex-exec re "-07" 0))
         (groups (gethash "groups" m)))
    (expect (gethash "0" m) :to-equal "-07")
    (expect (gethash "year" groups) :to-be-js-undefined)
    (expect (gethash "month" groups) :to-equal "07")
    (expect (gethash "2" m) :to-equal "07")))

(it-sequential "js-rt-regex-named-group-excludes-lookbehind-syntax"
  ;; (?<=...)/(?<!...) must not be mistaken for a named group by the `(?<`
  ;; prefix check — they still fall through as unrecognized (documented gap).
  (let ((re (cl-cc/javascript::%js-make-regex "(?<=a)")))
    (expect (cl-cc/javascript::js-regexp-group-names re) :to-be nil)))

(it-sequential "js-rt-regex-match-object-length-tracks-group-count"
  (let* ((re (cl-cc/javascript::%js-make-regex "(a)(b)?"))
         (m  (cl-cc/javascript::%js-regex-exec re "a" 0)))
    (expect (gethash "1" m) :to-equal "a")
    (expect (gethash "2" m) :to-be-js-undefined)))

;;; ─── Replacement placeholders: $&, $$, $1-$99, $<name> ────────────────────────

(it-sequential "js-rt-regex-replace-numbered-placeholders"
  (expect (cl-cc/javascript::%js-string-replace-regex
           "2024-07" (cl-cc/javascript::%js-make-regex "(\\d+)-(\\d+)") "$2/$1")
          :to-equal "07/2024"))

(it-sequential "js-rt-regex-replace-named-placeholder"
  (expect (cl-cc/javascript::%js-string-replace-regex
           "07" (cl-cc/javascript::%js-make-regex "(?<month>\\d\\d)") "month=$<month>")
          :to-equal "month=07"))

(it-sequential "js-rt-regex-replace-dollar-escape"
  (expect (cl-cc/javascript::%js-string-replace-regex
           "5" (cl-cc/javascript::%js-make-regex "5") "$$$&")
          :to-equal "$5"))

(it-sequential "js-rt-regex-replace-out-of-range-group-is-literal"
  (expect (cl-cc/javascript::%js-string-replace-regex
           "a" (cl-cc/javascript::%js-make-regex "(a)") "$9")
          :to-equal "$9"))

(it-sequential "js-rt-regex-replace-unterminated-named-placeholder-is-literal"
  (expect (cl-cc/javascript::%js-string-replace-regex
           "a" (cl-cc/javascript::%js-make-regex "(?<x>a)") "$<x")
          :to-equal "$<x"))

;;; ─── Bounded-repetition quantifiers: {n}, {n,}, {n,m} ─────────────────────────

(it-sequential "js-rt-regex-brace-exact-count"
  (let ((re (cl-cc/javascript::%js-make-regex "^a{3}$")))
    (expect (cl-cc/javascript::%js-regex-test re "aaa") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test re "aa") :to-be-falsy)
    (expect (cl-cc/javascript::%js-regex-test re "aaaa") :to-be-falsy)))

(it-sequential "js-rt-regex-brace-minimum-only"
  (let ((re (cl-cc/javascript::%js-make-regex "^a{2,}$")))
    (expect (cl-cc/javascript::%js-regex-test re "a") :to-be-falsy)
    (expect (cl-cc/javascript::%js-regex-test re "aa") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test re "aaaaa") :to-be-truthy)))

(it-sequential "js-rt-regex-brace-range"
  (let ((re (cl-cc/javascript::%js-make-regex "^a{2,3}$")))
    (expect (cl-cc/javascript::%js-regex-test re "a") :to-be-falsy)
    (expect (cl-cc/javascript::%js-regex-test re "aa") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test re "aaa") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test re "aaaa") :to-be-falsy)))

(it-sequential "js-rt-regex-brace-lazy-stops-at-minimum"
  (let* ((re (cl-cc/javascript::%js-make-regex "a{1,3}?"))
         (m  (cl-cc/javascript::%js-regex-exec re "aaa" 0)))
    (expect (gethash "0" m) :to-equal "a")))

(it-sequential "js-rt-regex-brace-invalid-falls-back-to-literal"
  (let ((re (cl-cc/javascript::%js-make-regex "^a{,3}$")))
    (expect (cl-cc/javascript::%js-regex-test re "a{,3}") :to-be-truthy)
    (expect (cl-cc/javascript::%js-regex-test re "aaa") :to-be-falsy))
  (let ((unclosed-re (cl-cc/javascript::%js-make-regex "^a{3$")))
    (expect (cl-cc/javascript::%js-regex-test unclosed-re "a{3") :to-be-truthy)))

;;; ─── Fuzz: no pattern/subject pair should ever signal an unhandled CL error ───

(it-fuzz "js-rt-regex-fuzz-compile-and-exec-never-crashes"
    ((pattern (gen-string :min-length 0 :max-length 24
                           :alphabet "abc().[]{}*+?|^$\\-,0123456789<>=!:"))
     (subject (gen-string :min-length 0 :max-length 24
                           :alphabet "abc0123456789 ")))
    (:trials 300)
  ;; %js-make-regex already catches a COMPILE-time error (an invalid pattern
  ;; just compiles to FN=NIL, exec then returns null) — this fuzzes for the
  ;; different, previously-unverified failure mode: a pattern that compiles
  ;; "successfully" but whose matcher closure signals a real Lisp error (an
  ;; out-of-bounds AREF, an unbound variable, ...) when actually run against
  ;; adversarial input. This test needs no expected output; only "did not
  ;; signal an ERROR" is checked, per IT-FUZZ's own contract.
  (cl-cc/javascript::%js-regex-test (cl-cc/javascript::%js-make-regex pattern) subject))

;;; ─── Compile-time recursion depth guard (CWE-674 DoS protection) ──────────────

(it-sequential "js-rt-regex-nested-groups-within-limit-still-compile"
  (let* ((depth 50)
         (pattern (format nil "~{~A~}a~{~A~}"
                           (make-list depth :initial-element "(")
                           (make-list depth :initial-element ")")))
         (re (cl-cc/javascript::%js-make-regex pattern)))
    (expect (cl-cc/javascript::%js-regex-test re "a") :to-be-truthy)
    (expect (= depth (cl-cc/javascript::js-regexp-num-groups re)) :to-be-truthy)))

(it-sequential "js-rt-regex-pathologically-nested-groups-fail-gracefully"
  ;; %js-compile-pattern's compile-atom/compile-seq/compile-alt mutual
  ;; recursion has no depth bound of its own; without
  ;; *js-regex-max-compile-depth* a pattern like this (deliberately well
  ;; past the limit) would exhaust the control stack instead of failing
  ;; cleanly — %js-make-regex already wraps compilation in a handler-case,
  ;; so the failure surfaces as an uncompiled (never-matching) RegExp, not a
  ;; process crash.
  (let* ((depth (+ 1000 cl-cc/javascript::*js-regex-max-compile-depth*))
         (pattern (format nil "~{~A~}a~{~A~}"
                           (make-list depth :initial-element "(")
                           (make-list depth :initial-element ")")))
         (re (cl-cc/javascript::%js-make-regex pattern)))
    (expect (cl-cc/javascript::js-regexp-compiled re) :to-be nil)))
