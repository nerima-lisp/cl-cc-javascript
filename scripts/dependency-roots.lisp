;;;; scripts/dependency-roots.lisp — locate this repo's nerima-lisp siblings.
;;;;
;;;; cl-cc-javascript is a plugin frontend for the cl-cc umbrella compiler: it
;;;; depends on packages that still live inside the cl-cc monorepo checkout
;;;; (cl-cc-ast/-bootstrap/-parse/-vm, plus everything cl-cc's own umbrella
;;;; system pulls in transitively — optimize needs cl-prolog/cl-parser-kit,
;;;; cli/repl need cl-boundary-kit/cl-cli/cl-tty-kit, boundary-kit needs
;;;; cl-log-kit) and on cl-weave for tests. Each is located via an environment
;;;; variable, falling back to a sibling checkout beside this repo (the ghq
;;;; layout every nerima-lisp repo already assumes).

(require :asdf)

(defparameter *dependency-specs*
  '(("CL_CC_JAVASCRIPT_CL_CC_ROOT" "cl-cc")
    ("CL_CC_JAVASCRIPT_CL_WEAVE_ROOT" "cl-weave")
    ("CL_CC_JAVASCRIPT_CL_PROLOG_ROOT" "cl-prolog")
    ("CL_CC_JAVASCRIPT_CL_PARSER_KIT_ROOT" "cl-parser-kit")
    ("CL_CC_JAVASCRIPT_CL_DATAFLOW_ROOT" "cl-dataflow")
    ("CL_CC_JAVASCRIPT_CL_BOUNDARY_KIT_ROOT" "cl-boundary-kit")
    ("CL_CC_JAVASCRIPT_CL_CLI_ROOT" "cl-cli")
    ("CL_CC_JAVASCRIPT_CL_TTY_KIT_ROOT" "cl-tty-kit")
    ("CL_CC_JAVASCRIPT_CL_LOG_KIT_ROOT" "cl-log-kit"))
  "(ENV-VAR SIBLING-DIRECTORY-NAME) pairs for every source-tree dependency.")

(defparameter *project-root*
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-directory-pathname (or *load-pathname* *compile-file-pathname*)))
  "The cl-cc-javascript checkout root (parent of this scripts/ directory).")

(defun dependency-root (env-var sibling-name)
  (uiop:ensure-directory-pathname
   (or (uiop:getenv env-var)
       (merge-pathnames (format nil "../~A/" sibling-name) *project-root*))))

(defun dependency-source-registry-directives ()
  (loop for (env-var sibling-name) in *dependency-specs*
        collect (list :directory (truename (dependency-root env-var sibling-name)))))

(defun initialize-dependency-source-registry ()
  (asdf:initialize-source-registry
   (list* :source-registry
          (append (dependency-source-registry-directives)
                  (list (list :directory (truename *project-root*))
                        :ignore-inherited-configuration))))
  ;; cl-cc-ast/-bootstrap/-parse/-vm live under packages/*/ inside the cl-cc
  ;; checkout, one level deeper than the :directory entry above reaches.
  ;; cl-cc.asd's own load-time eval-when registers each of them by relative
  ;; path, so loading it here (without building :cl-cc) makes them
  ;; discoverable for :cl-cc-javascript's own :depends-on.
  (load (merge-pathnames "cl-cc.asd" (dependency-root "CL_CC_JAVASCRIPT_CL_CC_ROOT" "cl-cc"))))
