;;;; scripts/dependency-roots.lisp — locate this repo's nerima-lisp siblings.
;;;;
;;;; This registry includes cl-cc-ast, cl-cc-bootstrap, cl-cc-parse,
;;;; cl-cc-vm, cl-cc-runtime, their toolkit dependencies, this frontend's
;;;; direct toolkit dependencies, and cl-weave for tests.
;;;; Each root comes from an environment variable or a sibling checkout beside
;;;; this repository.

(require :asdf)

(defparameter *dependency-specs*
  '(("CL_CC_JAVASCRIPT_CL_CC_AST_ROOT" "cl-cc-ast")
    ("CL_CC_JAVASCRIPT_CL_CC_BOOTSTRAP_ROOT" "cl-cc-bootstrap")
    ("CL_CC_JAVASCRIPT_CL_CC_PARSE_ROOT" "cl-cc-parse")
    ("CL_CC_JAVASCRIPT_CL_CC_VM_ROOT" "cl-cc-vm")
    ("CL_CC_JAVASCRIPT_CL_CC_RUNTIME_ROOT" "cl-cc-runtime")
    ("CL_CC_JAVASCRIPT_CL_PARSER_KIT_ROOT" "cl-parser-kit")
    ("CL_CC_JAVASCRIPT_CL_REGEX_KIT_ROOT" "cl-regex-kit")
    ("CL_CC_JAVASCRIPT_CL_TTY_KIT_ROOT" "cl-tty-kit")
    ("CL_CC_JAVASCRIPT_CL_HOST_KIT_ROOT" "cl-host-kit")
    ("CL_CC_JAVASCRIPT_CL_PROCESS_KIT_ROOT" "cl-process-kit")
    ("CL_CC_JAVASCRIPT_CL_BOUNDARY_KIT_ROOT" "cl-boundary-kit")
    ("CL_CC_JAVASCRIPT_CL_LOG_KIT_ROOT" "cl-log-kit")
    ("CL_CC_JAVASCRIPT_CL_CODEC_KIT_ROOT" "cl-codec-kit")
    ("CL_CC_JAVASCRIPT_CL_CONCURRENT_KIT_ROOT" "cl-concurrent-kit")
    ("CL_CC_JAVASCRIPT_CL_DATE_KIT_ROOT" "cl-date-kit")
    ("CL_CC_JAVASCRIPT_CL_JSON_KIT_ROOT" "cl-json-kit")
    ("CL_CC_JAVASCRIPT_CL_WEAVE_ROOT" "cl-weave"))
  "(ENV-VAR SIBLING-DIRECTORY-NAME) pairs for every source-tree dependency.")

(defparameter *project-root*
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-directory-pathname (or *load-pathname* *compile-file-pathname*)))
  "The cl-cc-javascript checkout root (parent of this scripts/ directory).")

(defun dependency-root (env-var sibling-name)
  (uiop:ensure-directory-pathname
   (or (uiop:getenv env-var)
       (merge-pathnames (format nil "../~A/" sibling-name) *project-root*))))

(defun dependency-roots ()
  "Every directory that must be on the source registry, dependencies then self."
  (append (loop for (env-var sibling-name) in *dependency-specs*
                collect (truename (dependency-root env-var sibling-name)))
          (list (truename *project-root*))))

(defun dependency-source-registry-directives ()
  (loop for root in (dependency-roots)
        collect (list :directory root)))

(defun dependency-source-registry-string ()
  "The same roots as a CL_SOURCE_REGISTRY value.
Each entry ends in a slash, so ASDF scans each root non-recursively. The value
has no trailing colon, so it does not inherit additional roots."
  (format nil "~{~A~^:~}" (mapcar #'namestring (dependency-roots))))

(defun initialize-dependency-source-registry ()
  ;; cl-tty-kit reinitializes ASDF at load time, so export roots before loading
  ;; dependencies and initialize ASDF in this image as well.
  (setf (uiop:getenv "CL_SOURCE_REGISTRY") (dependency-source-registry-string))
  (asdf:initialize-source-registry
   (list* :source-registry
          (append (dependency-source-registry-directives)
                  (list :ignore-inherited-configuration)))))
