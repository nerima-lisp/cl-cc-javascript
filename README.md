# cl-cc-javascript

JavaScript frontend/backend for the
[cl-cc](https://github.com/nerima-lisp/cl-cc) Common Lisp compiler.

This is a **plugin system** extracted from the cl-cc monorepo. It defines the
`:cl-cc-javascript` system: the JavaScript lexer, parser, and runtime helpers
(the `%JS-*` runtime bridge, method resolver, and VM integration) that let cl-cc
consume and execute JavaScript source.

## Status

Source extracted from the cl-cc monorepo. Unlike the dependency-free leaf repos
(cl-cc-ast), cl-cc-javascript depends on cl-cc-ast, cl-cc-bootstrap, cl-cc-parse,
and cl-cc-vm (the last three still internal to cl-cc), plus everything cl-cc's
own umbrella system pulls in transitively. `flake.nix` takes cl-cc and every
transitive nerima-lisp dependency as plain-source-tree inputs (the same
pattern cl-cc itself uses for cl-weave/cl-prolog/etc.), so `nix flake check`
builds and tests this repo standalone — no other checkout needed. The test
suite depends on `:cl-weave` directly (no `:cl-cc-testing-framework` adapter).

## Usage

```lisp
(asdf:load-system :cl-cc-javascript)
```

## Testing

```sh
nix flake check
```

Or without Nix, against sibling checkouts of cl-cc/cl-weave/etc. beside this
repo (or pointed at via the `CL_CC_JAVASCRIPT_*_ROOT` env vars — see
`scripts/dependency-roots.lisp`). `nix flake check` always runs these under
`scripts/with-timeout.pl`; do the same by hand outside Nix (a hung compile
or test run should never block a CI worker indefinitely):

```sh
scripts/with-timeout.pl 600 sbcl --script scripts/run-compile-check.lisp
scripts/with-timeout.pl 900 sbcl --script scripts/run-tests.lisp
```

## License

MIT — see [LICENSE](LICENSE).
