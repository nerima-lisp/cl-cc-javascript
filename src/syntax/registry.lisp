(in-package #:cl-cc/javascript/syntax)

(defvar *js-lexer-extension-handlers*
  (make-hash-table :test (function eq)))

(defvar *js-source-parser*
  nil)

(defun register-js-lexer-extension (kind handler)
  (unless (functionp handler)
    (error "JavaScript lexer extension ~S must be a function" kind))
  (setf (gethash kind *js-lexer-extension-handlers*) handler))

(defun js-lexer-extension-handler (kind)
  (gethash kind *js-lexer-extension-handlers*))

(defun register-js-source-parser (parser)
  (unless (functionp parser)
    (error "JavaScript source parser must be a function"))
  (setf *js-source-parser* parser))

(defun js-parse-source-tokens (tokens)
  (unless *js-source-parser*
    (error "JavaScript source parser has not been registered"))
  (funcall *js-source-parser* tokens))

(defun js-call-lexer-extension (kind source pos)
  (let ((handler (js-lexer-extension-handler kind)))
    (unless handler
      (error "JavaScript lexer extension ~S has not been registered" kind))
    (funcall handler source pos)))
(defvar *js-parser-handlers* (make-hash-table :test (function equal)))
(defun register-js-parser-handler (name handler)
  (unless (functionp handler)
    (error "JavaScript parser handler ~S must be a function" name))
  (setf (gethash name *js-parser-handlers*) handler))
(defun js-parser-handler (name)
  (gethash name *js-parser-handlers*))
(defun js-call-parser-handler (name &rest args)
  (let ((handler (js-parser-handler name)))
    (unless handler
      (error "JavaScript parser handler ~S has not been registered" name))
    (apply handler args)))
