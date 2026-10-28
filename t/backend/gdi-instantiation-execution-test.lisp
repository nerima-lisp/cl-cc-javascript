(in-package #:cl-cc/javascript/backend/test)

(defun %register-backend-gdi-instantiation-tests ()

  (it-sequential "js-gdi-own-property-descriptors-include-sidecar-only-properties"
                 (let ((object (%js-make-object)))
                   (%js-object-define-property
                    object "sidecarOnly" (%js-make-object "enumerable" nil))
                   (let* ((descriptors
                           (cl-cc/javascript/proxies:%js-object-get-own-property-descriptors
                            object))
                          (descriptor (%js-get-prop descriptors "sidecarOnly")))
                     (expect (not (eq descriptor +js-undefined+)) :to-be-truthy)
                     (expect (%js-get-prop descriptor "value") :to-equal +js-undefined+)
                     (expect (%js-get-prop descriptor "enumerable") :to-equal nil)
                     (expect (%js-get-prop descriptor "configurable") :to-equal nil))))
  ;; Test262: test/language/global-code/decl-func.js
  (it-sequential "js-gdi-last-function-declaration-wins"
                 (let* ((forms
                         (cl-cc/javascript:parse-js-source
                          "function selected(){return 1;} function selected(value){return value;}"))
                        (selected
                         (cl-cc/javascript/backend::%js-gdi-selected-functions forms)))
                   (expect (length selected) :to-equal 1)
                   (expect (length (cl-cc/ast:ast-defun-params (first selected)))
                           :to-equal 1)))
  ;; Test262: test/language/global-code/decl-func.js
  (it-sequential "js-gdi-function-order-and-existing-global-property-deletion"
                 (let* ((forms
                         (cl-cc/javascript:parse-js-source
                          "function first(){return 1;} function second(){return 2;}"))
                        (selected
                         (cl-cc/javascript/backend::%js-gdi-selected-functions forms)))
                   (expect (mapcar (lambda (function)
                                     (symbol-name (cl-cc/ast:ast-defun-name function)))
                                   selected)
                           :to-equal (list "first" "second")))
                 (let* ((state (%js-gdi-test-state))
                        (name (%js-gdi-test-name "preexistingGlobal")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (setf (gethash name (cl-cc/vm:vm-global-vars state)) 97)
                     (let ((global (cl-cc/javascript/backend::%js-gdi-global-object)))
                       (%js-object-define-property
                        global "preexistingGlobal"
                        (%js-make-object "value" 97 "writable" t "enumerable" t "configurable" t))
                       (cl-cc/javascript/backend::%js-gdi-prepare nil nil (list name))
                       (cl-cc/javascript/backend::%js-gdi-create-global-vars (list name) nil)
                       (expect (cl-cc/javascript/backend::%js-gdi-global-read name) :to-equal 97)
                       (expect (cl-cc/javascript/objects:%js-delete global "preexistingGlobal") :to-equal t)
                       (expect (cl-cc/javascript/backend::%js-gdi-global-typeof name) :to-equal "undefined")
                       (expect
                        (%js-gdi-test-error-p
                         (lambda () (cl-cc/javascript/backend::%js-gdi-global-read name))
                         "ReferenceError")
                        :to-be-truthy)
                       (expect (nth-value 1 (gethash name (cl-cc/vm:vm-global-vars state)))
                               :to-equal nil)))))
  ;; Test262: test/language/global-code/decl-var.js
  (it-sequential "js-gdi-var-collector-recurses-blocks-but-stops-at-functions"
                 (let* ((forms
                         (cl-cc/javascript:parse-js-source
                          "if(true){var visibleVar;} function nested(){var hiddenVar;}"))
                        (names
                         (mapcar (function symbol-name)
                                 (cl-cc/javascript/backend::%js-gdi-var-names forms))))
                   (expect names :to-equal (list "visibleVar"))))
  ;; Test262: test/language/global-code/script-decl-lex.js
  (it-sequential "js-gdi-global-lexical-collector-respects-scope-boundaries"
                 (let ((source
                        (concatenate 'string
                                     "let lexicalName=1; const constantName=2; "
                                     "function nested(){let localName=3;} "
                                     "if(true){let blockName=4;} "
                                     "for(let loopName=0;loopName<1;loopName++){} "
                                     "switch(1){case 1:let caseName=1;} "
                                     "class Declared{}")))
                   (let ((cl-cc/javascript/statements:*js-gdi-mode* t)
                         (cl-cc/javascript/statements:*js-gdi-function-depth* 0)
                         (cl-cc/javascript/statements:*js-gdi-lexical-scope-depth* 0)
                         (cl-cc/javascript/statements:*js-gdi-collect-global-lexical-bindings* t)
                         (cl-cc/javascript/statements:*js-gdi-global-lexical-bindings* nil)
                         (cl-cc/javascript/syntax:*js-gdi-global-reference-mode* nil))
                     (cl-cc/javascript:parse-js-source source)
                     (let* ((bindings
                             (nreverse cl-cc/javascript/statements:*js-gdi-global-lexical-bindings*))
                            (names (mapcar (lambda (binding) (symbol-name (car binding))) bindings))
                            (kinds (mapcar (function cdr) bindings)))
                       (expect names :to-equal (list "lexicalName" "constantName" "Declared"))
                       (expect kinds :to-equal (list :let :const :class))))))
  ;; Test262: test/language/global-code/decl-func.js
  (it-sequential "js-gdi-script-form-builder-includes-declarations"
                 (let* ((forms
                         (cl-cc/javascript/backend:js-program-forms
                          "var lifted=1; let lexical=2; function selected(value){return value;}"))
                        (functions (remove-if-not (function cl-cc/ast:ast-defun-p) forms)))
                   (expect forms :to-be-truthy)
                   (expect (mapcar (function cl-cc/ast:ast-defun-name) functions)
                           :to-equal (list (%js-gdi-test-name "selected")))
                   (expect (some (function cl-cc/ast:ast-defvar-p) forms)
                           :to-be-truthy)))
  ;; Test262: test/language/global-code/decl-var.js
  ;; Test262 algorithm analogue: test/language/global-code/decl-var.js
  (it-sequential "js-gdi-var-preserves-restricted-global-values"
                 (let* ((state (%js-gdi-test-state))
                        (undefined-name (%js-gdi-test-name "undefined"))
                        (infinity-name (%js-gdi-test-name "Infinity"))
                        (nan-name (%js-gdi-test-name "NaN")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (let ((global (cl-cc/javascript/backend::%js-gdi-global-object)))
                       (%js-object-define-property
                        global "undefined"
                        (%js-make-object "value" +js-undefined+
                                         "writable" nil "enumerable" nil "configurable" nil))
                       (%js-object-define-property
                        global "Infinity"
                        (%js-make-object "value" cl-cc/javascript/objects:*js-inf-float*
                                         "writable" nil "enumerable" nil "configurable" nil))
                       (%js-object-define-property
                        global "NaN"
                        (%js-make-object "value" cl-cc/javascript/objects:*js-nan-float*
                                         "writable" nil "enumerable" nil "configurable" nil))
                       (cl-cc/javascript/backend::%js-gdi-prepare
                        nil nil (list undefined-name infinity-name nan-name))
                       (cl-cc/javascript/backend::%js-gdi-create-global-vars
                        (list undefined-name infinity-name nan-name) nil)
                       (expect (eq (cl-cc/javascript/backend::%js-gdi-global-read undefined-name)
                                   +js-undefined+)
                               :to-be-truthy)
                       (expect (= (cl-cc/javascript/backend::%js-gdi-global-read infinity-name)
                                  cl-cc/javascript/objects:*js-inf-float*)
                               :to-be-truthy)
                       (expect (cl-cc/javascript/objects:%js-float-nan-p
                                (cl-cc/javascript/backend::%js-gdi-global-read nan-name))
                               :to-be-truthy)
                       (dolist (name (list undefined-name infinity-name nan-name))
                         (let ((descriptor
                                (%js-object-get-own-property-descriptor global (symbol-name name))))
                           (expect (%js-get-prop descriptor "writable") :to-equal nil)
                           (expect (%js-get-prop descriptor "enumerable") :to-equal nil)
                           (expect (%js-get-prop descriptor "configurable") :to-equal nil)))))))
  ;; Test262: test/language/global-code/decl-func.js
  ;; Test262 algorithm analogue: test/language/global-code/decl-func.js
  (it-sequential "js-gdi-function-declarations-reject-restricted-prelude-globals"
                 (let* ((state (%js-gdi-test-state))
                        (restricted-names
                         (list (%js-gdi-test-name "undefined")
                               (%js-gdi-test-name "Infinity")
                               (%js-gdi-test-name "NaN")))
                        (case-varied-names
                         (list (%js-gdi-test-name "Undefined")
                               (%js-gdi-test-name "infinity")
                               (%js-gdi-test-name "nan"))))
                   (let ((cl-cc/vm:*vm-state* state))
                     (dolist (name restricted-names)
                       (expect (%js-gdi-test-error-p
                                (lambda ()
                                  (cl-cc/javascript/backend::%js-gdi-prepare
                                   nil (list name) nil))
                                "TypeError")
                               :to-be-truthy))
                     (expect (cl-cc/javascript/backend::%js-gdi-prepare
                              nil case-varied-names nil)
                             :to-equal +js-undefined+))))
  ;; Related Test262 cases: test/language/statements/class/scope-name-lex-open-heritage.js and test/language/statements/class/scope-name-lex-open-no-heritage.js.
  (it-sequential "js-gdi-class-heritage-and-named-expression-shadowing"
                 (labels ((descendants (node)
                                       (cons node
                                             (mapcan (function descendants)
                                                     (cl-cc/ast:ast-children node))))
                          (named-defclass (name forms)
                                          (find-if
                                           (lambda (node)
                                             (and (cl-cc/ast:ast-defclass-p node)
                                                  (eq (cl-cc/ast:ast-defclass-name node) name)))
                                           (mapcan (function descendants) forms)))
                          (gdi-global-read-for-name-p (nodes name)
                                                      (some
                                                       (lambda (node)
                                                         (and (cl-cc/ast:ast-call-p node)
                                                              (cl-cc/ast:ast-var-p
                                                               (cl-cc/ast:ast-call-func node))
                                                              (string= "%JS-GDI-GLOBAL-READ"
                                                                       (symbol-name
                                                                        (cl-cc/ast:ast-var-name
                                                                         (cl-cc/ast:ast-call-func node))))
                                                              (let ((argument
                                                                     (first (cl-cc/ast:ast-call-args node))))
                                                                (and (cl-cc/ast:ast-quote-p argument)
                                                                     (eq (cl-cc/ast:ast-quote-value argument)
                                                                         name)))))
                                                       nodes))
                          (ast-var-for-name-p (nodes name)
                                              (some
                                               (lambda (node)
                                                 (and (cl-cc/ast:ast-var-p node)
                                                      (eq (cl-cc/ast:ast-var-name node) name)))
                                               nodes)))
                   (let* ((child-name (%js-gdi-test-name "Child"))
                          (base-name (%js-gdi-test-name "Base"))
                          (forms
                           (cl-cc/javascript/backend:js-program-forms
                            "class Child extends Base {}"))
                          (child (named-defclass child-name forms)))
                     (expect child :to-be-truthy)
                     (when child
                       (expect (member base-name
                                       (cl-cc/ast:ast-defclass-superclasses child)
                                       :test (function eq))
                               :to-be-truthy)
                       (let ((metaclass (cl-cc/ast:ast-defclass-metaclass child)))
                         (expect metaclass :to-be-truthy)
                         (when metaclass
                           (expect (gdi-global-read-for-name-p
                                    (descendants metaclass) base-name)
                                   :to-be-truthy)))))
                   (let* ((inner-name (%js-gdi-test-name "Inner"))
                          (forms
                           (cl-cc/javascript/backend:js-program-forms
                            "const C = class Inner extends Inner { method() { return Inner; } };"))
                          (inner (named-defclass inner-name forms)))
                     (expect inner :to-be-truthy)
                     (when inner
                       (let* ((heritage
                               (first
                                (cl-cc/ast:ast-call-args
                                 (cl-cc/ast:ast-defclass-metaclass inner))))
                              (heritage-nodes (descendants heritage))
                              (method-nodes
                               (mapcan (lambda (slot)
                                         (let ((initform (cl-cc/ast:ast-slot-initform slot)))
                                           (when initform (descendants initform))))
                                       (cl-cc/ast:ast-defclass-slots inner))))
                         (expect (cl-cc/ast:ast-var-p heritage) :to-be-truthy)
                         (when (cl-cc/ast:ast-var-p heritage)
                           (expect (eq (cl-cc/ast:ast-var-name heritage) inner-name) :to-be-truthy))
                         (expect (not (gdi-global-read-for-name-p heritage-nodes inner-name))
                                 :to-be-truthy)
                         (expect (ast-var-for-name-p method-nodes inner-name) :to-be-truthy)
                         (expect (not (gdi-global-read-for-name-p method-nodes inner-name))
                                 :to-be-truthy))))))
  ;; Related Test262 case: test/language/expressions/arrow-function/dflt-params-ref-later.js.
  (it-sequential "js-gdi-arrow-later-parameter-default-remains-local"
    (labels ((descendants (node)
               (cons node
                     (mapcan (function descendants)
                             (cl-cc/ast:ast-children node))))
             (global-read-for-name-p (nodes name)
               (some (lambda (node)
                       (and (cl-cc/ast:ast-call-p node)
                            (cl-cc/ast:ast-var-p (cl-cc/ast:ast-call-func node))
                            (string= "%JS-GDI-GLOBAL-READ"
                                     (symbol-name
                                      (cl-cc/ast:ast-var-name
                                       (cl-cc/ast:ast-call-func node))))
                            (let ((argument
                                    (first (cl-cc/ast:ast-call-args node))))
                              (and (cl-cc/ast:ast-quote-p argument)
                                   (eq (cl-cc/ast:ast-quote-value argument)
                                       name)))))
                     nodes))
             (var-ref-for-name-p (nodes name)
               (some (lambda (node)
                       (and (cl-cc/ast:ast-var-p node)
                            (eq (cl-cc/ast:ast-var-name node) name)))
                     nodes)))
      (let* ((a (%js-gdi-test-name "a"))
             (b (%js-gdi-test-name "b"))
             (forms
               (cl-cc/javascript/backend:js-program-forms
                "const f=(a=b,b=1)=>a;"))
             (arrow-lambda
               (find-if (lambda (node)
                          (and (cl-cc/ast:ast-lambda-p node)
                               (equal
                                (mapcar (function first)
                                        (cl-cc/ast:ast-lambda-optional-params node))
                                (list a b))))
                        (mapcan (function descendants) forms))))
        (expect arrow-lambda :to-be-truthy)
        (when arrow-lambda
          (let* ((optionals
                   (cl-cc/ast:ast-lambda-optional-params arrow-lambda))
                 (a-default (second (assoc a optionals :test (function eq))))
                 (b-default (second (assoc b optionals :test (function eq))))
                 (lambda-nodes (descendants arrow-lambda))
                 (body-nodes
                   (mapcan (function descendants)
                           (cl-cc/ast:ast-lambda-body arrow-lambda))))
            (expect (and (cl-cc/ast:ast-var-p a-default)
                         (eq (cl-cc/ast:ast-var-name a-default) b))
                    :to-be-truthy)
            (expect (cl-cc/ast:ast-int-p b-default) :to-be-truthy)
            (expect (var-ref-for-name-p body-nodes a) :to-be-truthy)
            (expect (not (global-read-for-name-p lambda-nodes a))
                    :to-be-truthy)
            (expect (not (global-read-for-name-p lambda-nodes b))
                    :to-be-truthy))))))
  ;; Related Test262 cases: test/language/statements/function/scope-paramsbody-var-close.js and test/language/statements/try/scope-catch-block-var-none.js.
  (it-sequential "js-gdi-function-local-try-var-remains-local"
                 (labels ((descendants (node)
                                       (cons node
                                             (mapcan (function descendants)
                                                     (cl-cc/ast:ast-children node))))
                          (global-read-for-name-p (nodes name)
                                                  (some
                                                   (lambda (node)
                                                     (and (cl-cc/ast:ast-call-p node)
                                                          (cl-cc/ast:ast-var-p
                                                           (cl-cc/ast:ast-call-func node))
                                                          (string= "%JS-GDI-GLOBAL-READ"
                                                                   (symbol-name
                                                                    (cl-cc/ast:ast-var-name
                                                                     (cl-cc/ast:ast-call-func node))))
                                                          (let ((argument
                                                                 (first (cl-cc/ast:ast-call-args node))))
                                                            (and (cl-cc/ast:ast-quote-p argument)
                                                                 (eq (cl-cc/ast:ast-quote-value argument)
                                                                     name)))))
                                                   nodes))
                          (var-ref-for-name-p (nodes name)
                                              (some
                                               (lambda (node)
                                                 (and (cl-cc/ast:ast-var-p node)
                                                      (eq (cl-cc/ast:ast-var-name node) name)))
                                               nodes)))
                   (let* ((local-name (%js-gdi-test-name "localTryVar"))
                          (forms
                           (cl-cc/javascript/backend:js-program-forms
                            "function container(){try { var localTryVar=1; } finally {} return localTryVar;}"))
                          (function-node
                           (find-if
                            (lambda (node)
                              (and (cl-cc/ast:ast-defun-p node)
                                   (eq (cl-cc/ast:ast-defun-name node)
                                       (%js-gdi-test-name "container"))))
                            (mapcan (function descendants) forms)))) (expect function-node :to-be-truthy) (when function-node
                            (let ((function-nodes (descendants function-node)))
                              (expect (var-ref-for-name-p function-nodes local-name)
                                      :to-be-truthy)
                              (expect (not (global-read-for-name-p function-nodes local-name))
                                      :to-be-truthy))))))
  ;; Related Test262 cases: test/language/statements/switch/scope-lex-open-case.js and test/language/statements/switch/scope-lex-close-case.js.
  (it-sequential "js-gdi-switch-case-lexical-references-remain-local"
  (labels ((descendants (node)
             (cons node
                   (mapcan (function descendants)
                           (cl-cc/ast:ast-children node))))
           (global-read-for-name-p (nodes name)
             (some
              (lambda (node)
                (and (cl-cc/ast:ast-call-p node)
                     (cl-cc/ast:ast-var-p
                      (cl-cc/ast:ast-call-func node))
                     (string= "%JS-GDI-GLOBAL-READ"
                              (symbol-name
                               (cl-cc/ast:ast-var-name
                                (cl-cc/ast:ast-call-func node))))
                     (let ((argument
                             (first (cl-cc/ast:ast-call-args node))))
                       (and (cl-cc/ast:ast-quote-p argument)
                            (eq (cl-cc/ast:ast-quote-value argument) name)))))
              nodes))
           (var-ref-for-name-p (nodes name)
             (some
              (lambda (node)
                (and (cl-cc/ast:ast-var-p node)
                     (eq (cl-cc/ast:ast-var-name node) name)))
              nodes)))
    (let* ((case-name (%js-gdi-test-name "caseLocal"))
           (forms
             (cl-cc/javascript/backend:js-program-forms
              "switch(1){case 1:let caseLocal=1;break;case 2:caseLocal;}"))
           (nodes (mapcan (function descendants) forms)))
      (expect (var-ref-for-name-p nodes case-name) :to-be-truthy)
      (expect (not (global-read-for-name-p nodes case-name))
              :to-be-truthy))))
  ;; Related Test262 case: test/language/global-code/decl-func.js.
  (it-sequential "js-gdi-top-level-function-self-reference-is-global"
                 (labels ((descendants (node)
                            (cons node
                                  (mapcan (function descendants)
                                          (cl-cc/ast:ast-children node))))
                          (global-read-for-name-p (nodes name)
                            (some
                             (lambda (node)
                               (and (cl-cc/ast:ast-call-p node)
                                    (cl-cc/ast:ast-var-p
                                     (cl-cc/ast:ast-call-func node))
                                    (string= "%JS-GDI-GLOBAL-READ"
                                             (symbol-name
                                              (cl-cc/ast:ast-var-name
                                               (cl-cc/ast:ast-call-func node))))
                                    (let ((argument
                                           (first (cl-cc/ast:ast-call-args node))))
                                      (and (cl-cc/ast:ast-quote-p argument)
                                           (eq (cl-cc/ast:ast-quote-value argument)
                                               name)))))
                             nodes))
                          (var-reference-for-name-p (nodes name)
                            (some
                             (lambda (node)
                               (and (cl-cc/ast:ast-var-p node)
                                    (eq (cl-cc/ast:ast-var-name node) name)))
                             nodes)))
                   (let* ((global-name (%js-gdi-test-name "globalFunction"))
                          (global-forms
                           (cl-cc/javascript/backend:js-program-forms
                            "function globalFunction(){return globalFunction;}"))
                          (global-function
                           (find-if
                            (lambda (node)
                              (and (cl-cc/ast:ast-defun-p node)
                                   (eq (cl-cc/ast:ast-defun-name node) global-name)))
                            (mapcan (function descendants) global-forms))))
                     (expect global-function :to-be-truthy)
                     (when global-function
                       (expect
                        (global-read-for-name-p
                         (mapcan (function descendants)
                                 (cl-cc/ast:ast-defun-body global-function))
                         global-name)
                        :to-be-truthy)))
                   (let* ((inner-name (%js-gdi-test-name "innerFunction"))
                          (nested-forms
                           (cl-cc/javascript/backend:js-program-forms
                            (concatenate 'string
                                         "function outerFunction(){"
                                         "function innerFunction(){return innerFunction;}}")))
                          (inner-function
                           (find-if
                            (lambda (node)
                              (and (cl-cc/ast:ast-defun-p node)
                                   (eq (cl-cc/ast:ast-defun-name node) inner-name)))
                            (mapcan (function descendants) nested-forms))))
                     (expect inner-function :to-be-truthy)
                     (when inner-function
                       (let ((inner-body-nodes
                              (mapcan (function descendants)
                                      (cl-cc/ast:ast-defun-body inner-function))))
                         (expect (var-reference-for-name-p inner-body-nodes inner-name)
                                 :to-be-truthy)
                         (expect (not (global-read-for-name-p inner-body-nodes inner-name))
                                 :to-be-truthy)))))))
