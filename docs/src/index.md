# cl-cc-javascript

The JavaScript frontend for [cl-cc](https://github.com/nerima-lisp/cl-cc): a lexer, a
parser, and the runtime helpers that let cl-cc compile and execute JavaScript source on
its own VM. It targets SBCL.

```lisp
(cl-cc:compile-string "console.log(1 + 1);" :target :vm :language :javascript)
```

This package is a *plugin frontend*, not a standalone JavaScript engine. It produces
cl-cc AST nodes and registers a runtime bridge with `cl-cc/bootstrap`; execution, code
generation and optimisation belong to cl-cc itself.

## Where to go next

- [Installation](installation.md) — add the flake input and the `:depends-on` entry.
- [Quick Start](quick-start.md) — tokenize, parse, and run a program end to end.
- [Core Concepts](core-concepts.md) — the token/AST/runtime-bridge vocabulary, and the
  `undefined` versus `null` distinction that trips up every first reader.
- [API Reference](api-reference.md) — all 320 exported symbols.
- [Compatibility](compatibility.md) — which ECMAScript editions are covered, and what is
  deliberately not implemented.
- [Architecture](architecture.md) — how `src/` is split, and why.

## Project

Contribution, security and support policy are org-wide and live in
[nerima-lisp/.github](https://github.com/nerima-lisp/.github):
[CONTRIBUTING](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md),
[SECURITY](https://github.com/nerima-lisp/.github/blob/main/SECURITY.md),
[SUPPORT](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).
