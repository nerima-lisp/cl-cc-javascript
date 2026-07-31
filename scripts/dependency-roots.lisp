;;;; scripts/dependency-roots.lisp — locate this repo's nerima-lisp siblings.
;;;;
;;;; cl-cc-javascript is a plugin frontend for the cl-cc umbrella compiler: it
;;;; depends on packages that still live inside the cl-cc monorepo checkout
;;;; (cl-cc-ast/-bootstrap/-parse/-vm, plus everything cl-cc's own umbrella
;;;; system pulls in transitively — optimize needs cl-prolog/cl-parser-kit,
;;;; cli/repl need cl-boundary-kit/cl-cli/cl-tty-kit, boundary-kit needs
;;;; cl-log-kit and, as of its v2.0.0, cl-host-kit too), on cl-date-kit for
;;;; the Temporal runtime's IANA time zone support, on cl-json-kit for
;;;; JSON.parse/JSON.stringify, on cl-concurrent-kit for the generator
;;;; runtime's suspend/resume coroutine channel, and on cl-weave for tests.
;;;; cl-host-kit itself is transitive-only here (cl-cc-javascript's own code
;;;; does not import it) -- see flake.nix's comment on that input for why.
;;;; Each is located via an environment variable, falling back to a sibling
;;;; checkout beside this repo (the ghq layout every nerima-lisp repo
;;;; already assumes).

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
    ("CL_CC_JAVASCRIPT_CL_LOG_KIT_ROOT" "cl-log-kit")
    ("CL_CC_JAVASCRIPT_CL_DATE_KIT_ROOT" "cl-date-kit")
    ("CL_CC_JAVASCRIPT_CL_JSON_KIT_ROOT" "cl-json-kit")
    ("CL_CC_JAVASCRIPT_CL_CONCURRENT_KIT_ROOT" "cl-concurrent-kit")
    ("CL_CC_JAVASCRIPT_CL_HOST_KIT_ROOT" "cl-host-kit"))
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
Each entry ends in a single slash, so it is scanned non-recursively: a
recursive scan of the cl-cc checkout would also turn up
packages/javascript/cl-cc-javascript.asd, a second, divergent definition of
this very system. No trailing colon, so nothing further is inherited."
  (format nil "~{~A~^:~}" (mapcar #'namestring (dependency-roots))))

(defun initialize-dependency-source-registry ()
  ;; Set CL_SOURCE_REGISTRY as well as configuring ASDF programmatically, and
  ;; keep the two in agreement.
  ;;
  ;; cl-tty-kit.asd re-runs asdf:initialize-source-registry itself, at load
  ;; time, with `(:tree <its own dir>) :inherit-configuration`. That discards
  ;; whatever registry was in force and rebuilds it from the *environment*, so a
  ;; registry that was only ever set programmatically does not survive. cl-cc's
  ;; repl subsystem depends on :cl-tty-kit and :cl-boundary-kit in that order,
  ;; so without this the load of :cl-cc fails half-way through with
  ;; "Component :CL-BOUNDARY-KIT not found" — cl-tty-kit having erased the
  ;; entry that would have resolved it moments earlier.
  (setf (uiop:getenv "CL_SOURCE_REGISTRY") (dependency-source-registry-string))
  (asdf:initialize-source-registry
   (list* :source-registry
          (append (dependency-source-registry-directives)
                  (list :ignore-inherited-configuration))))
  ;; cl-cc-ast/-bootstrap/-parse/-vm live under packages/*/ inside the cl-cc
  ;; checkout, one level deeper than the :directory entry above reaches.
  ;; cl-cc.asd's own load-time eval-when registers each of them by relative
  ;; path, so loading it here (without building :cl-cc) makes them
  ;; discoverable for :cl-cc-javascript's own :depends-on.
  (load (merge-pathnames "cl-cc.asd" (dependency-root "CL_CC_JAVASCRIPT_CL_CC_ROOT" "cl-cc"))))
