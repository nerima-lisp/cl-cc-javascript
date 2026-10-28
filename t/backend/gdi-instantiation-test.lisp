(in-package #:cl-cc/javascript/backend/test)
(defun %js-gdi-test-state ()
  (let ((state (cl-cc/vm:make-vm-state)))
    (cl-cc/javascript/backend:%seed-js-globals state)
    (setf (gethash (cl-cc/javascript/syntax:js-ident-sym "globalThis")
                   (cl-cc/vm:vm-global-vars state)) (%js-make-object))
    state))

(defun %js-gdi-test-name (name)
  (cl-cc/javascript/syntax:js-ident-sym name))

(defun %js-gdi-test-error-p (thunk expected-name)
  (handler-case (progn
                  (funcall thunk)
                  nil)
    (cl-cc/javascript/errors:js-exception (condition)
      (string= expected-name
               (%js-get-prop (cl-cc/javascript/errors:js-exception-value condition) "name")))))

(defun %register-backend-gdi-tests ()
  ;; Test262: test/language/global-code/decl-var.js
  (it-sequential "js-gdi-var-creates-nonconfigurable-global-property"
                 (let* ((state (%js-gdi-test-state))
                        (name (%js-gdi-test-name "value")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (cl-cc/javascript/backend::%js-gdi-prepare nil nil (list name))
                     (cl-cc/javascript/backend::%js-gdi-create-global-vars (list name) nil)
                     (expect (cl-cc/javascript/backend::%js-gdi-global-read name)
                             :to-equal +js-undefined+)
                     (cl-cc/javascript/backend::%js-gdi-global-write name 7)
                     (let* ((global (cl-cc/javascript/backend::%js-gdi-global-object))
                            (descriptor (%js-object-get-own-property-descriptor global "value")))
                       (expect (%js-get-prop descriptor "value") :to-equal 7)
                       (expect (%js-get-prop descriptor "writable") :to-equal t)
                       (expect (%js-get-prop descriptor "enumerable") :to-equal t)
                       (expect (%js-get-prop descriptor "configurable") :to-equal nil)
                       (expect (gethash name (cl-cc/vm:vm-global-vars state)) :to-equal 7)))))
  ;; Test262: test/language/global-code/decl-var.js
  (it-sequential "js-gdi-global-deletion-clears-vm-mirrors"
                 (let* ((state (%js-gdi-test-state))
                        (read-name (%js-gdi-test-name "deletedAssignmentGlobalRead"))
                        (typeof-name (%js-gdi-test-name "deletedAssignmentGlobalTypeof")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (let ((global (cl-cc/javascript/backend::%js-gdi-global-object)))
                       (cl-cc/javascript/backend::%js-gdi-global-write read-name 41)
                       (expect (gethash read-name (cl-cc/vm:vm-global-vars state)) :to-equal 41)
                       (expect
                        (cl-cc/javascript/objects:%js-delete global (symbol-name read-name))
                        :to-equal t)
                       (expect
                        (%js-gdi-test-error-p
                         (lambda () (cl-cc/javascript/backend::%js-gdi-global-read read-name))
                         "ReferenceError")
                        :to-be-truthy)
                       (expect (nth-value 1 (gethash read-name (cl-cc/vm:vm-global-vars state)))
                               :to-equal nil)
                       (cl-cc/javascript/backend::%js-gdi-global-write typeof-name 43)
                       (expect
                        (cl-cc/javascript/objects:%js-delete global (symbol-name typeof-name))
                        :to-equal t)
                       (expect (cl-cc/javascript/backend::%js-gdi-global-typeof typeof-name)
                               :to-equal "undefined")
                       (expect (nth-value 1 (gethash typeof-name (cl-cc/vm:vm-global-vars state)))
                               :to-equal nil))))
                 (let* ((state (%js-gdi-test-state))
                        (name (%js-gdi-test-name "console")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (setf (gethash name (cl-cc/vm:vm-global-vars state)) 97)
                     (cl-cc/javascript/backend::%js-gdi-initialize-prelude-global-properties
                      (list name))
                     (let ((global (cl-cc/javascript/backend::%js-gdi-global-object)))
                       (expect (cl-cc/javascript/backend::%js-gdi-global-read name) :to-equal 97)
                       (expect
                        (cl-cc/javascript/objects:%js-delete global (symbol-name name))
                        :to-equal t)
                       (expect (cl-cc/javascript/backend::%js-gdi-global-typeof name)
                               :to-equal "undefined")
                       (expect
                        (%js-gdi-test-error-p
                         (lambda () (cl-cc/javascript/backend::%js-gdi-global-read name))
                         "ReferenceError")
                        :to-be-truthy)
                       (expect (nth-value 1 (gethash name (cl-cc/vm:vm-global-vars state)))
                               :to-equal nil)
                       (setf (gethash name (cl-cc/vm:vm-global-vars state)) 97)
                       (cl-cc/javascript/backend::%js-gdi-initialize-prelude-global-properties
                        (list name))
                       (expect (cl-cc/javascript/backend::%js-gdi-global-typeof name)
                               :to-equal "undefined")
                       (expect
                        (%js-gdi-test-error-p
                         (lambda () (cl-cc/javascript/backend::%js-gdi-global-read name))
                         "ReferenceError")
                        :to-be-truthy)
                       (expect (nth-value 1 (gethash name (cl-cc/vm:vm-global-vars state)))
                               :to-equal nil))))
                 (let* ((state (%js-gdi-test-state))
                        (name (%js-gdi-test-name "deletedThenRedeclared")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (cl-cc/javascript/backend::%js-gdi-global-write name 41)
                     (let ((global (cl-cc/javascript/backend::%js-gdi-global-object)))
                       (expect
                        (cl-cc/javascript/objects:%js-delete global (symbol-name name))
                        :to-equal t))
                     (expect (gethash name (cl-cc/vm:vm-global-vars state)) :to-equal 41)
                     (cl-cc/javascript/backend::%js-gdi-prepare nil nil (list name))
                     (cl-cc/javascript/backend::%js-gdi-create-global-vars (list name) nil)
                     (expect (cl-cc/javascript/backend::%js-gdi-global-read name)
                             :to-equal +js-undefined+)
                     (expect (cl-cc/javascript/backend::%js-gdi-global-typeof name)
                             :to-equal "undefined"))))
  ;; Sloppy global writes ignore failed property-set operations.
  (it-sequential "js-gdi-sloppy-global-writes-fail-silently"
                 (let* ((state (%js-gdi-test-state))
                        (locked-name (%js-gdi-test-name "locked"))
                        (new-name (%js-gdi-test-name "createdByAssignment")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (let ((global (cl-cc/javascript/backend::%js-gdi-global-object)))
                       (%js-object-define-property
                        global "locked"
                        (%js-make-object "value" 11 "writable" nil
                                         "enumerable" t "configurable" t))
                       (expect (cl-cc/javascript/backend::%js-gdi-global-write
                                locked-name 12)
                               :to-equal 12)
                       (expect (cl-cc/javascript/backend::%js-gdi-global-read locked-name)
                               :to-equal 11)
                       (expect (cl-cc/javascript/backend::%js-gdi-global-write new-name 5)
                               :to-equal 5)
                       (expect (cl-cc/javascript/backend::%js-gdi-global-read new-name)
                               :to-equal 5)
                       (let ((descriptor
                              (%js-object-get-own-property-descriptor
                               global "createdByAssignment")))
                         (expect (%js-get-prop descriptor "writable") :to-equal t)
                         (expect (%js-get-prop descriptor "enumerable") :to-equal t)
                         (expect (%js-get-prop descriptor "configurable") :to-equal t))))))
  ;; Test262: test/language/global-code/decl-var.js
  (it-sequential "js-gdi-var-no-initializer-preserves-existing-value"
                 (labels ((descendants (node)
                                       (cons node
                                             (mapcan (function descendants)
                                                     (cl-cc/ast:ast-children node))))
                          (global-write-for-name-p (forms name)
                                                   (some
                                                    (lambda (node)
                                                      (and (cl-cc/ast:ast-call-p node)
                                                           (cl-cc/ast:ast-var-p
                                                            (cl-cc/ast:ast-call-func node))
                                                           (string= "%JS-GDI-GLOBAL-WRITE"
                                                                    (symbol-name
                                                                     (cl-cc/ast:ast-var-name
                                                                      (cl-cc/ast:ast-call-func node))))
                                                           (let ((argument
                                                                  (first (cl-cc/ast:ast-call-args node))))
                                                             (and (cl-cc/ast:ast-quote-p argument)
                                                                  (eq (cl-cc/ast:ast-quote-value argument) name)))))
                                                    (mapcan (function descendants) forms))))
                   (let* ((state (%js-gdi-test-state))
                          (name (%js-gdi-test-name "persistent"))
                          (no-initializer
                           (cl-cc/javascript/backend:js-program-forms "var persistent;"))
                          (explicit-undefined
                           (cl-cc/javascript/backend:js-program-forms
                            "var persistent = undefined;")))
                     (let ((cl-cc/vm:*vm-state* state))
                       (cl-cc/javascript/backend::%js-gdi-prepare nil nil (list name))
                       (cl-cc/javascript/backend::%js-gdi-create-global-vars (list name) nil)
                       (cl-cc/javascript/backend::%js-gdi-global-write name 17)
                       (cl-cc/javascript/backend::%js-gdi-prepare nil nil (list name))
                       (cl-cc/javascript/backend::%js-gdi-create-global-vars (list name) nil)
                       (expect (cl-cc/javascript/backend::%js-gdi-global-read name)
                               :to-equal 17)
                       (expect (not (global-write-for-name-p no-initializer name))
                               :to-be-truthy)
                       (expect (global-write-for-name-p explicit-undefined name)
                               :to-be-truthy)
                       (cl-cc/javascript/backend::%js-gdi-global-write
                        name +js-undefined+)
                       (expect (eq (cl-cc/javascript/backend::%js-gdi-global-read name)
                                   +js-undefined+)
                               :to-be-truthy)))))
  ;; Test262: test/language/global-code/decl-var.js
  (it-sequential "js-gdi-var-name-blocks-later-global-lexical-declaration"
                 (let* ((state (%js-gdi-test-state))
                        (name (%js-gdi-test-name "Math")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (let* ((global (cl-cc/javascript/backend::%js-gdi-global-object))
                            (value (%js-make-object)))
                       (%js-object-define-property
                        global "Math"
                        (%js-make-object "value" value "writable" t
                                         "enumerable" nil "configurable" t))
                       (setf (gethash name (cl-cc/vm:vm-global-vars state)) value)
                       (cl-cc/javascript/backend::%js-gdi-prepare nil nil (list name))
                       (cl-cc/javascript/backend::%js-gdi-create-global-vars (list name) nil)
                       (expect (cl-cc/javascript/backend::%js-gdi-global-var-declared-p name)
                               :to-be-truthy)
                       (expect (eq (cl-cc/javascript/backend::%js-gdi-global-read name) value)
                               :to-be-truthy)
                       (expect
                        (%js-gdi-test-error-p
                         (lambda ()
                           (cl-cc/javascript/backend::%js-gdi-prepare
                            (list (cons name :let)) nil nil))
                         "SyntaxError")
                        :to-be-truthy)
                       (expect (gethash name
                                        (cl-cc/javascript/backend::%js-gdi-lexical-environment nil))
                               :to-equal nil)))))
  ;; Test262: test/language/global-code/script-decl-lex.js
  (it-sequential "js-gdi-global-lexical-tdz-and-const-immutability"
                 (let* ((state (%js-gdi-test-state))
                        (name (%js-gdi-test-name "fixed")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (cl-cc/javascript/backend::%js-gdi-prepare
                      (list (cons name :const)) nil nil)
                     (expect (eq (%js-object-get-own-property-descriptor
                                  (cl-cc/javascript/backend::%js-gdi-global-object)
                                  "fixed")
                                 +js-undefined+)
                             :to-be-truthy)
                     (expect (%js-gdi-test-error-p
                              (lambda ()
                                (cl-cc/javascript/backend::%js-gdi-global-read name))
                              "ReferenceError")
                             :to-be-truthy)
                     (cl-cc/javascript/backend::%js-gdi-initialize-lexical name 2)
                     (expect (cl-cc/javascript/backend::%js-gdi-global-read name)
                             :to-equal 2)
                     (expect (%js-gdi-test-error-p
                              (lambda ()
                                (cl-cc/javascript/backend::%js-gdi-global-write name 3))
                              "TypeError")
                             :to-be-truthy))))
  ;; Test262: test/language/global-code/script-decl-lex.js
  (it-sequential "js-gdi-rejects-lexical-shadowing-of-restricted-prelude-globals"
                 (let ((state (%js-gdi-test-state)))
                   (let ((cl-cc/vm:*vm-state* state))
                     (dolist (name (list (%js-gdi-test-name "undefined")
                                         (%js-gdi-test-name "Infinity")
                                         (%js-gdi-test-name "NaN")))
                       (expect (%js-gdi-test-error-p
                                (lambda ()
                                  (cl-cc/javascript/backend::%js-gdi-prepare
                                   (list (cons name :let)) nil nil))
                                "SyntaxError")
                               :to-be-truthy))
                     (expect (cl-cc/javascript/backend::%js-gdi-prepare
                              (list (cons (%js-gdi-test-name "Undefined") :let)
                                    (cons (%js-gdi-test-name "infinity") :let)
                                    (cons (%js-gdi-test-name "nan") :let))
                              nil nil)
                             :to-equal +js-undefined+))))
  ;; Test262: test/language/global-code/script-decl-lex.js
  (it-sequential "js-gdi-global-lexical-persists-across-scripts"
                 (let* ((state (%js-gdi-test-state))
                        (name (%js-gdi-test-name "crossScript"))
                        (global-name (%js-gdi-test-name "globalThis"))
                        (new-var (%js-gdi-test-name "afterGlobalThisWrite"))
                        (replacement (%js-make-object)))
                   (let ((cl-cc/vm:*vm-state* state))
                     (cl-cc/javascript/backend::%js-gdi-prepare
                      (list (cons name :let)) nil nil)
                     (cl-cc/javascript/backend::%js-gdi-initialize-lexical name 1)
                     (let ((global (cl-cc/javascript/backend::%js-gdi-global-object)))
                       (setf (gethash global-name (cl-cc/vm:vm-global-vars state))
                             replacement)
                       (expect (eq (cl-cc/javascript/backend::%js-gdi-global-object)
                                   global)
                               :to-be-truthy)
                       (cl-cc/javascript/backend::%js-gdi-prepare nil nil (list new-var))
                       (cl-cc/javascript/backend::%js-gdi-create-global-vars
                        (list new-var) nil)
                       (expect (not (eq (%js-object-get-own-property-descriptor
                                         global "afterGlobalThisWrite")
                                        +js-undefined+))
                               :to-be-truthy)
                       (expect (eq (%js-object-get-own-property-descriptor
                                    replacement "afterGlobalThisWrite")
                                   +js-undefined+)
                               :to-be-truthy))
                     (cl-cc/javascript/backend::%js-gdi-prepare nil nil nil)
                     (expect (cl-cc/javascript/backend::%js-gdi-global-read name)
                             :to-equal 1)
                     (cl-cc/javascript/backend::%js-gdi-global-write name 2)
                     (expect (cl-cc/javascript/backend::%js-gdi-global-read name)
                             :to-equal 2))))
  ;; Test262: test/language/global-code/script-decl-lex-var.js
  (it-sequential "js-gdi-preflight-rejects-duplicate-and-cross-script-conflicts"
                 (let* ((state (%js-gdi-test-state))
                        (name (%js-gdi-test-name "priorLexical"))
                        (duplicate (%js-gdi-test-name "duplicateLexical")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (cl-cc/javascript/backend::%js-gdi-prepare
                      (list (cons name :let)) nil nil)
                     (expect (%js-gdi-test-error-p
                              (lambda ()
                                (cl-cc/javascript/backend::%js-gdi-prepare
                                 nil nil (list name)))
                              "SyntaxError")
                             :to-be-truthy)
                     (expect (%js-gdi-test-error-p
                              (lambda ()
                                (cl-cc/javascript/backend::%js-gdi-prepare
                                 (list (cons duplicate :let)
                                       (cons duplicate :const))
                                 nil nil))
                              "SyntaxError")
                             :to-be-truthy)
                     (expect (gethash duplicate
                                      (cl-cc/javascript/backend::%js-gdi-lexical-environment nil))
                             :to-equal nil)
                     (expect (%js-gdi-test-error-p
                              (lambda ()
                                (cl-cc/javascript/backend::%js-gdi-prepare
                                 (list (cons duplicate :let)) nil (list duplicate)))
                              "SyntaxError")
                             :to-be-truthy))))
  ;; Test262: test/language/global-code/script-decl-lex-restricted-global.js and test/language/global-code/decl-func.js
  (it-sequential "js-gdi-restricted-global-properties"
                 (let* ((state (%js-gdi-test-state))
                        (global nil)
                        (lexical-name (%js-gdi-test-name "restrictedLexical"))
                        (function-name (%js-gdi-test-name "blockedFunction"))
                        (allowed-name (%js-gdi-test-name "allowedFunction"))
                        (function (%js-make-object)))
                   (let ((cl-cc/vm:*vm-state* state))
                     (setf global (cl-cc/javascript/backend::%js-gdi-global-object))
                     (%js-object-define-property
                      global "restrictedLexical"
                      (%js-make-object "value" 1 "configurable" nil))
                     (%js-object-define-property
                      global "blockedFunction"
                      (%js-make-object "value" 1 "writable" nil
                                       "enumerable" nil "configurable" nil))
                     (%js-object-define-property
                      global "allowedFunction"
                      (%js-make-object "value" 1 "writable" t
                                       "enumerable" t "configurable" nil))
                     (expect (%js-gdi-test-error-p
                              (lambda ()
                                (cl-cc/javascript/backend::%js-gdi-prepare
                                 (list (cons lexical-name :let)) nil nil))
                              "SyntaxError")
                             :to-be-truthy)
                     (expect (%js-gdi-test-error-p
                              (lambda ()
                                (cl-cc/javascript/backend::%js-gdi-prepare
                                 nil (list function-name) nil))
                              "TypeError")
                             :to-be-truthy)
                     (setf (gethash allowed-name (cl-cc/vm:vm-function-registry state))
                           function)
                     (cl-cc/javascript/backend::%js-gdi-prepare
                      nil (list allowed-name) nil)
                     (cl-cc/javascript/backend::%js-gdi-create-global-functions
                      (list (cons allowed-name 0)))
                     (progn
                       (expect (eq (%js-get-prop global "allowedFunction") function)
                               :to-be-truthy)
                       (expect (eq (gethash allowed-name (cl-cc/vm:vm-global-vars state)) function)
                               :to-be-truthy))
                     (expect (%js-get-prop
                              (%js-object-get-own-property-descriptor
                               global "allowedFunction")
                              "configurable")
                             :to-equal nil))))
  ;; Test262: test/language/global-code/decl-var.js
  (it-sequential "js-gdi-var-and-function-preflight-on-nonextensible-global"
                 (let* ((state (%js-gdi-test-state))
                        (existing-name (%js-gdi-test-name "existingProperty"))
                        (configurable-name (%js-gdi-test-name "configurableProperty"))
                        (builtin-name (%js-gdi-test-name "Math"))
                        (missing-var (%js-gdi-test-name "newProperty"))
                        (missing-function (%js-gdi-test-name "newFunction"))
                        (builtin (%js-make-object "PI" 3)))
                   (let ((cl-cc/vm:*vm-state* state))
                     (let ((global (cl-cc/javascript/backend::%js-gdi-global-object)))
                       (%js-object-define-property
                        global "existingProperty"
                        (%js-make-object "value" 4 "writable" nil
                                         "enumerable" nil "configurable" nil))
                       (%js-object-define-property
                        global "configurableProperty"
                        (%js-make-object "value" 5 "writable" t
                                         "enumerable" nil "configurable" t))
                       (setf (gethash builtin-name (cl-cc/vm:vm-global-vars state)) builtin)
                       (cl-cc/javascript/backend::%js-gdi-prepare
                        nil nil (list builtin-name))
                       (cl-cc/javascript/backend::%js-gdi-create-global-vars
                        (list builtin-name) nil)
                       (expect (eq (cl-cc/javascript/backend::%js-gdi-global-read
                                    builtin-name)
                                   builtin)
                               :to-be-truthy)
                       (expect (%js-get-prop
                                (%js-object-get-own-property-descriptor global "Math")
                                "configurable")
                               :to-equal nil)
                       (cl-cc/javascript/objects:%js-object-prevent-extensions global))
                     (cl-cc/javascript/backend::%js-gdi-prepare
                      nil nil (list existing-name))
                     (cl-cc/javascript/backend::%js-gdi-create-global-vars
                      (list existing-name) nil)
                     (expect (cl-cc/javascript/backend::%js-gdi-global-read existing-name)
                             :to-equal 4)
                     (cl-cc/javascript/backend::%js-gdi-prepare
                      nil nil (list configurable-name))
                     (cl-cc/javascript/backend::%js-gdi-create-global-vars
                      (list configurable-name) nil)
                     (let ((descriptor
                            (%js-object-get-own-property-descriptor
                             (cl-cc/javascript/backend::%js-gdi-global-object)
                             "configurableProperty")))
                       (expect (%js-get-prop descriptor "value") :to-equal 5)
                       (expect (%js-get-prop descriptor "writable") :to-equal t)
                       (expect (%js-get-prop descriptor "enumerable") :to-equal nil)
                       (expect (%js-get-prop descriptor "configurable") :to-equal t))
                     (expect (%js-gdi-test-error-p
                              (lambda ()
                                (cl-cc/javascript/backend::%js-gdi-prepare
                                 nil nil (list missing-var)))
                              "TypeError")
                             :to-be-truthy)
                     (expect (%js-gdi-test-error-p
                              (lambda ()
                                (cl-cc/javascript/backend::%js-gdi-prepare
                                 nil (list missing-function) nil))
                              "TypeError")
                             :to-be-truthy))))
  ;; Test262: test/language/global-code/decl-func.js, test/language/statements/function/name.js, test/language/statements/function/length-dflt.js, and test/built-ins/Function/prototype/S15.3.5.2_A1_T1.js
  (it-sequential "js-gdi-function-properties-and-hoisting-metadata"
                 (let* ((state (%js-gdi-test-state))
                        (name (%js-gdi-test-name "declared"))
                        (function
                         (make-instance (quote cl-cc/vm:vm-closure-object)
                                        :entry-label "declared"
                                        :params nil)))
                   (let ((cl-cc/vm:*vm-state* state))
                     (setf (gethash name (cl-cc/vm:vm-function-registry state)) function)
                     (cl-cc/javascript/backend::%js-gdi-prepare nil (list name) nil)
                     (cl-cc/javascript/backend::%js-gdi-create-global-functions
                      (list (cons name 2)))
                     (let* ((global (cl-cc/javascript/backend::%js-gdi-global-object))
                            (global-descriptor
                             (%js-object-get-own-property-descriptor global "declared"))
                            (length-descriptor
                             (%js-object-get-own-property-descriptor function "length"))
                            (name-descriptor
                             (%js-object-get-own-property-descriptor function "name"))
                            (prototype (%js-get-prop function "prototype"))
                            (prototype-descriptor
                             (%js-object-get-own-property-descriptor function "prototype")))
                       (expect (eq (%js-get-prop global "declared") function)
                               :to-be-truthy)
                       (expect (%js-get-prop global-descriptor "writable")
                               :to-equal t) (expect (%js-get-prop global-descriptor "enumerable")
                                                    :to-equal t) (expect (%js-get-prop global-descriptor "configurable")
                                                                         :to-equal nil)
                       (expect (%js-get-prop function "name")
                               :to-equal "declared") (expect (%js-get-prop name-descriptor "value")
                                                             :to-equal "declared")
                       (expect (%js-get-prop length-descriptor "value") :to-equal 2)
                       (expect (%js-get-prop length-descriptor "writable")
                               :to-equal nil) (expect (%js-get-prop length-descriptor "enumerable")
                                                      :to-equal nil) (expect (%js-get-prop length-descriptor "configurable")
                                                                             :to-equal t)
                       (expect (%js-get-prop name-descriptor "writable")
                               :to-equal nil) (expect (%js-get-prop name-descriptor "enumerable")
                                                      :to-equal nil) (expect (%js-get-prop name-descriptor "configurable")
                                                                             :to-equal t)
                       (expect (%js-get-prop prototype-descriptor "writable")
                               :to-equal t) (expect (%js-get-prop prototype-descriptor "enumerable")
                                                    :to-equal nil)
                       (expect (%js-get-prop prototype-descriptor "configurable")
                               :to-equal nil)
                       (expect (eq (%js-get-prop prototype "constructor") function)
                               :to-be-truthy) (let ((own-property-names
                                                     (cl-cc/javascript/objects:%js-object-get-own-property-names
                                                      function)))
                                                (expect (coerce own-property-names (quote list))
                                                        :to-equal (quote ("length" "name" "prototype")))
                                                (expect (coerce (cl-cc/javascript/objects:%js-object-keys
                                                                 function)
                                                                (quote list))
                                                        :to-equal nil)) (let* ((descriptors
                                                                                (cl-cc/javascript/proxies:%js-object-get-own-property-descriptors
                                                                                 function))
                                                                               (length-property (%js-get-prop descriptors "length"))
                                                                               (name-property (%js-get-prop descriptors "name"))
                                                                               (prototype-property (%js-get-prop descriptors "prototype")))
                                                                          (expect (%js-get-prop length-property "value") :to-equal 2)
                                                                          (expect (%js-get-prop length-property "enumerable")
                                                                                  :to-equal nil)
                                                                          (expect (%js-get-prop name-property "value")
                                                                                  :to-equal "declared")
                                                                          (expect (%js-get-prop prototype-property "value")
                                                                                  :to-equal prototype))))))
  )
