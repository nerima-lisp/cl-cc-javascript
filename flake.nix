{
  description = "cl-cc-javascript: JavaScript frontend for the cl-cc Common Lisp compiler";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # cl-cc-javascript is a plugin frontend: its production system depends on
    # cl-cc-ast/-bootstrap/-parse/-vm, which still live inside the cl-cc
    # monorepo checkout, and cl-cc's own umbrella system transitively pulls in
    # cl-prolog/cl-parser-kit (optimize's e-graph rules), cl-boundary-kit/
    # cl-cli/cl-tty-kit (cli/repl), and cl-log-kit (boundary-kit). cl-weave is
    # the test framework. All are plain source trees, matched to the env vars
    # scripts/dependency-roots.lisp reads.
    cl-cc = {
      url = "github:nerima-lisp/cl-cc";
      flake = false;
    };
    cl-weave = {
      url = "github:nerima-lisp/cl-weave";
      flake = false;
    };
    cl-prolog = {
      url = "github:nerima-lisp/cl-prolog";
      flake = false;
    };
    cl-parser-kit = {
      url = "github:nerima-lisp/cl-parser-kit";
      flake = false;
    };
    cl-dataflow = {
      url = "github:nerima-lisp/cl-dataflow";
      flake = false;
    };
    cl-boundary-kit = {
      url = "github:nerima-lisp/cl-boundary-kit";
      flake = false;
    };
    cl-cli = {
      url = "github:nerima-lisp/cl-cli";
      flake = false;
    };
    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit";
      flake = false;
    };
    cl-log-kit = {
      url = "github:nerima-lisp/cl-log-kit";
      flake = false;
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
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems =
        function: nixpkgs.lib.genAttrs systems (system: function (import nixpkgs { inherit system; }));
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
        nixpkgs.lib.mapAttrsToList (name: value: "export ${name}=${nixpkgs.lib.escapeShellArg value}\n") dependencyEnv
      );
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.sbcl ];
          shellHook = exportDependencyEnv;
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);

      packages = forAllSystems (pkgs: {
        default = pkgs.stdenvNoCC.mkDerivation {
          pname = "cl-cc-javascript";
          version = "0.1.0";
          src = self;
          nativeBuildInputs = [
            pkgs.sbcl
            pkgs.perl
          ];
          buildPhase = ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            ${exportDependencyEnv}
            chmod +x scripts/with-timeout.pl
            scripts/with-timeout.pl 600 sbcl --noinform --non-interactive --script scripts/run-compile-check.lisp
          '';
          installPhase = ''
            mkdir -p "$out/share/common-lisp/source/cl-cc-javascript"
            cp -R . "$out/share/common-lisp/source/cl-cc-javascript"
          '';
          meta = {
            description = "cl-cc JavaScript frontend: lexer, parser, and runtime helpers";
            homepage = "https://github.com/nerima-lisp/cl-cc-javascript";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.unix;
          };
        };
      });

      checks = forAllSystems (pkgs: {
        compile = self.packages.${pkgs.stdenv.hostPlatform.system}.default;

        test = pkgs.stdenvNoCC.mkDerivation {
          name = "cl-cc-javascript-test";
          src = self;
          nativeBuildInputs = [
            pkgs.sbcl
            pkgs.perl
          ];
          buildPhase = ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            ${exportDependencyEnv}
            chmod +x scripts/with-timeout.pl
            scripts/with-timeout.pl 900 sbcl --noinform --non-interactive --script scripts/run-tests.lisp
          '';
          installPhase = "touch $out";
        };
      });
    };
}
