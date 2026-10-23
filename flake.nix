{
  description = "CL-CC JavaScript frontend: lexer, parser, and runtime helpers";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-nix-forge supplies `fromAsdSystem` and `mkDocsSite`. Its package
    # preset is not used: at v0.6.1, `lispDerivation` only runs
    # `(require "asdf") (asdf:load-system "<name>")`, so it cannot set up
    # this repository's dependency roots or run the compile/test scripts. The
    # custom phases below handle those steps. Recheck
    # `lib/core/asdf-derivation.nix` before replacing them after an upgrade.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.6.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The compiler dependency closure includes five cl-cc component repos and
    # their required source kits. cl-date-kit provides Temporal time-zone
    # support, cl-json-kit backs JSON.parse/JSON.stringify, cl-concurrent-kit
    # supplies generator channels, and cl-weave provides the test framework.
    #
    # Every one of these is consumed as a plain source tree (`flake = false`)
    # rather than as a flake, because scripts/dependency-roots.lisp locates
    # them through CL_CC_JAVASCRIPT_*_ROOT environment variables and hands the
    # paths to ASDF's source registry. Only the directory is ever needed.
    #
    # Raw source inputs have no `nixpkgs` sub-inputs to redirect. treefmt-nix is
    # a flake input and follows nixpkgs.
    #
    # Source inputs use fixed commit or release references instead of
    # following their upstream default branches.
    cl-cc-ast = {
      url = "github:nerima-lisp/cl-cc-ast/a45c5acecfccb91a43f6a04251e8a5d6ec3d3213";
      flake = false;
    };
    cl-cc-bootstrap = {
      url = "github:nerima-lisp/cl-cc-bootstrap/027f6c9826010c15789454e69abd2930738b50af";
      flake = false;
    };
    cl-cc-parse = {
      url = "github:nerima-lisp/cl-cc-parse/75d8699835731ec6ca44e15c82ef02601f5100fe";
      flake = false;
    };
    cl-cc-runtime = {
      url = "github:nerima-lisp/cl-cc-runtime/d23ea44512b162def39ec981426c4c8e1af4df84";
      flake = false;
    };
    cl-cc-vm = {
      url = "github:nerima-lisp/cl-cc-vm/462213fcf5e0e6cecc09992e8cb0b7ed48dbce2f";
      flake = false;
    };
    # v1.0.0 -> v1.1.0: internal reorg (org package-standard adoption, file
    # splits) plus one additive feature (defmatcher/expect-extend multi-part
    # descriptions). No behavior change to how a raw-source-tree consumer
    # like this repo sees it — checked against cl-weave's own CHANGELOG.md
    # before bumping.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.4.0";
      flake = false;
    };
    cl-process-kit = {
      url = "github:nerima-lisp/cl-process-kit/1276a8b8db6120ac15a0911c255a586b3a030ca1";
      flake = false;
    };
    cl-regex-kit = {
      url = "github:nerima-lisp/cl-regex-kit/da83905cad2bcb28518ebb28cac6628c654bb328";
      flake = false;
    };
    # cl-boundary-kit v2.0.0 added cl-host-kit as a required dependency. The
    # pinned process and concurrency kits also depend on cl-boundary-kit.
    cl-boundary-kit = {
      url = "github:nerima-lisp/cl-boundary-kit/v2.3.0";
      flake = false;
    };
    # v1.0.0 -> v1.0.3: three bug fixes (a FORMAT directive-parsing bug in a
    # sixel test, a read-count validation bug, a wide-glyph alignment test)
    # plus an internal cl-weave test-migration and macro consolidation — no
    # public API change, checked against cl-tty-kit's CHANGELOG.md.
    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.6.1";
      flake = false;
    };
    cl-codec-kit = {
      url = "github:nerima-lisp/cl-codec-kit/v0.6.0";
      flake = false;
    };
    # Runtime and process systems depend on cl-log-kit; its ASDF dependencies
    # on date, concurrency, and host kits are pinned below.
    cl-log-kit = {
      url = "github:nerima-lisp/cl-log-kit/v2.2.0";
      flake = false;
    };
    cl-date-kit = {
      url = "github:nerima-lisp/cl-date-kit/v1.1.1";
      flake = false;
    };
    cl-json-kit = {
      url = "github:nerima-lisp/cl-json-kit/v1.2.0";
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
      url = "github:nerima-lisp/cl-concurrent-kit/v0.6.1";
      flake = false;
    };
    # The Temporal runtime reads TZ through `host-kit:getenv` (see
    # runtime-temporal.lisp), replacing this repo's last `uiop:` call site in
    # src/. The VM also depends on host-kit, and boundary-kit requires it.
    cl-host-kit = {
      url = "github:nerima-lisp/cl-host-kit/v0.3.1";
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
      url = "github:nerima-lisp/paredit-cli/v1.6.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-nix-forge,
      cl-cc-ast,
      cl-cc-bootstrap,
      cl-cc-parse,
      cl-cc-runtime,
      cl-cc-vm,
      cl-weave,
      cl-process-kit,
      cl-regex-kit,
      cl-boundary-kit,
      cl-tty-kit,
      cl-codec-kit,
      cl-log-kit,
      cl-date-kit,
      cl-json-kit,
      cl-concurrent-kit,
      cl-host-kit,
      treefmt-nix,
      paredit-cli,
    }:
    let
      # CI gates this package on x86_64-linux.
      systems = [ "x86_64-linux" ];
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
        CL_CC_JAVASCRIPT_CL_CC_AST_ROOT = toString cl-cc-ast;
        CL_CC_JAVASCRIPT_CL_CC_BOOTSTRAP_ROOT = toString cl-cc-bootstrap;
        CL_CC_JAVASCRIPT_CL_CC_PARSE_ROOT = toString cl-cc-parse;
        CL_CC_JAVASCRIPT_CL_CC_RUNTIME_ROOT = toString cl-cc-runtime;
        CL_CC_JAVASCRIPT_CL_CC_VM_ROOT = toString cl-cc-vm;
        CL_CC_JAVASCRIPT_CL_WEAVE_ROOT = toString cl-weave;
        CL_CC_JAVASCRIPT_CL_PROCESS_KIT_ROOT = toString cl-process-kit;
        CL_CC_JAVASCRIPT_CL_REGEX_KIT_ROOT = toString cl-regex-kit;
        CL_CC_JAVASCRIPT_CL_BOUNDARY_KIT_ROOT = toString cl-boundary-kit;
        CL_CC_JAVASCRIPT_CL_TTY_KIT_ROOT = toString cl-tty-kit;
        CL_CC_JAVASCRIPT_CL_CODEC_KIT_ROOT = toString cl-codec-kit;
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
          # publishes the HTML report as $out, matching the shape cl-prolog-kit's
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
          # cl-date-kit's TZDIR/zoneinfo lookup (see docs/src/reference/compatibility.md),
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
