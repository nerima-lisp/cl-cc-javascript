(in-package #:cl-cc/javascript/backend/test)

(defun %js-gdi-expect-prelude-global-properties (global)
  (dolist
      (property
       (list (list "undefined" +js-undefined+)
             (list "Infinity" cl-cc/javascript/objects:*js-inf-float*)
             (list "NaN" cl-cc/javascript/objects:*js-nan-float*)))
    (let* ((name (first property))
           (descriptor (%js-object-get-own-property-descriptor global name))
           (value (%js-get-prop descriptor "value")))
      (expect (not (eq descriptor +js-undefined+)) :to-be-truthy)
      (expect
       (cond
         ((string= name "undefined") (eq value +js-undefined+))
         ((string= name "Infinity") (= value cl-cc/javascript/objects:*js-inf-float*))
         (t (cl-cc/javascript/objects:%js-float-nan-p value)))
       :to-be-truthy)
      (expect (%js-get-prop descriptor "writable") :to-equal nil)
      (expect (%js-get-prop descriptor "enumerable") :to-equal nil)
      (expect (%js-get-prop descriptor "configurable") :to-equal nil))))

(defun %register-backend-gdi-prelude-global-properties-tests ()
  (it-sequential "js-gdi-prelude-global-properties-cover-all-intrinsics"
                 (let* ((state (cl-cc/vm:make-vm-state))
                        (specs cl-cc/javascript/backend::*js-prelude-global-specs*)
                        (names
                         (mapcar
                          (lambda (spec)
                            (cl-cc/javascript/syntax:js-ident-sym (second spec)))
                          specs))
                        (math-name (cl-cc/javascript/syntax:js-ident-sym "Math"))
                        (infinity-name (cl-cc/javascript/syntax:js-ident-sym "Infinity")))
                   (let ((cl-cc/vm:*vm-state* state))
                     (let* ((global (cl-cc/javascript/backend::%js-gdi-global-object))
                            (vars (cl-cc/vm:vm-global-vars state))
                            (shared-value (%js-make-object)))
                       (dolist (spec specs)
                         (let* ((name (second spec))
                                (symbol (cl-cc/javascript/syntax:js-ident-sym name))
                                (value
                                 (cond
                                   ((string= name "undefined") +js-undefined+)
                                   ((string= name "Infinity")
                                    cl-cc/javascript/objects:*js-inf-float*)
                                   ((string= name "NaN")
                                    cl-cc/javascript/objects:*js-nan-float*)
                                   ((string= name "globalThis") global)
                                   (t shared-value))))
                           (setf (gethash symbol vars) value)))
                       (cl-cc/javascript/backend::%js-gdi-initialize-prelude-global-properties
                        names)
                       (dolist (spec specs)
                         (let* ((name (second spec))
                                (restricted
                                 (member name
                                         (list "undefined" "Infinity" "NaN")
                                         :test
                                         (function string=)))
                                (descriptor
                                 (%js-object-get-own-property-descriptor global name)))
                           (expect (not (eq descriptor +js-undefined+)) :to-be-truthy)
                           (expect (%js-get-prop descriptor "writable")
                                   :to-equal
                                   (not restricted))
                           (expect (%js-get-prop descriptor "enumerable") :to-equal nil)
                           (expect (%js-get-prop descriptor "configurable")
                                   :to-equal
                                   (not restricted))))
                       (%js-gdi-expect-prelude-global-properties global)
                       (cl-cc/javascript/backend::%js-gdi-global-write math-name 17)
                       (expect
                        (%js-get-prop (%js-object-get-own-property-descriptor global "Math")
                                      "value")
                        :to-equal
                        17)
                       (cl-cc/javascript/backend::%js-gdi-prepare nil nil (list infinity-name))
                       (cl-cc/javascript/backend::%js-gdi-create-global-vars
                        (list infinity-name)
                        nil)
                       (%js-gdi-expect-prelude-global-properties global)
                       (expect
                        (%js-get-prop (%js-object-get-own-property-descriptor global "Math")
                                      "value")
                        :to-equal
                        17))))))
