# Development

## The gate

```sh
nix flake check --print-build-logs
```

This is what CI runs, and it is the whole gate. It evaluates five checks in parallel,
each as its own derivation:

| Check | What it does |
|---|---|
| `checks.compile` | compiles and loads the production system (`scripts/run-compile-check.lisp`) |
| `checks.default` | runs the test suite (`run-tests.lisp`) |
| `checks.formatting` | fails if any Nix file is unformatted |
| `checks.docs` | builds this site with `mkdocs --strict` |
| `checks.coverage` | asserts `packages.coverage-report` built and produced a report — not a percentage gate yet, see [Coverage](#coverage) |

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

## Refactoring with paredit-cli

[paredit-cli](https://github.com/nerima-lisp/paredit-cli) — the org's structure-editing
CLI for safe S-expression refactoring — is on `PATH` inside `nix develop` as `paredit`.
Prefer it over hand-editing for anything structural:

```sh
paredit inspect check -f src/runtime-object.lisp     # balanced-S-expression sanity check
paredit inspect lint src/*.lisp                      # every within-file logic-bug rule at once
paredit inspect unused-definitions src/*.lisp         # definitions with no external reference
paredit inspect clone-classes src/*.lisp              # near-duplicate forms, ranked by lines an extraction would save
```

Always pass the complete file set a rule needs to see cross-file usage — `unused-definitions`
and `clone-classes` scoped to a narrow subset will misreport symbols that are only "unused"
because the files that call them were left out. Set `--timeout-ms` on any scan over the
whole tree, consistent with this project's "every command execution needs a timeout" rule.

## Resolving the source-tree dependencies

Unlike the dependency-free leaf packages in this org, cl-cc-javascript depends on
systems that still live inside the cl-cc checkout (`cl-cc-ast`, `cl-cc-bootstrap`,
`cl-cc-parse`, `cl-cc-vm`), everything cl-cc's umbrella system pulls in transitively, and
a handful of `nerima-lisp` sibling packages this frontend depends on directly
(`cl-date-kit` for Temporal, `cl-json-kit` for JSON, `cl-concurrent-kit` for the
generator runtime — see [Architecture](../reference/architecture.md)).
`scripts/dependency-roots.lisp` locates each of them, in this order:

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
| `CL_CC_JAVASCRIPT_CL_DATE_KIT_ROOT` | `cl-date-kit` |
| `CL_CC_JAVASCRIPT_CL_JSON_KIT_ROOT` | `cl-json-kit` |
| `CL_CC_JAVASCRIPT_CL_CONCURRENT_KIT_ROOT` | `cl-concurrent-kit` |

`nix develop` sets all twelve for you from the pinned flake inputs, so inside the dev
shell no further configuration is needed.

## Running tests without Nix

The suite needs the sibling checkouts. Inside `nix develop` they are already pointed at
the pinned flake inputs; outside it, `scripts/dependency-roots.lisp` falls back to
sibling directories next to this repository.

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
nix build .#coverage-report                                  # preferred: sandboxed, no sibling-checkout setup needed
scripts/with-timeout.pl 900 sbcl --script scripts/run-coverage.lisp   # outside Nix
```

Both write an HTML report — the Nix build's is `result/`; the bare-SBCL script's is
`coverage-report/` at the repository root, which is gitignored. Coverage instrumentation
has to be declaimed before the instrumented systems are compiled, so
`scripts/run-coverage.lisp` force-reloads the test system after enabling `sb-cover`.
`checks.coverage` only asserts the report was produced; it does not yet gate on a
percentage (no `check-coverage.pl`-equivalent exists in this repository).

## Layout

```
cl-cc-javascript.asd   both systems: cl-cc-javascript and cl-cc-javascript/test
run-tests.lisp         test entry point
src/                   flat; every defpackage in src/package.lisp
t/                     tests, named t/<source>-test.lisp
scripts/               dependency resolution, compile check, coverage, timeout
docs/                  mkdocs.yml + src/
flake.nix flake.lock
```

Tests run under [cl-weave](https://github.com/nerima-lisp/cl-weave), the org's test
framework. Do not introduce FiveAM, parachute, rove or prove.

A test file is named after the source file it covers: `src/lexer.lisp` is tested by
`t/lexer-test.lisp`. Where one source file (or one broad area, like statement parsing)
has several concerns, the concern goes in the middle — `t/parser-decl-test.lisp`,
`t/parser-stmt-control-flow-test.lisp`, `t/parser-stmt-module-test.lisp` and
`t/parser-stmt-misc-test.lisp` all cover parser statement handling. The
`t/e2e-*-test.lisp` files have no single source counterpart: they compile and run whole
JavaScript programs through the frontend and the VM.

## Adding a builtin

1. Implement `%js-<name>` in the right `src/runtime-*.lisp` file, or add a new one
   grouped by builtin family.
2. Add it to the `:components` list in `cl-cc-javascript.asd`, before
   `runtime-bridge-provider`.
3. Export it from `src/package.lisp`, under the group heading it belongs to — those
   headings are the H2 sections of [the API reference](../reference/api.md).
4. Register it in the relevant dispatch table (`*js-builtin-map*`, or a
   `*js-*-method-table*`) so property access finds it.
5. Add tests to the `t/runtime-*-test.lisp` file matching the source file you
   touched.
6. Document it in `docs/src/api-reference.md`.

Steps 3 and 6 are not optional: the API reference is required to cover every exported
symbol.

## Removing a builtin (or any exported symbol)

`docs/src/api-reference.md` is hand-maintained, not generated from `src/package.lisp`'s
export list — deleting a `defun`/`defparameter` and its export does not remove its doc
entry for free. When deleting dead code, grep `docs/` for the exact symbol name and
remove its entry (and any cross-reference note pointing at it from a sibling entry)
before considering the deletion done.

## Conventions

Commit messages follow
[Conventional Commits](https://github.com/nerima-lisp/.github/blob/main/CODING_STANDARD.md).
Work on short-lived topic branches off `main`.
