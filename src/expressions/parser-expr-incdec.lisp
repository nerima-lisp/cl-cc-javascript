(in-package #:cl-cc/javascript/expressions)

;;; ─── Increment / decrement on places (obj.x / arr[i]) ────────────────────────
(defun %js-place-get-prop-p (ast)
  "True when AST is an assignable property place — either a public property
access (%js-get-prop OBJ KEY) or a private field access
(%js-class-private-field-get OBJ KEY)."
  (and (ast-call-p ast)
       (ast-var-p (ast-call-func ast))
       (member (ast-var-name (ast-call-func ast)) '(%js-get-prop %js-class-private-field-get))
       (= (length (ast-call-args ast)) 2)))

(defun %js-lower-place-incdec (place op return-new-p)
  "Lower ++/-- applied to a property/element PLACE.
PLACE may be a public (%js-get-prop) or private (%js-class-private-field-get) access.
OP is '+ or '-. RETURN-NEW-P true means prefix (yields updated value); false
means postfix (yields original). OBJ and KEY are captured in temps so the place
expression is evaluated exactly once."
  (let* ((obj (first (ast-call-args place)))
         (key (second (ast-call-args place)))
         (get-fn (ast-var-name (ast-call-func place)))
         (set-fn
          (if (eq get-fn '%js-class-private-field-get)
              '%js-class-private-field-set
              '%js-set-prop))
         (obj-tmp (gensym "JS-OBJ-"))
         (key-tmp (gensym "JS-KEY-"))
         (old-tmp (gensym "JS-OLD-")))
    (flet ((bumped ()
             (make-ast-binop :op op :lhs (make-ast-var :name old-tmp) :rhs (make-ast-int :value 1))))
      (make-ast-let :bindings
                    (list (cons obj-tmp obj) (cons key-tmp key))
                    :body
                    (list
                     (make-ast-let :bindings
                                   (list
                                    (cons old-tmp
                                          (%js-call get-fn
                                                    (make-ast-var :name obj-tmp)
                                                    (make-ast-var :name key-tmp))))
                                   :body
                                   (list
                                    (%js-call set-fn
                                              (make-ast-var :name obj-tmp)
                                              (make-ast-var :name key-tmp)
                                              (bumped))
                                    (if return-new-p
                                        (bumped)
                                        (make-ast-var :name old-tmp)))))))))

(defun %js-incdec-setq (var-sym op-sym)
  "The (setq VAR-SYM (OP-SYM VAR-SYM 1)) AST shared by ++/--'s plain-variable
prefix and postfix lowering below."
  (make-ast-setq :var
                 var-sym
                 :value
                 (make-ast-binop :op
                                 op-sym
                                 :lhs
                                 (make-ast-var :name var-sym)
                                 :rhs
                                 (make-ast-int :value 1))))

(defun %js-lower-incdec (expr op-sym prefix-p fallback-helper)
  (let ((global-name (%js-gdi-reference-name expr)))
    (cond
      (global-name
       (let ((tmp (gensym "JS-GDI-INCDEC-")))
         (flet ((bumped (value)
                  (make-ast-binop :op op-sym :lhs value :rhs (make-ast-int :value 1)))
                (write-value (value)
                  (%js-gdi-global-write-ast global-name value)))
           (if prefix-p
               (write-value (bumped expr))
               (make-ast-let :bindings
                             (list (cons tmp expr))
                             :body
                             (list
                              (make-ast-progn :forms
                                              (list (write-value (bumped (make-ast-var :name tmp)))
                                                    (make-ast-var :name tmp)))))))))
      ((ast-var-p expr)
       (let ((var-sym (ast-var-name expr)))
         (if prefix-p
             (%js-incdec-setq var-sym op-sym)
             (let ((tmp (gensym "JS-POSTFIX-")))
               (make-ast-let :bindings
                             (list (cons tmp (make-ast-var :name var-sym)))
                             :body
                             (list (%js-incdec-setq var-sym op-sym) (make-ast-var :name tmp)))))))
      ((%js-place-get-prop-p expr) (%js-lower-place-incdec expr op-sym prefix-p))
      (t (%js-call fallback-helper expr)))))
