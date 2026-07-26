# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `.github/workflows/`: `ci.yml`, `docs.yml`, `release.yml` and `flake-update.yml`, plus
  the shared `nix-setup` composite action. This repository previously had no CI at all.
- `flake.lock`. The flake declared ten inputs and locked none of them, so no two builds
  resolved to the same dependency tree.
- `CHANGELOG.md` and the `docs/` site (MkDocs Material), neither of which existed.
- `checks.formatting` (treefmt/nixfmt) and `checks.docs` (`mkdocs --strict`) alongside
  the existing compile and test checks, and an `apps.test` entry point.

### Changed

- Test files are named `t/<source>-test.lisp` after the source file they cover,
  per `CODING_STANDARD.md`. The redundant `js-` prefix is gone (no source file
  carries it) and the plural `-tests` is now singular, so `js-lexer-tests.lisp`
  is `lexer-test.lisp`. Three names that did not identify a source file were
  changed to ones that do. No test content changed.
- `src/package.lisp` no longer `:use`s `cl-cc/ast`, `cl-cc/bootstrap` or
  `cl-cc/parse`; the 55 symbols actually borrowed are now listed in
  `:import-from`. The exported symbol set is unchanged.
- The test system moved from a separate `cl-cc-javascript-test.asd` into
  `cl-cc-javascript.asd` as `cl-cc-javascript/test`, and both `defsystem` names are now
  strings rather than keywords.
- Test sources moved from `tests/` to `t/`, and the test entry point from
  `scripts/run-tests.lisp` to `run-tests.lisp` at the repository root.
- `flake.nix` now derives the package version from the `:version` form in
  `cl-cc-javascript.asd` instead of hardcoding it, tracks `nixos-unstable` rather than
  `nixpkgs-unstable`, and pins every sibling input to a release tag except `cl-cc`.
- `systems` narrowed to `x86_64-linux` and `aarch64-darwin`. `aarch64-linux` and
  `x86_64-darwin` were declared but never built or tested by anything.
- `.asd` metadata completed to the eight required fields, with `:author` and
  `:maintainer` set to the canonical `takeokunn <bararararatty@gmail.com>`.

## [0.1.0] - 2026-07-26

### Added

- Initial extraction of the JavaScript frontend from the cl-cc monorepo: the lexer,
  parser, and `%js-*` runtime helpers that let cl-cc compile and execute JavaScript.
- `flake.nix` and the `scripts/` entry points, making the repository buildable and
  testable standalone against sibling checkouts.

### Changed

- `runtime-async.lisp` split into `runtime-console.lisp`, `runtime-generator.lisp` and
  `runtime-promise.lisp`.
- The test suite is discovered by [cl-weave](https://github.com/nerima-lisp/cl-weave):
  `tests/js-suite.lisp` gave way to a `package.lisp` that cl-weave picks up.
