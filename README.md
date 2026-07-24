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
and cl-cc-vm (the last three still internal to cl-cc), so standalone Nix CI is
pending those systems being consumable as flake inputs (or cl-cc consumed as a
flake input). The .asd loads correctly against a cl-cc checkout.

## Usage

```lisp
(asdf:load-system :cl-cc-javascript)
```

## License

MIT — see [LICENSE](LICENSE).
