(in-package #:cl-cc/javascript/objects)

(defvar %js-this +js-undefined+
  "Dynamically bound to the receiver when a JS method is called.
JS source `this.x' compiles to (%js-get-prop %js-this \"x\").
Methods are called via %js-funcall-with-this which establishes this binding.")

(in-package #:cl-cc/javascript/objects)

(defun %js-vm-closure-p (x)
  "Package-safe predicate for a compiled-JS closure (a cl-cc/vm:vm-closure-object).
The VM package is NOT an ASDF compile-time dependency of the JS frontend (closures
are invoked through the runtime *js-apply-fn* pointer), so the vm-closure-object
type symbol cannot be named at read time — resolve it by name at runtime."
  (let ((pkg (find-package "CL-CC/VM")))
    (and
      pkg
      (let ((sym (find-symbol "VM-CLOSURE-OBJECT" pkg)))
        (and sym (find-class sym nil) (typep x sym))))))

(in-package #:cl-cc/javascript/objects)

(defun %js-object-instanceof-p (obj constructor)
  "JS instanceof. constructor must be a hash-table with __prototype__."
  (when (%js-ht-p obj)
    (let ((proto (and (%js-ht-p constructor) (gethash "__prototype__" constructor))))
      (when proto
        (let ((obj-proto (gethash "__proto__" obj)))
          (loop while (%js-ht-p obj-proto)
                when (eq obj-proto proto)
                  return t
                do (setf obj-proto (gethash "__proto__" obj-proto))
                finally (return)))))))
