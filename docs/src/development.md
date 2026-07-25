# Development

## The gate

```sh
nix flake check --print-build-logs
```

This is what CI runs, and it is the whole gate. It evaluates four checks in parallel,
each as its own derivation:

| Check | What it does |
|---|---|
| `checks.compile` | compiles and loads the production system (`scripts/run-compile-check.lisp`) |
| `checks.default` | runs the test suite (`run-tests.lisp`) |
| `checks.formatting` | fails if any Nix file is unformatted |
| `checks.docs` | builds this site with `mkdocs --strict` |

Granularity lives here rather than in extra GitHub Actions jobs, because `nix flake
check` already parallelises and caches. Add a check to `flake.nix`; do not add a job to
`ci.yml`.

## Individual commands

```sh
nix develop          # SBCL with every CL_CC_JAVASCRIPT_*_ROOT already exported
nix run .#test       # just the test suite
nix build .#docs     # just this site
nix fmt              # format Nix sources (treefmt / nixfmt)
```

## Running tests without Nix

The suite needs the sibling checkouts. Inside `nix develop` they are already pointed at
the pinned flake inputs; outside it, `scripts/dependency-roots.lisp` falls back to
sibling directories next to this repository. See
[Installation](installation.md#resolving-the-source-tree-dependencies).

Always run under a timeout — a hung compile or test should never occupy a worker
indefinitely:

```sh
scripts/with-timeout.pl 600 sbcl --script scripts/run-compile-check.lisp
scripts/with-timeout.pl 900 sbcl --script run-tests.lisp
```

`run-tests.lisp` lives at the repository root (the org-wide convention for the test
entry point) and loads `scripts/dependency-roots.lisp` relative to it. It fails on a
load error, on a test failure, and also when zero tests were collected — the last of
those catches a suite that silently stopped being loaded at all.

## Coverage

```sh
scripts/with-timeout.pl 900 sbcl --script scripts/run-coverage.lisp
```

Writes an HTML report to `coverage-report/`, which is gitignored. Coverage
instrumentation has to be declaimed before the instrumented systems are compiled, so the
script force-reloads the test system after enabling `sb-cover`.

## Layout

```
cl-cc-javascript.asd   both systems: cl-cc-javascript and cl-cc-javascript/test
run-tests.lisp         test entry point
src/                   flat; every defpackage in src/package.lisp
t/                     tests, one file per concern
scripts/               dependency resolution, compile check, coverage, timeout
docs/                  mkdocs.yml + src/
flake.nix flake.lock
```

Tests run under [cl-weave](https://github.com/nerima-lisp/cl-weave), the org's test
framework. Do not introduce FiveAM, parachute, rove or prove.

## Adding a builtin

1. Implement `%js-<name>` in the right `src/runtime-*.lisp` file, or add a new one
   grouped by builtin family.
2. Add it to the `:components` list in `cl-cc-javascript.asd`, before
   `runtime-bridge-provider`.
3. Export it from `src/package.lisp`, under the group heading it belongs to — those
   headings are the H2 sections of [the API reference](api-reference.md).
4. Register it in the relevant dispatch table (`*js-builtin-map*`, or a
   `*js-*-method-table*`) so property access finds it.
5. Add tests to the matching `t/js-runtime-*-tests.lisp`.
6. Document it in `docs/src/api-reference.md`.

Steps 3 and 6 are not optional: the API reference is required to cover every exported
symbol.

## Conventions

Commit messages follow
[Conventional Commits](https://github.com/nerima-lisp/.github/blob/main/CODING_STANDARD.md).
Work on short-lived topic branches off `main`.
