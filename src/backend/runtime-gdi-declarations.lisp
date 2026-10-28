(in-package #:cl-cc/javascript/backend)

(defun %js-gdi-define-global-property (name value writable enumerable configurable)
  (let ((global (%js-gdi-global-object)))
    (when global
      (%js-object-define-property global
                                  (symbol-name name)
                                  (%js-make-object "value"
                                                   value
                                                   "writable"
                                                   writable
                                                   "enumerable"
                                                   enumerable
                                                   "configurable"
                                                   configurable)))
    (when cl-cc/vm:*vm-state*
      (setf (gethash name (cl-cc/vm:vm-global-vars cl-cc/vm:*vm-state*)) value))
    value))

(defun %js-gdi-create-global-functions (function-metadata)
  (let* ((state cl-cc/vm:*vm-state*)
         (registry (and state (cl-cc/vm:vm-function-registry state))))
    (dolist (metadata function-metadata)
      (let* ((name (car metadata))
             (flags
              (if (consp (cdr metadata))
                  (cddr metadata)
                  nil))
             (non-constructable-p (member :non-constructable flags :test (function eq)))
             (prototype-p
              (or (not non-constructable-p)
                  (member :prototype flags :test (function eq))
                  (member :prototype-without-constructor flags :test (function eq))))
             (prototype-constructor-p
              (not (member :prototype-without-constructor flags :test (function eq))))
             (length
              (if non-constructable-p
                  (second metadata)
                  (cdr metadata)))
             (function (and registry (gethash name registry))))
        (unless function
          (%js-gdi-throw *js-type-error-class* "Function declaration was not instantiated"))
        (let ((descriptor (%js-gdi-global-descriptor name)))
          (if (and (%js-gdi-descriptor-present-p descriptor)
                   (not
                    (%js-truthy (cl-cc/javascript/objects:%js-get-prop descriptor "configurable"))))
              (progn
                (cl-cc/javascript/objects:%js-set-prop (%js-gdi-global-object)
                                                       (symbol-name name)
                                                       function)
                (when state
                  (setf (gethash name (cl-cc/vm:vm-global-vars state)) function)))
              (%js-gdi-define-global-property name function t t nil)))
        (%js-object-define-property function
                                    "length"
                                    (%js-make-object "value"
                                                     length
                                                     "writable"
                                                     nil
                                                     "enumerable"
                                                     nil
                                                     "configurable"
                                                     t))
        (%js-object-define-property function
                                    "name"
                                    (%js-make-object "value"
                                                     (symbol-name name)
                                                     "writable"
                                                     nil
                                                     "enumerable"
                                                     nil
                                                     "configurable"
                                                     t))
        (when prototype-p
          (let ((prototype (%js-make-object)))
            (when prototype-constructor-p
              (%js-object-define-property prototype
                                          "constructor"
                                          (%js-make-object "value"
                                                           function
                                                           "writable"
                                                           t
                                                           "enumerable"
                                                           nil
                                                           "configurable"
                                                           t)))
            (%js-object-define-property function
                                        "prototype"
                                        (%js-make-object "value"
                                                         prototype
                                                         "writable"
                                                         t
                                                         "enumerable"
                                                         nil
                                                         "configurable"
                                                         nil))))
        (%js-gdi-global-var-declared-p name t)))
    +js-undefined+))

(defun %js-gdi-create-global-vars (var-names function-names)
  (let ((state cl-cc/vm:*vm-state*))
    (dolist (name (%js-gdi-unique-names var-names))
      (unless (member name function-names :test (function eq))
        (let ((descriptor (%js-gdi-global-descriptor name)))
          (unless (%js-gdi-descriptor-present-p descriptor)
            (%js-gdi-discard-global-write-mirror name)
            (multiple-value-bind (value value-p)
                (if state
                    (gethash name (cl-cc/vm:vm-global-vars state))
                    (values nil nil))
              (%js-gdi-define-global-property name
                                              (if value-p
                                                  value
                                                  +js-undefined+)
                                              t
                                              t
                                              nil)))
          (when (and state
                     (not (nth-value 1 (gethash name (cl-cc/vm:vm-global-vars state)))))
            (setf (gethash name (cl-cc/vm:vm-global-vars state))
                  (if (%js-gdi-descriptor-present-p descriptor)
                      (cl-cc/javascript/objects:%js-get-prop descriptor "value")
                      +js-undefined+)))
          (when (%js-gdi-descriptor-present-p (%js-gdi-global-descriptor name))
            (%js-gdi-record-global-write-mirror name))))
      (%js-gdi-global-var-declared-p name t))
    +js-undefined+))

(defun %js-gdi-initialize-lexical (name value)
  (let* ((environment (%js-gdi-lexical-environment nil))
         (binding (and environment (gethash name environment))))
    (unless binding
      (%js-gdi-throw *js-reference-error-class* "Global lexical binding does not exist"))
    (when (getf binding :initialized)
      (%js-gdi-throw *js-type-error-class* "Global lexical binding was initialized twice"))
    (setf (getf binding :value) value
          (getf binding :initialized) t)
    value))

(defun %js-gdi-var-names (forms)
  (let ((names nil))
    (labels ((visit (node)
               (cond
                 ((or (cl-cc/ast:ast-defun-p node)
                      (cl-cc/ast:ast-lambda-p node)
                      (cl-cc/ast:ast-defclass-p node)) nil)
                 ((and (cl-cc/ast:ast-call-p node)
                       (cl-cc/ast:ast-var-p (cl-cc/ast:ast-call-func node))
                       (eq (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func node))
                           'cl-cc/javascript/statements:%js-try-catch-finally))
                  (dolist (arg (cl-cc/ast:ast-call-args node))
                    (if (cl-cc/ast:ast-lambda-p arg)
                        (dolist (form (cl-cc/ast:ast-lambda-body arg))
                          (visit form))
                        (visit arg))))
                 (t
                   (when
                       (and (cl-cc/ast:ast-let-p node)
                            (member :var (cl-cc/ast:ast-let-declarations node)))
                     (dolist (binding (cl-cc/ast:ast-let-bindings node))
                       (let ((name (car binding)))
                         (when
                             (and (symbolp name)
                                  (eq (symbol-package name) (find-package :cl-cc/javascript)))
                           (push name names)))))
                   (dolist (child (cl-cc/ast:ast-children node))
                     (visit child))))))
      (dolist (form forms)
        (visit form))
      (%js-gdi-unique-names (nreverse names)))))

(defun %js-gdi-selected-functions (forms)
  (let ((seen (make-hash-table :test #'eq))
        (selected nil))
    (dolist (form (reverse forms))
      (when (cl-cc/ast:ast-defun-p form)
        (let ((name (cl-cc/ast:ast-defun-name form)))
          (unless (gethash name seen)
            (setf (gethash name seen) t)
            (push form selected)))))
    selected))

(defun %js-gdi-lower-declaration (form kind)
  (let ((tail nil))
    (dolist (binding (reverse (cl-cc/ast:ast-let-bindings form)))
      (let ((name (car binding))
            (value (cdr binding)))
        (if (and (symbolp name) (eq (symbol-package name) (find-package :cl-cc/javascript)))
            (unless
                (and (eq kind :var)
                     (cl-cc/ast:ast-quote-p value)
                     (eq (cl-cc/ast:ast-quote-value value) :js-gdi-no-initializer))
              (setf tail (cons
                          (if (eq kind :var)
                              (%js-call '%js-gdi-global-write (make-ast-quote :value name) value)
                              (%js-call '%js-gdi-initialize-lexical
                                        (make-ast-quote :value name)
                                        value))
                          tail)))
            (setf tail (list (cl-cc/ast:make-ast-let :bindings (list binding) :body tail))))))
    (if tail
        (cl-cc/ast:make-ast-progn :forms tail)
        (make-ast-quote :value :js-undefined))))

(defun %js-gdi-lower-class (form)
  (list form
        (%js-call '%js-gdi-initialize-lexical
                  (make-ast-quote :value (cl-cc/ast:ast-defclass-name form))
                  (make-ast-var :name (cl-cc/ast:ast-defclass-name form)))))

(defun %js-gdi-function-metadata (functions)
  (mapcar
   (lambda (function)
     (let* ((name (cl-cc/ast:ast-defun-name function))
            (length (length (cl-cc/ast:ast-defun-params function)))
            (declarations (cl-cc/ast:ast-defun-declarations function))
            (async-p (member :js-async declarations :test #'eq))
            (generator-p (member :js-generator declarations :test #'eq)))
       (cond
         ((and (not async-p) (not generator-p)) (cons name length))
         (generator-p (list name length :non-constructable :prototype-without-constructor))
         (t (list name length :non-constructable)))))
   functions))

(defun %js-gdi-global-read-ast (name)
  (%js-call '%js-gdi-global-read (make-ast-quote :value name)))

(defun %js-gdi-global-typeof-ast (name)
  (%js-call '%js-gdi-global-typeof (make-ast-quote :value name)))

(defun %js-gdi-global-write-ast (name value)
  (%js-call '%js-gdi-global-write (make-ast-quote :value name) value))

(eval-when (:load-toplevel :execute)
  (cl-cc/javascript/syntax:register-js-parser-handler :gdi-global-read-ast
                                                      (function %js-gdi-global-read-ast))
  (cl-cc/javascript/syntax:register-js-parser-handler :gdi-global-write-ast
                                                      (function %js-gdi-global-write-ast))
  (cl-cc/javascript/syntax:register-js-parser-handler :gdi-global-typeof-ast
                                                      (function %js-gdi-global-typeof-ast)))
