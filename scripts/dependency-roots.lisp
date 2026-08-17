;;;; scripts/dependency-roots.lisp — locate this repo's nerima-lisp siblings.
;;;;
;;;; cl-cc-javascript is a plugin frontend for the cl-cc umbrella compiler.
;;;; Its production system depends on cl-cc-ast/-bootstrap/-parse/-vm; its
;;;; /test system depends on cl-cc-pipeline instead of the full cl-cc umbrella
;;;; (see cl-cc-javascript.asd's own comment on that choice, and cl-cc-php's
;;;; precedent for it), which pulls in cl-cc-type/-optimize/-expand/-binary/
;;;; -mir/-codegen(-native)/-runtime/-cps transitively. None of these eleven
;;;; cl-cc-* names has a .asd anywhere except its own standalone repository —
;;;; cl-cc.asd carries no in-tree copy of any of them. cl-cc's own umbrella
;;;; system separately pulls in cl-prolog-kit/cl-parser-kit (optimize's
;;;; e-graph rules), cl-boundary-kit/cl-cli/cl-tty-kit (cli/repl), and
;;;; cl-log-kit (boundary-kit). cl-regex-kit and cl-process-kit are cl-cc-vm's
;;;; and cl-cc-runtime's/cl-cc-binary's own dependencies respectively, and
;;;; cl-codec-kit is cl-process-kit's. On top of the compiler graph, this repo
;;;; needs cl-date-kit for the Temporal runtime's IANA time zone support,
;;;; cl-json-kit for JSON.parse/JSON.stringify, cl-concurrent-kit for the
;;;; generator runtime's suspend/resume coroutine channel, and cl-weave for
;;;; tests. cl-host-kit is needed both transitively (cl-boundary-kit v2.0.0
;;;; requires it, and so now do cl-cc-vm/-expand/-runtime) and directly: the
;;;; Temporal runtime reads the host TZ variable through host-kit:getenv --
;;;; see runtime-temporal.lisp.
;;;; Each is located via an environment variable, falling back to a sibling
;;;; checkout beside this repo (the ghq layout every nerima-lisp repo
;;;; already assumes).

(require :asdf)

(defparameter *dependency-specs*
  '(("CL_CC_JAVASCRIPT_CL_CC_ROOT" "cl-cc")
    ("CL_CC_JAVASCRIPT_CL_WEAVE_ROOT" "cl-weave")
    ("CL_CC_JAVASCRIPT_CL_PROLOG_KIT_ROOT" "cl-prolog-kit")
    ("CL_CC_JAVASCRIPT_CL_PARSER_KIT_ROOT" "cl-parser-kit")
    ("CL_CC_JAVASCRIPT_CL_DATAFLOW_KIT_ROOT" "cl-dataflow-kit")
    ("CL_CC_JAVASCRIPT_CL_BOUNDARY_KIT_ROOT" "cl-boundary-kit")
    ("CL_CC_JAVASCRIPT_CL_CLI_ROOT" "cl-cli")
    ("CL_CC_JAVASCRIPT_CL_TTY_KIT_ROOT" "cl-tty-kit")
    ("CL_CC_JAVASCRIPT_CL_LOG_KIT_ROOT" "cl-log-kit")
    ("CL_CC_JAVASCRIPT_CL_DATE_KIT_ROOT" "cl-date-kit")
    ("CL_CC_JAVASCRIPT_CL_JSON_KIT_ROOT" "cl-json-kit")
    ("CL_CC_JAVASCRIPT_CL_CONCURRENT_KIT_ROOT" "cl-concurrent-kit")
    ("CL_CC_JAVASCRIPT_CL_HOST_KIT_ROOT" "cl-host-kit")
    ;; Standalone cl-cc-* subsystems and their own dependencies, needed only
    ;; by cl-cc-javascript/test (via cl-cc-pipeline). See this file's header
    ;; comment and cl-cc-javascript.asd's /test comment for why these exist
    ;; and why they are not folded into the production system's own set above.
    ("CL_CC_JAVASCRIPT_CL_CC_AST_ROOT" "cl-cc-ast")
    ("CL_CC_JAVASCRIPT_CL_CC_BOOTSTRAP_ROOT" "cl-cc-bootstrap")
    ("CL_CC_JAVASCRIPT_CL_CC_PARSE_ROOT" "cl-cc-parse")
    ("CL_CC_JAVASCRIPT_CL_CC_VM_ROOT" "cl-cc-vm")
    ("CL_CC_JAVASCRIPT_CL_CC_TYPE_ROOT" "cl-cc-type")
    ("CL_CC_JAVASCRIPT_CL_CC_OPTIMIZE_ROOT" "cl-cc-optimize")
    ("CL_CC_JAVASCRIPT_CL_CC_EXPAND_ROOT" "cl-cc-expand")
    ("CL_CC_JAVASCRIPT_CL_CC_BINARY_ROOT" "cl-cc-binary")
    ;; Also reaches cl-cc-target.asd: both it and cl-cc-mir.asd live at this
    ;; same repository's root.
    ("CL_CC_JAVASCRIPT_CL_CC_MIR_ROOT" "cl-cc-mir")
    ;; cl-cc-codegen-native is one checkout holding three systems, none at
    ;; its root (codegen/cl-cc-codegen.asd, emit/cl-cc-emit.asd,
    ;; regalloc/cl-cc-regalloc.asd) -- each needs its own entry here because
    ;; `dependency-source-registry-directives` below does a non-recursive
    ;; :directory scan per root, so a single root at the checkout's top would
    ;; find none of the three. flake.nix sets each of the three env vars to a
    ;; subpath of the one cl-cc-codegen-native input; the local-checkout
    ;; fallback below does the same relative to a single sibling directory.
    ("CL_CC_JAVASCRIPT_CL_CC_CODEGEN_ROOT" "cl-cc-codegen-native/codegen")
    ("CL_CC_JAVASCRIPT_CL_CC_EMIT_ROOT" "cl-cc-codegen-native/emit")
    ("CL_CC_JAVASCRIPT_CL_CC_REGALLOC_ROOT" "cl-cc-codegen-native/regalloc")
    ("CL_CC_JAVASCRIPT_CL_CC_RUNTIME_ROOT" "cl-cc-runtime")
    ("CL_CC_JAVASCRIPT_CL_CC_CPS_ROOT" "cl-cc-cps")
    ("CL_CC_JAVASCRIPT_CL_REGEX_KIT_ROOT" "cl-regex-kit")
    ("CL_CC_JAVASCRIPT_CL_PROCESS_KIT_ROOT" "cl-process-kit")
    ("CL_CC_JAVASCRIPT_CL_CODEC_KIT_ROOT" "cl-codec-kit"))
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
