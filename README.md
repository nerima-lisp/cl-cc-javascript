# cl-cc-javascript

[![CI](https://github.com/nerima-lisp/cl-cc-javascript/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/cl-cc-javascript/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-0a7a5a)](https://nerima-lisp.github.io/cl-cc-javascript/)

The JavaScript frontend for [cl-cc](https://github.com/nerima-lisp/cl-cc): a lexer, a
parser, and the runtime helpers that let cl-cc compile and execute JavaScript on its own
VM. It targets SBCL. This is a plugin frontend, not a standalone JavaScript engine — it
emits cl-cc AST nodes directly, so if you want an ESTree-shaped tree this is the wrong
library.

Full documentation is published at <https://nerima-lisp.github.io/cl-cc-javascript/>.
The source for that site lives in [docs/src/](docs/src/).

## Quick Start

```lisp
(asdf:load-system "cl-cc-javascript")

(let* ((result  (cl-cc:compile-string "console.log(1 + 1);"
                                      :target :vm :language :javascript))
       (program (cl-cc/compile:compilation-result-program result)))
  (cl-cc/vm:run-compiled program))
;; prints: 2
```

Loading the system is all the setup there is: its last two components self-register with
`cl-cc/bootstrap`, which is what makes `:language :javascript` available.

## Install

```nix
# flake.nix
inputs.cl-cc-javascript = {
  url = "github:nerima-lisp/cl-cc-javascript";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Consumers inside this org normally pin a release tag rather than follow the default
branch. cl-cc-javascript has no tag yet, so there is nothing to pin to; pin one as soon
as the first tag exists.

## Documentation

- [Quick Start](https://nerima-lisp.github.io/cl-cc-javascript/quick-start/)
- [Core Concepts](https://nerima-lisp.github.io/cl-cc-javascript/core-concepts/) — the
  value model, and why `nil` is `false` rather than `null`
- [API Reference](https://nerima-lisp.github.io/cl-cc-javascript/api-reference/)
- [Compatibility](https://nerima-lisp.github.io/cl-cc-javascript/compatibility/) — the
  deliberate simplifications, including the synchronous promise model

## Development

```sh
nix develop          # SBCL with every CL_CC_JAVASCRIPT_*_ROOT already set
nix run .#test       # run the test suite
nix flake check      # compile + tests + formatting + docs, the same gate CI uses
nix fmt              # format Nix sources (treefmt)
```

Tests live in `t/` and run under [cl-weave](https://github.com/nerima-lisp/cl-weave),
the org's test framework. Outside Nix, the sibling checkouts are located by the
`CL_CC_JAVASCRIPT_*_ROOT` environment variables, falling back to sibling directories
next to this repository — see `scripts/dependency-roots.lisp`.

## Contributing

See the org-wide [CONTRIBUTING](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
guide and the [package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

See [SUPPORT](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
