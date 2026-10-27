(in-package #:cl-cc/javascript/classes/test)

(defun %js-decorators (src)
  "Parse the leading @decorator forms in SRC, returning (values decorators rest)."
  (cl-cc/javascript/classes:%js-parse-decorators
   (cl-cc/javascript/syntax:tokenize-js-source src)))

(describe-concurrent "JavaScript Classes"
  (it-sequential "js-parser-decorators-none"
    (multiple-value-bind (decorators rest) (%js-decorators "class Foo {}")
      (expect decorators :to-be-null)
      (expect (cl-cc/javascript/syntax:js-peek-type rest) :to-be :T-CLASS)))
  (it-sequential "js-parser-decorators-simple"
    (multiple-value-bind (decorators rest) (%js-decorators "@dec class Foo {}")
      (expect (length decorators) :to-be 1)
      (expect (cl-cc/ast:ast-var-p (first decorators)) :to-be-truthy)
      (expect (symbol-name (cl-cc/ast:ast-var-name (first decorators))) :to-equal "dec")
      (expect (cl-cc/javascript/syntax:js-peek-type rest) :to-be :T-CLASS)))
  (it-sequential "js-parser-decorators-member-chain"
    (multiple-value-bind (decorators rest) (%js-decorators "@ns.sub.dec class Foo {}")
      (declare (ignore rest))
      (expect (length decorators) :to-be 1)
      (expect (symbol-name (cl-cc/ast:ast-var-name (first decorators))) :to-equal "ns.sub.dec")))
  (it-sequential "js-parser-decorators-with-args"
    (multiple-value-bind (decorators rest) (%js-decorators "@dec(1, 2) class Foo {}")
      (declare (ignore rest))
      (expect (length decorators) :to-be 1)
      (expect (cl-cc/ast:ast-call-p (first decorators)) :to-be-truthy)
      (expect (symbol-name (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func (first decorators))))
              :to-equal "dec")
      (expect (length (cl-cc/ast:ast-call-args (first decorators))) :to-be 2)))
  (it-sequential "js-parser-decorators-with-nested-call-arg"
    ;; @dec(1, 2)'s test above never checks REST -- a decorator argument that
    ;; is itself a call (nested parens/commas) is where a naive "skip tokens
    ;; until the next comma or ')'" argument-list scan (as opposed to one that
    ;; tracks nesting depth) stops at the INNER call's own comma/close-paren
    ;; instead of the outer one, leaving REST pointing at a stray ')' instead
    ;; of the class keyword.
    (multiple-value-bind (decorators rest) (%js-decorators "@dec(foo(1,2)) class Foo {}")
      (expect (length decorators) :to-be 1)
      (expect (cl-cc/javascript/syntax:js-peek-type rest) :to-be :T-CLASS)))
  (it-sequential "js-parser-decorators-stacked"
    (multiple-value-bind (decorators rest) (%js-decorators "@a @b @c class Foo {}")
      (declare (ignore rest))
      (expect (length decorators) :to-be 3)
      (expect (mapcar (lambda (d) (symbol-name (cl-cc/ast:ast-var-name d))) decorators)
              :to-equal '("a" "b" "c"))))
)
