{
  description = "CL-CC JavaScript frontend: lexer, parser, and runtime helpers";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-nix-forge is the org's Nix flake-library for building/testing Common
    # Lisp packages -- "crane for Common Lisp". Used below for exactly two
    # pure, dependency-graph-agnostic pieces: `fromAsdSystem` (the version
    # single source of truth) and `mkDocsSite` (the MkDocs Material site,
    # byte-for-byte the same `mkdocs build --strict` derivation this file
    # used to hand-roll).
    #
    # Its flagship preset, `mkPackageFlake`, and the `lispDerivation`
    # dependency-graph model it is built on (`lispDependencies`/
    # `lispCheckDependencies` resolved into CL_SOURCE_REGISTRY) are
    # deliberately NOT adopted for packages.cl-cc-javascript / checks.default
    # / devShells.default below, and this is not an oversight: `lispDerivation`
    # (lib/core/asdf-derivation.nix, read directly at this pin) builds a
    # system with exactly `(require "asdf") (asdf:load-system "<name>")`,
    # with no hook to run arbitrary Lisp first. cl-cc-javascript's production
    # system `:depends-on (:cl-cc-ast :cl-cc-bootstrap :cl-cc-parse
    # :cl-cc-vm)` -- four systems with no discoverable .asd of their own;
    # they exist only because cl-cc.asd registers them (as an eval-when side
    # effect) when IT is loaded. scripts/dependency-roots.lisp's
    # `initialize-dependency-source-registry` does exactly that extra
    # `(load ".../cl-cc.asd")` step before anything else runs -- a step
    # `lispDerivation` has no argument to express. Forcing the main package
    # through it would build a derivation whose own build phase cannot
    # resolve its dependencies, so the hand-rolled buildPhase below (which
    # runs the same dependency-roots.lisp bootstrap CI and a contributor's
    # shell both already rely on) stays. Re-check this reasoning against
    # lib/core/asdf-derivation.nix before revisiting it on a future
    # cl-nix-forge upgrade.
    #
    # Pinned to a release tag, `inputs.nixpkgs.follows`'d like every real
    # flake input below.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # cl-cc-javascript is a plugin frontend: its production system depends on
    # cl-cc-ast/-bootstrap/-parse/-vm, which still live inside the cl-cc
    # monorepo checkout, and cl-cc's own umbrella system transitively pulls in
    # cl-prolog/cl-parser-kit (optimize's e-graph rules), cl-boundary-kit/
    # cl-cli/cl-tty-kit (cli/repl), and cl-log-kit (boundary-kit). cl-date-kit
    # gives the Temporal runtime real IANA time zone support (host zone
    # discovery and instant -> local-zone projection; see
    # docs/src/compatibility.md for what that does and does not cover).
    # cl-json-kit replaces the JSON.parse/JSON.stringify runtime's own ad hoc
    # parser/writer with an RFC-8259-conformant one (95/95 JSONTestSuite
    # must-accept, 188/188 must-reject) — adopted directly through its own
    # null-value/false-value/true-value/number-encoder hooks, not an adapter;
    # see runtime-json.lisp for what those hooks are used for. cl-concurrent-
    # kit's unbuffered CSP channel (SEND blocks until the matching RECV takes
    # the value — a two-party rendezvous) replaces the generator runtime's own
    # hand-rolled mutex+condvar+turn-tracking for its suspend/resume coroutine
    # hand-off; see runtime-generator.lisp. cl-weave is the test framework.
    #
    # Every one of these is consumed as a plain source tree (`flake = false`)
    # rather than as a flake, because scripts/dependency-roots.lisp locates
    # them through CL_CC_JAVASCRIPT_*_ROOT environment variables and hands the
    # paths to ASDF's source registry. Only the directory is ever needed.
    #
    # PACKAGE_STANDARD.md asks for `inputs.nixpkgs.follows` on every input. That
    # rule does not apply to a `flake = false` input: such an input has no
    # sub-inputs to redirect, so the override is a no-op AND nix prints
    # "has an override for a non-existent input 'nixpkgs'" once per input on
    # every single command. Nine warnings on every build teach the reader to
    # ignore warnings, which costs more than the rule buys. treefmt-nix is a
    # real flake input and does carry `follows`.
    #
    # Siblings are pinned to release tags: a bare `github:nerima-lisp/<name>`
    # follows that repo's default branch, so an upstream push to main breaks
    # this repo's CI without warning.
    #
    # cl-cc is pinned to a commit rather than a tag. Its only tag is v0.1.0,
    # which predates the packages/ layout that :cl-cc-ast/-bootstrap/-parse/-vm
    # are resolved from, and it cannot cut a new one yet: its own
    # `nix flake check` fails with 55 failures and 31 errors. Those are not new
    # — its pre-migration check only ran the cl-cc-prolog-tools sub-suite, so
    # the main suite had never been wired to the gate at all.
    #
    # A commit is as immutable as a tag, which is what the pinning rule is
    # actually for; a bare `github:nerima-lisp/cl-cc` follows the default
    # branch and would break this repository on an unrelated upstream push.
    # Move to `/vX.Y.Z` once cl-cc's suite is green and it releases.
    cl-cc = {
      url = "github:nerima-lisp/cl-cc/594456c6671356508a9393a97761be41e4ef8f1f";
      flake = false;
    };
    # v1.0.0 -> v1.1.0: internal reorg (org package-standard adoption, file
    # splits) plus one additive feature (defmatcher/expect-extend multi-part
    # descriptions). No behavior change to how a raw-source-tree consumer
    # like this repo sees it — checked against cl-weave's own CHANGELOG.md
    # before bumping.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.1.0";
      flake = false;
    };
    # v1.0.1 -> v1.1.0: internal performance work (indexed substitution,
    # tabled-answer replay, hash-table dispatch) plus a coverage report
    # target. No public API change — checked against cl-prolog's CHANGELOG.md.
    cl-prolog = {
      url = "github:nerima-lisp/cl-prolog/v1.1.0";
      flake = false;
    };
    # v1.0.0 -> v1.0.1: org package-standard conformance only (file renames,
    # `defpackage` designator style, test-system name). v1.0.1 -> v1.0.2: two
    # bug fixes (a dropped :position on parse-pratt's token-limit failure
    # path, and a decimal-literal tokenizer overflow on very long integer
    # parts) — no public API change either way. Checked against
    # cl-parser-kit's CHANGELOG.md both times.
    cl-parser-kit = {
      url = "github:nerima-lisp/cl-parser-kit/v1.0.2";
      flake = false;
    };
    # v1.0.0 -> v1.1.0: additive-only `:parallel` keyword on run-pipeline/
    # map-pipeline (default nil, backward compatible); CHANGELOG.md states
    # "No public API changed or removed" explicitly.
    cl-dataflow = {
      url = "github:nerima-lisp/cl-dataflow/v1.1.0";
      flake = false;
    };
    # v0.6.0 -> v1.0.0: CHANGELOG.md states "No exported symbol, protocol, or
    # documented behavior changes from 0.6.0" — this release only adds the
    # 1.x semver stability commitment and fixes internal build/test-harness
    # bugs (none of which this repo's raw-source-tree consumption touches).
    # v1.0.0 -> v2.0.0: real breaking changes (default set-fn/unset-fn/
    # hostname-fn/username-fn/exit-fn/args-source implementations moved onto
    # a new required `cl-host-kit` dependency; the optional process-kit/json
    # subsystems were removed) — none of which cl-cc-javascript's own code is
    # exposed to, since this package only needs cl-boundary-kit resolvable
    # for cl-cc's build (see CL_CC_JAVASCRIPT_CL_BOUNDARY_KIT_ROOT below),
    # never imports it directly. Bumped after adding cl-host-kit as a new
    # input below to satisfy the new transitive requirement.
    cl-boundary-kit = {
      url = "github:nerima-lisp/cl-boundary-kit/v2.0.0";
      flake = false;
    };
    # v1.0.1 -> v1.1.0: CHANGELOG.md states "No behavior of the cl-cli system
    # itself changed" — org package-standard conformance only.
    cl-cli = {
      url = "github:nerima-lisp/cl-cli/v1.1.0";
      flake = false;
    };
    # v1.0.0 -> v1.0.3: three bug fixes (a FORMAT directive-parsing bug in a
    # sixel test, a read-count validation bug, a wide-glyph alignment test)
    # plus an internal cl-weave test-migration and macro consolidation — no
    # public API change, checked against cl-tty-kit's CHANGELOG.md.
    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.0.3";
      flake = false;
    };
    # v1.0.0 -> v2.0.0, evaluated 2026-07-31 (a prior session deliberately left
    # this bump for its own dedicated evaluation rather than doing it as a
    # side effect of unblocking cl-date-kit/cl-concurrent-kit/cl-host-kit as
    # inputs — that evaluation is this comment). v2.0.0's own BREAKING section
    # covers dropping cl-log-kit's zero-runtime-dependency guarantee (now
    # needs exactly those three packages) and rotating-file-handler's default
    # rotation clock switching from local time to UTC — neither affects this
    # repo: cl-log-kit is a transitive dependency only (cl-cc's umbrella pulls
    # it in via cl-boundary-kit; grepped src/*.lisp and t/*.lisp for any
    # direct reference — none), so no code here ever constructs a
    # rotating-file-handler or otherwise observes the clock change. Version
    # floors cl-log-kit.asd declares for the three new dependencies
    # (cl-date-kit >= 0.2.0, cl-concurrent-kit >= 0.1.0, cl-host-kit >= 0.2.0)
    # are already met by the pins below. Safe bump.
    cl-log-kit = {
      url = "github:nerima-lisp/cl-log-kit/v2.0.0";
      flake = false;
    };
    cl-date-kit = {
      url = "github:nerima-lisp/cl-date-kit/v0.2.0";
      flake = false;
    };
    cl-json-kit = {
      url = "github:nerima-lisp/cl-json-kit/v1.0.1";
      flake = false;
    };
    # v0.1.0 -> v0.2.0: substantial internal rework (intrusive-list FIFO,
    # bitmask-keyed channel waiters, CAS-based executor task state, several
    # new define-*/with-* macro consolidations, a promise/stream/executor
    # feature layer) but zero change to the three functions this repo
    # actually calls (make-channel/send/recv) -- checked the CHANGELOG's own
    # "### Changed" section line by line for a signature change to any of
    # the three before bumping; found none.
    cl-concurrent-kit = {
      url = "github:nerima-lisp/cl-concurrent-kit/v0.2.0";
      flake = false;
    };
    # Not used directly by cl-cc-javascript's own code (evaluated and
    # rejected on its own merits earlier this session: this repo's
    # host/filesystem surface is too small to justify it as a direct
    # dependency) — declared purely so cl-boundary-kit v2.0.0, which now
    # requires it, is resolvable. See cl-boundary-kit's comment above.
    cl-host-kit = {
      url = "github:nerima-lisp/cl-host-kit/v0.2.1";
      flake = false;
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # paredit-cli: the org's structure-editing CLI for safe S-expression
    # refactoring, meant to be reached for aggressively while touching this
    # repository's Lisp sources (2026 refactor goal). Unlike every CL sibling
    # above, this is a REAL flake input, not `flake = false`: those are raw
    # source trees ASDF loads directly, whereas what this repo actually wants
    # is paredit-cli's own already-built binary (`packages.${system}.default`,
    # a Rust/crane derivation) — there is no ASDF system to load here at all.
    # Exposed only in devShells.default below (a local/interactive refactoring
    # tool), not packages/checks: nothing in this repo's own build or test
    # suite depends on it.
    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-nix-forge,
      cl-cc,
      cl-weave,
      cl-prolog,
      cl-parser-kit,
      cl-dataflow,
      cl-boundary-kit,
      cl-cli,
      cl-tty-kit,
      cl-log-kit,
      cl-date-kit,
      cl-json-kit,
      cl-concurrent-kit,
      cl-host-kit,
      treefmt-nix,
      paredit-cli,
    }:
    let
      # CI builds and tests only x86_64-linux, so that is the sole declared
      # system: the flake never advertises a platform it does not verify
      # (ADR-0078). aarch64-darwin was dropped on 2026-08-01. Its only
      # verification was a local `nix flake check` on a development machine, and
      # a run nobody can tell was skipped is not a gate. aarch64-linux and
      # x86_64-darwin were already undeclared for the same reason.
      #
      # Consequence, accepted deliberately: every per-system output -- packages,
      # checks, apps AND devShells -- is generated from this one list, so
      # `nix develop` and `nix build` no longer work on macOS. Development
      # happens on Linux. See PACKAGE_STANDARD.md, section "systems".
      systems = [
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Single source of truth for the package version: the `:version` form in
      # cl-cc-javascript.asd. A release only ever edits the .asd file and every
      # Nix package follows automatically. `fromAsdSystem` replaces this file's
      # former hand-rolled `builtins.match` extraction with cl-nix-forge's own
      # (lib/batteries/version.nix): unlike the regex this used to run, it
      # requires the file's two `defsystem` forms (the production system and
      # cl-cc-javascript/test) to unanimously agree on `:version`, and refuses
      # to silently pick whichever one happened to match first if they ever
      # drift. Pure function of the .asd's text, so any one system's
      # instantiation of cl-nix-forge answers it identically -- the same
      # pattern `mkPackageFlake` itself uses for its own systems-spanning call.
      version = cl-nix-forge.lib.${builtins.head systems}.fromAsdSystem ./cl-cc-javascript.asd;

      # scripts/dependency-roots.lisp reads one environment variable per source
      # tree dependency; these are the values it expects.
      dependencyEnv = {
        CL_CC_JAVASCRIPT_CL_CC_ROOT = toString cl-cc;
        CL_CC_JAVASCRIPT_CL_WEAVE_ROOT = toString cl-weave;
        CL_CC_JAVASCRIPT_CL_PROLOG_ROOT = toString cl-prolog;
        CL_CC_JAVASCRIPT_CL_PARSER_KIT_ROOT = toString cl-parser-kit;
        CL_CC_JAVASCRIPT_CL_DATAFLOW_ROOT = toString cl-dataflow;
        CL_CC_JAVASCRIPT_CL_BOUNDARY_KIT_ROOT = toString cl-boundary-kit;
        CL_CC_JAVASCRIPT_CL_CLI_ROOT = toString cl-cli;
        CL_CC_JAVASCRIPT_CL_TTY_KIT_ROOT = toString cl-tty-kit;
        CL_CC_JAVASCRIPT_CL_LOG_KIT_ROOT = toString cl-log-kit;
        CL_CC_JAVASCRIPT_CL_DATE_KIT_ROOT = toString cl-date-kit;
        CL_CC_JAVASCRIPT_CL_JSON_KIT_ROOT = toString cl-json-kit;
        CL_CC_JAVASCRIPT_CL_CONCURRENT_KIT_ROOT = toString cl-concurrent-kit;
        CL_CC_JAVASCRIPT_CL_HOST_KIT_ROOT = toString cl-host-kit;
      };
      exportDependencyEnv = nixpkgs.lib.concatStrings (
        nixpkgs.lib.mapAttrsToList (
          name: value: "export ${name}=${nixpkgs.lib.escapeShellArg value}\n"
        ) dependencyEnv
      );

      # treefmt drives `nix fmt` and the `checks.<system>.formatting` gate.
      # Scope is Nix only: nixfmt is a zero-footgun, low-diff formatter, whereas
      # YAML formatters mangle the GitHub Actions `on:` key and Markdown
      # reformatting would churn the whole docs tree.
      treefmtEval = forAllSystems (
        system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          cl = cl-nix-forge.lib.${system};
        in
        rec {
          # Compile-and-load gate: proves every component in the .asd actually
          # builds against the pinned sibling checkouts.
          cl-cc-javascript = pkgs.stdenvNoCC.mkDerivation {
            pname = "cl-cc-javascript";
            inherit version;
            src = self;
            nativeBuildInputs = [
              pkgs.sbcl
              pkgs.coreutils
            ];
            buildPhase = ''
              runHook preBuild
              export HOME="$TMPDIR/home"
              mkdir -p "$HOME"
              ${exportDependencyEnv}
              # NOT `sbcl --noinform --non-interactive --script FILE`: SBCL processes
              # --non-interactive first and exits before --script ever loads the file,
              # silently and with status 0. That is what the pre-CI flake ran here, so
              # this gate passed without compiling anything. --script already implies
              # --disable-debugger --no-sysinit --no-userinit.
              #
              # `--kill-after=30`: SBCL defers signals to safepoints, so a tight
              # compiled loop outlives a bare SIGTERM; escalating to SIGKILL after
              # a grace period is cl-nix-forge's own documented default for its
              # check helpers (docs/src/reference/checks.md), adopted here by hand
              # since this buildPhase isn't one of those helpers (see the
              # cl-nix-forge input comment for why).
              timeout --kill-after=30 600 sbcl --script scripts/run-compile-check.lisp
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/share/common-lisp/source/cl-cc-javascript"
              cp -R . "$out/share/common-lisp/source/cl-cc-javascript"
              runHook postInstall
            '';
            meta = {
              description = "CL-CC JavaScript frontend: lexer, parser, and runtime helpers";
              homepage = "https://github.com/nerima-lisp/cl-cc-javascript";
              license = pkgs.lib.licenses.mit;
              platforms = pkgs.lib.platforms.unix;
            };
          };

          default = cl-cc-javascript;

          # Rendered documentation site (Material for MkDocs), via
          # cl-nix-forge's `mkDocsSite` (lib/batteries/docs.nix) -- a pure,
          # dependency-graph-agnostic builder that produces byte-for-byte the
          # same derivation this file used to hand-roll: `mkdocs build
          # --strict`, fully offline (Material bundles its own assets), --
          # promoting a broken link or an unlisted page to a build failure.
          # The source root is the repository, not ./docs, because mkdocs runs
          # from the repository root with `-f docs/mkdocs.yml`.
          docs = cl.mkDocsSite {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./docs/mkdocs.yml
              ./docs/src
            ];
            mkdocsYmlName = "docs/mkdocs.yml";
            pname = "cl-cc-javascript-docs";
            inherit version;
            meta = {
              description = "Rendered MkDocs (Material) documentation for cl-cc-javascript";
              homepage = "https://github.com/nerima-lisp/cl-cc-javascript";
              license = pkgs.lib.licenses.mit;
            };
          };

          # `nix build .#coverage-report`: runs the regression suite under
          # SB-COVER via scripts/run-coverage.lisp (pre-existing, previously
          # unwired into flake.nix — CI and `nix flake check` never ran it) and
          # publishes the HTML report as $out, matching the shape cl-prolog's
          # v1.1.0 established. `checks.coverage` below only asserts the
          # report exists, the same restraint cl-prolog's docs give for the
          # same reason: SB-COVER's HTML output isn't a numeric gate without
          # its own parser, which this repository does not have yet.
          coverage-report = pkgs.stdenvNoCC.mkDerivation {
            pname = "cl-cc-javascript-coverage-report";
            inherit version;
            src = self;
            nativeBuildInputs = [
              pkgs.sbcl
              pkgs.coreutils
            ];
            buildPhase = ''
              runHook preBuild
              export HOME="$TMPDIR/home"
              mkdir -p "$HOME"
              ${exportDependencyEnv}
              export TZDIR="${pkgs.tzdata}/share/zoneinfo"
              timeout --kill-after=30 900 sbcl --script scripts/run-coverage.lisp
              # Prints the this-repo-only percentage to the build log (and
              # to summary.txt in $out below) from the LCOV report
              # run-coverage.lisp just wrote -- unambiguous by absolute
              # path, unlike the HTML report's basename-keyed links.
              # Best-effort: run-coverage.lisp's LCOV export itself is
              # best-effort (see its comment on a known SB-COVER bug), so
              # coverage.lcov may not exist this run; do not fail the whole
              # coverage-report build over that secondary output.
              timeout --kill-after=30 60 sbcl --script scripts/coverage-summary.lisp | tee coverage-summary.txt || true
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              cp -R coverage-report "$out"
              cp coverage-summary.txt "$out/"
              if [ -f coverage.lcov ]; then cp coverage.lcov "$out/"; fi
              runHook postInstall
            '';
            meta = {
              description = "SB-COVER HTML coverage report for cl-cc-javascript";
              homepage = "https://github.com/nerima-lisp/cl-cc-javascript";
              license = pkgs.lib.licenses.mit;
            };
          };
        }
      );

      # `nix fmt` entry point.
      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      # Granularity lives here, NOT in extra GitHub Actions jobs: `nix flake
      # check` evaluates each attribute as its own derivation, in parallel, with
      # build caching. Add a check here rather than a job in ci.yml.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # The Temporal time-zone tests read real IANA data through
          # cl-date-kit's TZDIR/zoneinfo lookup (see docs/src/compatibility.md),
          # so the Nix sandbox needs its own zoneinfo tree: nixpkgs' `tzdata`
          # package, not whatever the host happens to have at
          # /usr/share/zoneinfo, which the sandbox does not expose anyway.
          # Matches cl-date-kit's own flake.nix.
          tzdir = "${pkgs.tzdata}/share/zoneinfo";
        in
        {
          default =
            pkgs.runCommand "cl-cc-javascript-tests"
              {
                nativeBuildInputs = [
                  pkgs.sbcl
                  pkgs.coreutils
                ];
              }
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME" "$out"
                ${exportDependencyEnv}
                export TZDIR="${tzdir}"
                # See the note in packages.cl-cc-javascript: --non-interactive would
                # make SBCL exit before running the script at all. --kill-after=30
                # matches cl-nix-forge's own check helpers' default grace period.
                timeout --kill-after=30 900 sbcl --script ${self}/run-tests.lisp
                touch "$out/passed"
              '';

          # The compile gate is kept as its own check so a pure load failure is
          # distinguishable from a test failure without reading the log.
          compile = self.packages.${system}.cl-cc-javascript;

          # Fails `nix flake check` when any tracked Nix file is unformatted,
          # turning the formatter into an enforced CI gate.
          formatting = treefmtEval.${system}.config.build.check self;

          # `packages.docs` runs `mkdocs build --strict`, so a broken link or a
          # page missing from the nav fails here rather than after the merge to
          # main, in the publish workflow.
          docs = self.packages.${system}.docs;

          # Fails if the coverage run itself fails (compile error, a test
          # signaling instead of failing cleanly, SB-COVER erroring) or
          # produces no report; does not gate on a percentage. See the
          # comment on packages.coverage-report for why.
          coverage = pkgs.runCommand "cl-cc-javascript-coverage-report-check" { } ''
            test -f ${self.packages.${system}.coverage-report}/cover-index.html
            touch "$out"
          '';
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          test = pkgs.writeShellApplication {
            name = "cl-cc-javascript-test";
            runtimeInputs = [
              pkgs.sbcl
              pkgs.coreutils
            ];
            text = ''
              ${exportDependencyEnv}
              export TZDIR="${pkgs.tzdata}/share/zoneinfo"
              exec timeout --kill-after=30 900 sbcl --script ${self}/run-tests.lisp
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${test}/bin/cl-cc-javascript-test";
            meta.description = "Run the cl-cc-javascript test suite (alias for apps.test)";
          };
          test = {
            type = "app";
            program = "${test}/bin/cl-cc-javascript-test";
            meta.description = "Run the cl-cc-javascript test suite under a 900s timeout";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.sbcl
              pkgs.perl # scripts/with-timeout.pl, for running the suite by hand
              paredit-cli.packages.${system}.default # `paredit` binary; see the input's own comment
            ];
            shellHook = ''
              ${exportDependencyEnv}
              export TZDIR="${pkgs.tzdata}/share/zoneinfo"
            '';
          };
        }
      );
    };
}
