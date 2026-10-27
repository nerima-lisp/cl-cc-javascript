(defpackage #:cl-cc/javascript/v8-objects
  (:use #:cl)
  (:export #:object-shape #:make-object-shape #:*shape-registry*
           #:find-or-create-shape #:shape-slot-offset
           #:+imt-size+ #:imt-entry #:make-imt-entry
           #:inline-method-table #:make-inline-method-table
           #:imt-insert #:imt-lookup
           #:make-mark-word #:mark-word-gc-color
           #:defvalue-type #:value-type-def #:*value-types*))
