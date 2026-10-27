;;;; packages/javascript/src/runtime-builtins.lisp — JS built-in dispatch table
;;;;
;;;; *js-builtin-map* maps built-in name strings to CL functions.
;;;; This file contains the misc runtime builtin helpers used by the table.
(in-package #:cl-cc/javascript/errors)

(defun %js-error-is-error (val) "ES2026 Error.isError: true when VAL is an Error object." (and (%js-ht-p val) (%js-object-instanceof-p val (%js-object-error-class))))
