(in-package #:cl-cc/javascript/backend)
(defvar *js-gdi-global-environments*
  (make-hash-table :test #'eq))
(defvar *js-gdi-global-var-declarations* (make-hash-table :test (function eq)))
(defvar *js-gdi-global-write-mirrors* (make-hash-table :test (function eq)))
(defvar *js-gdi-global-objects* (make-hash-table :test (function eq)))
(defvar *js-gdi-prelude-properties-initialized* (make-hash-table :test (function eq)))

(defun %js-gdi-lexical-environment (&optional (create-p t))
  (let* ((state cl-cc/vm:*vm-state*)
         (table (gethash state *js-gdi-global-environments*)))
    (when (and create-p (null table))
      (setf table (setf (gethash state *js-gdi-global-environments*) (make-hash-table
                                                                      :test
                                                                      #'eq))))
    table))
(defun %js-gdi-global-var-declared-p (name &optional (declare-p nil))
  (let* ((state cl-cc/vm:*vm-state*)
         (table (and state
                     (or (gethash state *js-gdi-global-var-declarations*)
                         (when declare-p
                           (setf (gethash state *js-gdi-global-var-declarations*)
                                 (make-hash-table :test (function eq))))))))
    (when (and table declare-p)
      (setf (gethash name table) t))
    (and table (gethash name table))))
(defun %js-gdi-record-global-write-mirror (name &optional (value nil value-p))
  (let ((state cl-cc/vm:*vm-state*))
    (when state
      (let ((table
              (or (gethash state *js-gdi-global-write-mirrors*)
                  (setf (gethash state *js-gdi-global-write-mirrors*)
                        (make-hash-table :test (function eq))))))
        (setf (gethash name table) t)
        (when value-p
          (setf (gethash name (cl-cc/vm:vm-global-vars state)) value))))
    value))
(defun %js-gdi-discard-global-write-mirror (name)
  "Remove a stale VM value but retain its marker to prevent fallback resurrection."
  (let* ((state cl-cc/vm:*vm-state*)
         (table (and state (gethash state *js-gdi-global-write-mirrors*))))
    (when (and table (nth-value 1 (gethash name table)))
      (remhash name (cl-cc/vm:vm-global-vars state))
      t)))

(defun %js-gdi-global-object ()
  "Return the stable global object for the current VM state."
  (let ((state cl-cc/vm:*vm-state*))
    (when state
      (or (gethash state *js-gdi-global-objects*)
          (let* ((vars (cl-cc/vm:vm-global-vars state))
                 (name (js-ident-sym "globalThis"))
                 (global
                   (multiple-value-bind (value found-p)
                       (gethash name vars)
                     (if found-p value (%js-make-object)))))
            (setf (gethash state *js-gdi-global-objects*) global
                  (gethash name vars) global)
            global)))))

(defun %js-gdi-global-descriptor (name)
  (let ((global (%js-gdi-global-object)))
    (if global
        (%js-object-get-own-property-descriptor global (symbol-name name))
        +js-undefined+)))

(defun %js-gdi-descriptor-present-p (descriptor)
  (not (eq descriptor +js-undefined+)))
(defun %js-gdi-restricted-global-name-p (name)
  (member (symbol-name name)
          (list "undefined" "Infinity" "NaN")
          :test (function string=)))
(defun %js-gdi-restricted-global-property-p (name)
  "Check restricted properties omitted from the global object mirror."
  (or (%js-gdi-restricted-global-name-p name)
      (let ((descriptor (%js-gdi-global-descriptor name)))
        (and (%js-gdi-descriptor-present-p descriptor)
             (not
              (%js-truthy
               (cl-cc/javascript/objects:%js-get-prop descriptor
                                                      "configurable")))))))
(defun %js-gdi-initialize-prelude-global-properties (names)
  "Create missing global properties for the values installed by the prelude."
  (let ((state cl-cc/vm:*vm-state*))
    (when (and state
               (not (gethash state *js-gdi-prelude-properties-initialized*)))
      (let ((global (%js-gdi-global-object))
            (vars (cl-cc/vm:vm-global-vars state)))
        (when global
          (dolist (name names)
            (multiple-value-bind (value found-p) (gethash name vars)
              (when found-p
                (%js-gdi-record-global-write-mirror name value)
                (when (eq (%js-object-get-own-property-descriptor
                           global (symbol-name name))
                          +js-undefined+)
                  (let ((writable
                          (not (%js-gdi-restricted-global-name-p name))))
                    (%js-object-define-property
                     global (symbol-name name)
                     (%js-make-object "value" value
                                      "writable" writable
                                      "enumerable" nil
                                      "configurable" writable))))))))
          (setf (gethash state *js-gdi-prelude-properties-initialized*) t)))
    +js-undefined+))

(defun %js-gdi-throw (class message)
  (cl-cc/javascript/errors:%js-throw
   (cl-cc/javascript/classes:%js-make-error-instance class message)))

(defun %js-gdi-unique-names (names)
  (let ((seen (make-hash-table :test #'eq))
        (unique nil))
    (dolist (name names (nreverse unique))
      (unless (gethash name seen)
        (setf (gethash name seen) t)
        (push name unique)))))

(defun %js-gdi-can-declare-global-var-p (name)
  (or (%js-gdi-descriptor-present-p (%js-gdi-global-descriptor name))
      (let ((global (%js-gdi-global-object)))
        (or (null global) (%js-object-extensible-p global)))))

(defun %js-gdi-can-declare-global-function-p (name)
  (and
   (not (%js-gdi-restricted-global-name-p name))
   (let* ((descriptor (%js-gdi-global-descriptor name))
          (global (%js-gdi-global-object))
          (descriptor-p (%js-gdi-descriptor-present-p descriptor)))
     (or (and (not descriptor-p)
              (or (null global) (%js-object-extensible-p global)))
         (and descriptor-p
              (or (%js-truthy
                   (cl-cc/javascript/objects:%js-get-prop descriptor
                                                          "configurable"))
                  (and (not (nth-value 1 (gethash "get" descriptor)))
                       (not (nth-value 1 (gethash "set" descriptor)))
                       (%js-truthy
                        (cl-cc/javascript/objects:%js-get-prop descriptor
                                                               "writable"))
                       (%js-truthy
                        (cl-cc/javascript/objects:%js-get-prop descriptor
                                                               "enumerable")))))))))

(defun %js-gdi-prepare (lexical-bindings function-names var-names)
  (let* ((environment (%js-gdi-lexical-environment))
         (all-var-names
          (%js-gdi-unique-names (append function-names var-names)))
         (seen-lexicals (make-hash-table :test (function eq))))
    (dolist (binding lexical-bindings)
      (let ((name (car binding)))
        (when (gethash name seen-lexicals)
          (%js-gdi-throw *js-syntax-error-class*
                         "Identifier has already been declared"))
        (setf (gethash name seen-lexicals) t)
        (when (member name all-var-names :test (function eq))
          (%js-gdi-throw *js-syntax-error-class*
                         "Lexical declaration conflicts with a var declaration"))
        (when (or (gethash name environment)
                  (%js-gdi-global-var-declared-p name))
          (%js-gdi-throw *js-syntax-error-class*
                         "Identifier has already been declared"))
        (when (%js-gdi-restricted-global-property-p name)
          (%js-gdi-throw *js-syntax-error-class*
                         "Lexical declaration conflicts with a restricted global property"))))
    (dolist (name all-var-names)
      (when (gethash name environment)
        (%js-gdi-throw *js-syntax-error-class*
                       "Var declaration conflicts with a global lexical binding")))
    (dolist (name function-names)
      (unless (%js-gdi-can-declare-global-function-p name)
        (%js-gdi-throw *js-type-error-class* "Cannot declare global function")))
    (dolist
        (name
         (%js-gdi-unique-names
          (remove-if
           (lambda (name)
             (member name function-names :test (function eq)))
           var-names)))
      (unless (%js-gdi-can-declare-global-var-p name)
        (%js-gdi-throw *js-type-error-class* "Cannot declare global variable")))
    (dolist (binding lexical-bindings)
      (setf (gethash (car binding) environment)
            (list :kind (cdr binding) :initialized nil :value +js-undefined+)))
    +js-undefined+))
(defun %js-gdi-lexical-read (name)
  (let* ((environment (%js-gdi-lexical-environment nil))
         (binding (and environment (gethash name environment))))
    (unless (and binding (getf binding :initialized))
      (%js-gdi-throw *js-reference-error-class*
                     "Cannot access global lexical binding before initialization"))
    (getf binding :value)))
(defun %js-gdi-global-read (name)
  (let* ((environment (%js-gdi-lexical-environment nil))
         (binding (and environment (gethash name environment)))
         (global (%js-gdi-global-object))
         (descriptor (%js-gdi-global-descriptor name)))
    (cond
      (binding (%js-gdi-lexical-read name))
      ((%js-gdi-descriptor-present-p descriptor)
       (cl-cc/javascript/objects:%js-get-prop global (symbol-name name)))
      ((%js-gdi-discard-global-write-mirror name)
       (%js-gdi-throw *js-reference-error-class* "Global binding is not defined"))
      (t
       (multiple-value-bind (value found-p)
           (if cl-cc/vm:*vm-state*
               (gethash name (cl-cc/vm:vm-global-vars cl-cc/vm:*vm-state*))
               (values +js-undefined+ nil))
         (if found-p
             value
             (%js-gdi-throw *js-reference-error-class* "Global binding is not defined")))))))
(defun %js-gdi-global-typeof (name)
  (let* ((environment (%js-gdi-lexical-environment nil))
         (binding (and environment (gethash name environment)))
         (global (%js-gdi-global-object))
         (descriptor (%js-gdi-global-descriptor name)))
    (cond
      (binding (%js-typeof (%js-gdi-lexical-read name)))
      ((%js-gdi-descriptor-present-p descriptor)
       (%js-typeof (cl-cc/javascript/objects:%js-get-prop global (symbol-name name))))
      ((%js-gdi-discard-global-write-mirror name) "undefined")
      (t
       (multiple-value-bind (value found-p)
           (if cl-cc/vm:*vm-state*
               (gethash name (cl-cc/vm:vm-global-vars cl-cc/vm:*vm-state*))
               (values +js-undefined+ nil))
         (if found-p
             (%js-typeof value)
             "undefined"))))))
(defun %js-gdi-global-write (name value)
  (let* ((environment (%js-gdi-lexical-environment nil))
         (binding (and environment (gethash name environment))))
    (if binding
        (progn
          (%js-gdi-lexical-read name)
          (unless (member (getf binding :kind) (list :let :class) :test (function eq))
            (%js-gdi-throw *js-type-error-class* "Assignment to immutable global lexical binding"))
          (setf (getf binding :value) value))
        (let* ((global (%js-gdi-global-object))
               (descriptor (%js-gdi-global-descriptor name)))
          (cond
            ((not global) (%js-gdi-define-global-property name value t t t))
            ((not (%js-gdi-descriptor-present-p descriptor))
             (cl-cc/javascript/objects:%js-set-prop global (symbol-name name) value)
             (when (%js-gdi-descriptor-present-p (%js-gdi-global-descriptor name))
               (%js-gdi-record-global-write-mirror name value)))
            ((or (nth-value 1 (gethash "get" descriptor))
                 (nth-value 1 (gethash "set" descriptor)))
             (cl-cc/javascript/objects:%js-set-prop global (symbol-name name) value))
            ((%js-truthy (cl-cc/javascript/objects:%js-get-prop descriptor "writable"))
             (cl-cc/javascript/objects:%js-set-prop global (symbol-name name) value)
             (%js-gdi-record-global-write-mirror name value)))))
    value))
