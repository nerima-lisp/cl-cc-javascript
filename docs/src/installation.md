# Installation

cl-cc-javascript is consumed as a Nix flake input and loaded through ASDF.

## Add the flake input

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cl-cc-javascript = {
      url = "github:nerima-lisp/cl-cc-javascript";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

!!! note "This input is not yet pinned to a tag"

    Consumers inside this org normally pin a release tag
    (`github:nerima-lisp/cl-cc-javascript/v0.1.0`) rather than follow the default
    branch, because an upstream push to `main` otherwise breaks downstream CI without
    warning. cl-cc-javascript has no release tag yet, so there is nothing to pin to.
    Pin one as soon as the first tag exists.

## Add the system dependency

```lisp
;; your-system.asd
:depends-on ("cl-cc" "cl-cc-javascript")
```

## Load it

```lisp
(asdf:load-system "cl-cc-javascript")
```

Loading the system is all that is required to register the JavaScript frontend: the last
two components (`runtime-bridge-provider` and `vm-integration`) self-register with
`cl-cc/bootstrap`, so `cl-cc:compile-string` accepts `:language :javascript` from then
on. There is no separate initialisation call.

## Resolving the source-tree dependencies

Unlike the dependency-free leaf packages in this org, cl-cc-javascript depends on
systems that still live inside the cl-cc checkout (`cl-cc-ast`, `cl-cc-bootstrap`,
`cl-cc-parse`, `cl-cc-vm`), plus everything cl-cc's umbrella system pulls in
transitively. `scripts/dependency-roots.lisp` locates each of them, in this order:

1. an explicit environment variable, one per dependency;
2. otherwise a sibling checkout next to this repository, which is the layout `ghq`
   already produces.

| Environment variable | Dependency |
|---|---|
| `CL_CC_JAVASCRIPT_CL_CC_ROOT` | `cl-cc` |
| `CL_CC_JAVASCRIPT_CL_WEAVE_ROOT` | `cl-weave` |
| `CL_CC_JAVASCRIPT_CL_PROLOG_ROOT` | `cl-prolog` |
| `CL_CC_JAVASCRIPT_CL_PARSER_KIT_ROOT` | `cl-parser-kit` |
| `CL_CC_JAVASCRIPT_CL_DATAFLOW_ROOT` | `cl-dataflow` |
| `CL_CC_JAVASCRIPT_CL_BOUNDARY_KIT_ROOT` | `cl-boundary-kit` |
| `CL_CC_JAVASCRIPT_CL_CLI_ROOT` | `cl-cli` |
| `CL_CC_JAVASCRIPT_CL_TTY_KIT_ROOT` | `cl-tty-kit` |
| `CL_CC_JAVASCRIPT_CL_LOG_KIT_ROOT` | `cl-log-kit` |

`nix develop` sets all nine for you from the pinned flake inputs, so inside the dev
shell no further configuration is needed.

## Verify

```sh
nix flake check --print-build-logs
```

This runs the compile gate, the test suite, the Nix formatting gate and the docs build.
See [Development](development.md).
