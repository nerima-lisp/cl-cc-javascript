;;;; packages/javascript/src/runtime-console.lisp — JS `console' global object

(in-package :cl-cc/javascript)

;;; Data table: (stream prefix) for each console output function.
(defmacro define-js-console-output (name stream &optional prefix)
  "Define a console output function that formats all args as JS strings."
  `(defun ,name (&rest args)
     (format ,stream ,(if prefix
                          (concatenate 'string prefix "~{~A~^ ~}~%")
                          "~{~A~^ ~}~%")
             (mapcar #'%js-to-string args))
     +js-undefined+))

(define-js-console-output %js-console-log   t)
(define-js-console-output %js-console-error *error-output*)
(define-js-console-output %js-console-warn  *error-output* "Warning: ")

;;; Methods with no observable side-effects in our synchronous model.
(defparameter *%js-console-noop-methods*
  '("group" "groupEnd" "time" "timeEnd" "count" "countReset" "clear")
  "console methods that are no-ops (seeded as (constantly +js-undefined+)).")

;;; Data table: console method name → implementation.
;;; Keeping this separate from %js-make-console lets tests inspect
;;; specific entries and makes adding new methods a one-line change.
(defparameter *%js-console-method-specs*
  (list (cons "log"    #'%js-console-log)
        (cons "info"   #'%js-console-log)
        (cons "debug"  #'%js-console-log)
        (cons "error"  #'%js-console-error)
        (cons "warn"   #'%js-console-warn)
        (cons "dir"    (lambda (o &rest _) (declare (ignore _))
                         (format t "~A~%" (%js-to-string o))
                         +js-undefined+))
        (cons "table"  (lambda (&rest args)
                         (format t "~{~A~^ ~}~%" (mapcar #'%js-to-string args))
                         +js-undefined+))
        (cons "trace"  (lambda (&rest args)
                         (format t "Trace: ~{~A~^ ~}~%" (mapcar #'%js-to-string args))
                         +js-undefined+))
        (cons "assert" (lambda (condition &rest args)
                         (unless (%js-truthy condition)
                           (format *error-output* "Assertion failed: ~{~A~^ ~}~%"
                                   (mapcar #'%js-to-string args)))
                         +js-undefined+)))
  "Alist: console method name → implementation function.")

(defun %js-make-console ()
  "Construct the JS `console' global object from *%js-console-method-specs*."
  (let ((obj (%js-make-ht)))
    (dolist (entry *%js-console-method-specs*)
      (setf (gethash (car entry) obj) (cdr entry)))
    (dolist (name *%js-console-noop-methods*)
      (setf (gethash name obj) (constantly +js-undefined+)))
    obj))
