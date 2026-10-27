;;;; t/strings/runtime-string-number-test.lisp
;;;;
;;;; String prototype methods, template-literal escape handling, URL, and
;;;; text/base64 encoding.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr)

(in-package #:cl-cc/javascript/strings/test)

;;; ─── String ──────────────────────────────────────────────────────────────────

(defun %register-strings-runtime-string-number-tests ()
  (it-sequential "js-rt-string-slice"
    (expect (cl-cc/javascript::%js-string-slice "hello" 1 4) :to-equal "ell")
    (expect (cl-cc/javascript::%js-string-slice "hello" -2) :to-equal "lo"))
  (it-sequential "js-rt-string-search"
    (expect (cl-cc/javascript::%js-string-includes  "hello" "ell") :to-be-truthy)
    (expect (cl-cc/javascript::%js-string-includes  "hello" "xyz") :to-be-falsy)
    (expect (= 2 (cl-cc/javascript::%js-string-index-of  "hello" "l")) :to-be-truthy)
    (expect (= -1 (cl-cc/javascript::%js-string-index-of  "hello" "z")) :to-be-truthy))
  (it-sequential "js-rt-string-index-of-position-coercion"
    (expect (= 2 (cl-cc/javascript::%js-string-index-of "ababa" "a" "2")) :to-be-truthy)
    (expect (= 3 (cl-cc/javascript::%js-string-index-of "abcabc" "a" 2.8d0)) :to-be-truthy)
    (expect (zerop (cl-cc/javascript::%js-string-index-of
                 "abc" "a" cl-cc/javascript/objects:+js-undefined+)) :to-be-truthy)
    (expect (cl-cc/javascript::%js-string-includes "abc" "a" 1) :to-be-falsy))
  (it-sequential-each ((cl-cc/javascript::%js-string-to-upper-case "hello" "HELLO")
                       (cl-cc/javascript::%js-string-to-lower-case "HELLO" "hello"))
      "js-rt-string-case ~A"
      (fn input expected)
    (expect (funcall (symbol-function fn) input) :to-equal expected))
  (it-sequential-each (("ab" 3 "ababab") ("ab" 0 ""))
      "js-rt-string-repeat ~A ~A"
      (s n expected)
    (expect (cl-cc/javascript::%js-string-repeat s n) :to-equal expected))
  (it-sequential "js-rt-string-split-empty-sep"
    (expect (%jr-list (cl-cc/javascript::%js-string-split "abc" "")) :to-equal '("a" "b" "c")))
  (it-sequential-each ((cl-cc/javascript::%js-string-starts-with "hello" "hel" t)
                       (cl-cc/javascript::%js-string-starts-with "hello" "ell" nil)
                       (cl-cc/javascript::%js-string-ends-with "hello" "llo" t)
                       (cl-cc/javascript::%js-string-ends-with "hello" "hel" nil))
      "js-rt-string-starts-ends-with ~A ~*~S"
      (fn s sub expected)
    (expect (funcall (symbol-function fn) s sub) :to-equal expected))
  (it-sequential-each ((cl-cc/javascript::%js-string-pad-start "5" 3 "005")
                       (cl-cc/javascript::%js-string-pad-end "5" 3 "500"))
      "js-rt-string-pad ~A"
      (fn s len expected)
    (expect (funcall (symbol-function fn) s len "0") :to-equal expected))
  (it-sequential "js-rt-string-trim"
    (expect (cl-cc/javascript::%js-string-trim       "  hello  ") :to-equal "hello")
    (expect (cl-cc/javascript::%js-string-trim-start "  hello  ") :to-equal "hello  ")
    (expect (cl-cc/javascript::%js-string-trim-end   "  hello  ") :to-equal "  hello"))
  (it-sequential-each ((0 "h") (-1 "o") (2 "l"))
      "js-rt-string-at ~A"
      (idx expected)
    (expect (cl-cc/javascript::%js-string-at "hello" idx) :to-equal expected))
  (it-sequential "js-rt-string-char-at-code-at"
    (expect (cl-cc/javascript::%js-string-char-at      "hello" 1) :to-equal "e")
    (expect (= 101 (cl-cc/javascript::%js-string-char-code-at "hello" 1)) :to-be-truthy))
  (it-sequential-each (("abcabc" "b" 4) ("aabb" "b" 3) ("abc" "z" -1))
      "js-rt-string-last-index-of ~A ~A"
      (s sub expected)
    (expect (= expected (cl-cc/javascript::%js-string-last-index-of s sub)) :to-be-truthy))
  (it-sequential "js-rt-string-last-index-of-position-bounds"
    (expect (= 4 (cl-cc/javascript::%js-string-last-index-of "ababa" "a" cl-cc/javascript/objects:+js-undefined+)) :to-be-truthy)
    (expect (= 2 (cl-cc/javascript::%js-string-last-index-of "ababa" "a" "2")) :to-be-truthy)
    (expect (zerop (cl-cc/javascript::%js-string-last-index-of "abcabc" "a" 2.8d0)) :to-be-truthy)
    (expect (zerop (cl-cc/javascript::%js-string-last-index-of "ababa" "a" -99)) :to-be-truthy)
    (expect (= -1 (cl-cc/javascript::%js-string-last-index-of "ababa" "b" -99)) :to-be-truthy)
    (expect (= 5 (cl-cc/javascript::%js-string-last-index-of "ababa" "" 99)) :to-be-truthy))
  (it-sequential "js-rt-string-concat"
    (expect (cl-cc/javascript::%js-string-concat "hello" " " "world") :to-equal "hello world"))
  (it-sequential "js-rt-string-from-char-code-and-code-point"
    (expect (cl-cc/javascript::%js-string-from-char-code  65) :to-equal "A")
    (expect (cl-cc/javascript::%js-string-from-code-point 65) :to-equal "A"))
  (it-sequential "js-rt-string-code-point-at"
    (expect (= 72 (cl-cc/javascript/strings:%js-string-code-point-at "Hello" 0)) :to-be-truthy)
    (expect (= 101 (cl-cc/javascript/strings:%js-string-code-point-at "Hello" 1)) :to-be-truthy))
  (it-sequential "js-rt-string-is-well-formed"
    (let ((wf "hello"))
      (expect (cl-cc/javascript::%js-string-is-well-formed wf) :to-be-truthy)
      (expect (cl-cc/javascript::%js-string-to-well-formed wf) :to-equal wf)))
  (it-sequential-each ((cl-cc/javascript::%js-string-replace "aaa" "a" "b" "baa")
                       (cl-cc/javascript::%js-string-replace-all "aaa" "a" "b" "bbb"))
      "js-rt-string-replace ~A"
      (fn s pat rep expected)
    (expect (funcall (symbol-function fn) s pat rep) :to-equal expected))
  (it-sequential "js-rt-method-resolution-string"
    (let* ((s "hello")
           (upper-fn (cl-cc/javascript::%js-get-prop s "toUpperCase")))
      (expect (functionp upper-fn) :to-be-truthy)
      (expect (funcall upper-fn) :to-equal "HELLO")))
  (it-sequential "js-rt-string-length"
    (expect (zerop (cl-cc/javascript::%js-string-length "")) :to-be-truthy)
    (expect (= 5 (cl-cc/javascript::%js-string-length "hello")) :to-be-truthy))
  (it-sequential-each (("a,b,c" "," ("a" "b" "c"))
                       ("a,,b" "," ("a" "" "b"))
                       ("abc" "," ("abc")))
      "js-rt-string-split-separator ~S"
      (s sep expected)
    (expect (%jr-list (cl-cc/javascript::%js-string-split s sep)) :to-equal expected))
  (it-sequential "js-rt-string-split-limit"
    (let ((parts (%jr-list (cl-cc/javascript::%js-string-split "a,b,c,d" "," 2))))
      (expect (= 2 (length parts)) :to-be-truthy)
      (expect (first parts) :to-equal "a")
      (expect (second parts) :to-equal "b")))
  (it-sequential-each (("hello world" "world" "world") ("hello" "xyz" :null))
      "js-rt-string-match-cases ~S"
      (s pat expected)
    (let ((result (cl-cc/javascript::%js-string-match s pat)))
      (if (eq expected :null)
          (expect result :to-be cl-cc/javascript/objects:+js-null+)
          (expect (aref result 0) :to-equal expected))))
  (it-sequential "js-rt-string-match-all-multiple"
    (let ((all (cl-cc/javascript::%js-string-match-all "abab" "ab")))
      (expect (= 2 (length all)) :to-be-truthy)
      (expect (aref (aref all 0) 0) :to-equal "ab")
      (expect (aref (aref all 1) 0) :to-equal "ab")))
  (it-sequential-each (("hello" "ll" 2) ("hello" "xyz" -1))
      "js-rt-string-search-index ~A ~A"
      (s pat expected)
    (expect (= expected (cl-cc/javascript::%js-string-search s pat)) :to-be-truthy))
  (it-sequential "js-rt-string-normalize"
    (let* ((acute (string (code-char #x0301)))
           (composed-e (string (code-char #x00E9)))
           (decomposed-e (concatenate 'string "e" acute))
           (angstrom-sign (string (code-char #x212B)))
           (angstrom-letter (string (code-char #x00C5)))
           (fi-ligature (string (code-char #xFB01))))
      (expect (cl-cc/javascript::%js-string-normalize decomposed-e) :to-equal composed-e)
      (expect (cl-cc/javascript::%js-string-normalize composed-e "NFD") :to-equal decomposed-e)
      (expect (cl-cc/javascript::%js-string-normalize angstrom-sign "NFKC") :to-equal angstrom-letter)
      (expect (cl-cc/javascript::%js-string-normalize fi-ligature "NFKD") :to-equal "fi")
      (signals error (cl-cc/javascript::%js-string-normalize "cafe" "BAD"))))
  (it-sequential-each (("a" "b" -1.0d0) ("x" "x" 0.0d0) ("b" "a" 1.0d0))
      "js-rt-string-locale-compare-order ~A ~A"
      (a b expected)
    (expect (= expected (cl-cc/javascript::%js-string-locale-compare a b)) :to-be-truthy))
  (it-sequential "js-rt-string-raw-tag"
    (let* ((raw    (%jr-arr "hello " " world"))
           (result (cl-cc/javascript::%js-string-raw raw "JS")))
      (expect result :to-equal "hello JS world")))
  (it-sequential-each (("hello" 1 3 "el") ("hello" 0 100 "hello") ("hello" 3 1 "el"))
      "js-rt-string-substring-cases ~*~A ~A"
      (s a b expected)
    (expect (cl-cc/javascript::%js-string-substring s a b) :to-equal expected))
  (labels ((%js-signals-error-p (thunk)
           (handler-case (progn (funcall thunk) nil)
             (error () t))))
  (it-sequential-each ((cl-cc/javascript::%js-string-to-locale-upper-case "hello" "HELLO")
                       (cl-cc/javascript::%js-string-to-locale-lower-case "HELLO" "hello"))
      "js-rt-string-locale-case ~A"
      (fn input expected)
    (expect (funcall (symbol-function fn) input) :to-equal expected))
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
  (multiple-value-bind (ch new-pos) (js-lex-template-escape src pos)
    (expect ch :to-be expected-char)
    (expect (= expected-pos new-pos) :to-be-truthy)))
  (it-sequential-each (("") ("u") ("u{}") ("u{1F4") ("u{1F4x")
                     ("u{110000}") ("x4") ("u12x4") ("xg1"))
    "lex-template-escape-errors ~S"
    (src)
  (expect (%js-signals-error-p (lambda () (js-lex-template-escape src 0)))
          :to-be-truthy)))
  )

;;; ─── URL and encoding coverage ────────────────────────────────────────────────

(defun %register-strings-runtime-builtins-platform-url-tests ()
  (it-sequential "js-rt-make-url-parses-components"
    (let ((url (%js-make-url
                "https://example.com:8443/path/to?q=1#frag")))
      (%jr-assert-string-props
       url
       '(("href" "https://example.com:8443/path/to?q=1#frag")
         ("protocol" "https:")
         ("host" "example.com:8443")
         ("hostname" "example.com")
         ("port" "8443")
         ("origin" "https://example.com:8443")
         ("pathname" "/path/to")
         ("search" "?q=1")
         ("hash" "#frag")))
      (expect (funcall (gethash "toString" url)) :to-equal "https://example.com:8443/path/to?q=1#frag")))
  (it-sequential "js-rt-make-url-resolves-base-relative-path"
    (let ((url (%js-make-url
                "child?x=1"
                "https://example.com/a/b/index.html")))
      (%jr-assert-string-props
       url
       '(("href" "https://example.com/a/b/child?x=1")
         ("pathname" "/a/b/child")
         ("search" "?x=1")))))
  (it-sequential "js-rt-make-url-normalizes-relative-dot-segments"
    (let ((url (%js-make-url
                "../c/./d/?x=1"
                "https://example.com/a/b/index.html")))
      (%jr-assert-string-props
       url
       '(("href" "https://example.com/a/c/d/?x=1")
         ("pathname" "/a/c/d/")
         ("search" "?x=1")))))
  (it-sequential "js-rt-make-url-resolves-query-and-hash-only-relative"
    (let ((query-url (%js-make-url
                      "?q=2"
                      "https://example.com/a/b/index.html?old=1#frag"))
          (hash-url (%js-make-url
                     "#next"
                     "https://example.com/a/b/index.html?old=1#frag")))
      (%jr-assert-string-props
       query-url
       '(("href" "https://example.com/a/b/index.html?q=2")
         ("pathname" "/a/b/index.html")
         ("search" "?q=2")))
      (%jr-assert-string-props
       hash-url
       '(("href" "https://example.com/a/b/index.html?old=1#next")
         ("pathname" "/a/b/index.html")
         ("search" "?old=1")
         ("hash" "#next")))))
  (it-sequential-each (("hello world" "hello%20world")
                       ("a/b" "a%2Fb")
                       ("abc123" "abc123"))
      "js-rt-encode-uri-component ~S"
      (s expected)
    (expect (cl-cc/javascript/strings:%js-encode-uri-component s) :to-equal expected))
  (it-sequential "js-rt-decode-uri-component"
    (expect (cl-cc/javascript/strings:%js-decode-uri-component "hello%20world") :to-equal "hello world"))
  (it-property "js-rt-encode-decode-uri-component-roundtrip-property"
      ((s (gen-string :min-length 0 :max-length 40
                      :alphabet " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")))
    (expect (cl-cc/javascript/strings:%js-decode-uri-component
             (cl-cc/javascript/strings:%js-encode-uri-component s))
            :to-equal s))
  (it-sequential "js-rt-btoa-atob-roundtrip"
    (let* ((s "Hello, World!")
           (encoded (cl-cc/javascript/strings:%js-btoa s))
           (decoded (cl-cc/javascript/strings:%js-atob encoded)))
      (expect decoded :to-equal s)))
  (it-property "js-rt-btoa-atob-roundtrip-property"
      ((s (gen-string :min-length 0 :max-length 40
                      :alphabet " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")))
    (expect (cl-cc/javascript/strings:%js-atob (cl-cc/javascript/strings:%js-btoa s)) :to-equal s))
  )

;;; ─── Local test helpers ──────────────────────────────────────────────────────

(defun %jr-assert-string-props (object expected-props)
  "Assert every (key expected) pair in EXPECTED-PROPS against OBJECT's
matching gethash value. Uses WITH-SOFT-ASSERTIONS so a mismatch on one
property doesn't hide mismatches on the others — useful here since callers
pass many properties (e.g. every URL component) in one call."
  (with-soft-assertions
    (dolist (prop expected-props)
      (destructuring-bind (key expected) prop
        (expect (gethash key object) :to-equal expected)))))
