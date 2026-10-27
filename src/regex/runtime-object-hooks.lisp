(in-package #:cl-cc/javascript/regex)

(defun %js-clone-object-regexp (value)
  (if (js-regexp-p value)
      (values (%js-make-regex (js-regexp-source value) (js-regexp-flags value))
              t)
      (values nil nil)))

(eval-when (:load-toplevel :execute)
  (%js-register-object-regex-clone-handler #'%js-clone-object-regexp))
