{
  description = "CL-CC JavaScript frontend: lexer, parser, and runtime helpers";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-cc-javascript is a plugin frontend: its production system depends on
    # cl-cc-ast/-bootstrap/-parse/-vm, which still live inside the cl-cc
    # monorepo checkout, and cl-cc's own umbrella system transitively pulls in
    # cl-prolog/cl-parser-kit (optimize's e-graph rules), cl-boundary-kit/
    # cl-cli/cl-tty-kit (cli/repl), and cl-log-kit (boundary-kit). cl-weave is
    # the test framework.
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
    # cl-cc is the one deliberate exception. It is mid-way through a large
    # restructuring, and its only tag (v0.1.0) predates the packages/ layout
    # that :cl-cc-ast/-bootstrap/-parse/-vm are resolved from. Pinning it now
    # would pin to a tree this repository cannot build against. Revisit once
    # cl-cc cuts a tag that matches its current layout.
    cl-cc = {
      url = "github:nerima-lisp/cl-cc";
      flake = false;
    };
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.0.0";
      flake = false;
    };
    cl-prolog = {
      url = "github:nerima-lisp/cl-prolog/v1.0.1";
      flake = false;
    };
    cl-parser-kit = {
      url = "github:nerima-lisp/cl-parser-kit/v1.0.0";
      flake = false;
    };
    cl-dataflow = {
      url = "github:nerima-lisp/cl-dataflow/v1.0.0";
      flake = false;
    };
    cl-boundary-kit = {
      url = "github:nerima-lisp/cl-boundary-kit/v0.6.0";
      flake = false;
    };
    cl-cli = {
      url = "github:nerima-lisp/cl-cli/v1.0.1";
      flake = false;
    };
    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.0.0";
      flake = false;
    };
    cl-log-kit = {
      url = "github:nerima-lisp/cl-log-kit/v1.0.0";
      flake = false;
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-cc,
      cl-weave,
      cl-prolog,
      cl-parser-kit,
      cl-dataflow,
      cl-boundary-kit,
      cl-cli,
      cl-tty-kit,
      cl-log-kit,
      treefmt-nix,
    }:
    let
      # Only platforms that something actually verifies are declared (ADR-0078).
      # x86_64-linux is exercised by the CI runner; aarch64-darwin is the
      # development machine, so it is exercised by every local `nix flake
      # check`. aarch64-linux and x86_64-darwin have no such runner and are
      # therefore not advertised.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Single source of truth for the package version: the `:version` form in
      # cl-cc-javascript.asd. A release only ever edits the .asd file and every
      # Nix package follows automatically. Nix regexes are whole-string anchored
      # and `.` never spans newlines, so the version is extracted line-by-line
      # rather than with one multi-line match.
      version =
        let
          lines = nixpkgs.lib.splitString "\n" (builtins.readFile ./cl-cc-javascript.asd);
          versionLine = builtins.head (
            builtins.filter (line: builtins.match "[[:space:]]*:version \"[^\"]*\"" line != null) lines
          );
        in
        builtins.head (builtins.match "[[:space:]]*:version \"([^\"]*)\"" versionLine);

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
              timeout 600 sbcl --script scripts/run-compile-check.lisp
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

          # Rendered documentation site (Material for MkDocs). Builds fully
          # offline: Material bundles all of its assets, so no network access is
          # required inside the Nix sandbox. --strict promotes broken links and
          # unlisted pages to build failures.
          docs = pkgs.stdenvNoCC.mkDerivation {
            pname = "cl-cc-javascript-docs";
            inherit version;
            # The source root is the repository, not ./docs, because
            # docs/src/changelog.md pulls in the root CHANGELOG.md through a
            # pymdownx snippet rather than duplicating it. mkdocs therefore runs
            # from the repository root with `-f docs/mkdocs.yml`, which is what
            # makes the snippet `base_path` of "." resolve.
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [
                ./docs/mkdocs.yml
                ./docs/src
                ./CHANGELOG.md
              ];
            };
            nativeBuildInputs = [ pkgs.python3Packages.mkdocs-material ];
            buildPhase = ''
              runHook preBuild
              mkdocs build --strict --config-file docs/mkdocs.yml --site-dir "$out"
              runHook postBuild
            '';
            dontInstall = true;
            meta = {
              description = "Rendered MkDocs (Material) documentation for cl-cc-javascript";
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
                # See the note in packages.cl-cc-javascript: --non-interactive would
                # make SBCL exit before running the script at all.
                timeout 900 sbcl --script ${self}/run-tests.lisp
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
              exec timeout 900 sbcl --script ${self}/run-tests.lisp
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${test}/bin/cl-cc-javascript-test";
          };
          test = {
            type = "app";
            program = "${test}/bin/cl-cc-javascript-test";
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
            ];
            shellHook = exportDependencyEnv;
          };
        }
      );
    };
}
