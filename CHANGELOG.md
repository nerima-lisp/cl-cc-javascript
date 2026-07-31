# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `paredit-cli` (the org's structure-editing CLI for S-expression refactoring) wired into
  `flake.nix` as a real flake input — pinned to `v1.3.0`, `inputs.nixpkgs.follows =
  "nixpkgs"` — and exposed as `paredit` in `devShells.default`. It was previously absent
  from this repository entirely despite being an org tool this project's own refactor
  conventions call for using; every attempt to run it in a plain `nix develop` shell
  failed with "command not found" until now. Unlike the CL sibling dependencies above,
  it is a real flake input (not `flake = false`) because what's needed is its built
  binary (a Rust/crane `packages.${system}.default`), not a source tree for ASDF to
  load. Documented in `docs/src/development.md`'s new "Refactoring with paredit-cli"
  section.

### Fixed

- `Object.freeze`/`Object.seal`/`Object.preventExtensions` (and their `is*` queries) on
  JS arrays: previously complete no-ops, since `%js-object-frozen-p`/`-sealed-p`/
  `-extensible-p` and their setters hard-gated on `%js-ht-p` and a JS array is a plain
  CL vector (`%js-vec-p`), not a hash-table — `Object.freeze(arr)` followed by
  `arr.push(1)`/`arr[0] = 99` silently succeeded either way, and `Object.isFrozen(arr)`
  always returned `false`. Added a new `*js-array-flags*` side table
  (`src/runtime-property.lisp`) — deliberately separate from the pre-existing
  `*js-array-extra-properties*` table so an internal `__frozen__`/`__sealed__`/
  `__extensible__` flag can never leak into `Object.keys`/`for...in` enumeration — and
  widened `%js-object-internal-flag` and friends (`src/runtime-object.lisp`) to read/write
  it for `%js-vec-p` values. `%js-set-prop`'s array branch, and the 9 mutating array
  methods (`push`/`pop`/`shift`/`unshift`, `splice`/`reverse`/`sort`/`fill`/
  `copyWithin`), now enforce the real ECMAScript distinction: frozen blocks *all*
  mutation; sealed/non-extensible blocks only *adding or removing* indices/properties,
  still permitting an existing index's value to be overwritten (matching this
  codebase's existing silent-no-op convention for blocked writes on plain objects,
  rather than throwing).
- `#field in obj` (the ES2022 ergonomic private-field brand check) previously lowered
  to a plain variable lookup on a nonexistent variable literally named `#field` —
  `js-parse-primary`'s `:T-PRIVATE-IDENT` case builds a synthetic `(ast-var #field)`
  for a standalone private identifier, and the generic `"in"` operator dispatch had no
  special case for it, so it tried to evaluate `#field` as a real variable and failed
  with an undefined-variable error instead of calling the already-correct, previously
  unwired `%js-has-private-field`. Fixed in `%js-lower-binary` (`src/parser-expr.lisp`)
  with a new `%js-private-field-in-check-name` helper that recognizes this synthetic
  AST shape and lowers to `%js-has-private-field` directly, checked before every other
  `"in"` handling.
- `for await (x of asyncIter)` silently discarded the `await`, iterating identically to
  a plain `for...of` — each yielded item was never unwrapped through `%js-await`, so an
  async iterator yielding promises handed the raw (unawaited) `Promise` object to the
  loop body instead of its resolved value. `%js-lower-for-of-in`/`%js-parse-for-of-stmt`/
  `%js-parse-for-in-of-stmt` (`src/parser-stmt-control.lisp`) now thread an `await-p`
  flag through to wrap each element access in `%js-await`. The dead, wrong-shaped
  `%js-for-await-of` helper (`src/runtime-promise.lisp`) — never callable from this
  AST-lowering architecture in the first place — was deleted rather than wired up.

### Removed

- Four dead duplicate implementations, found via a `paredit inspect unused-definitions`
  sweep (see the paredit-cli wiring above) and confirmed by tracing that each JS feature
  is actually implemented and tested through a completely different code path:
  `%js-nullish-coalesce` (`??` is real-lowered via `%js-lower-nullish-coalesce`, already
  covered by `t/e2e-advanced-test.lisp`'s `js-e2e-optional-chaining-execution`),
  `%js-void` (`void` lowers inline to an `ast-progn` in `parser-expr-unary.lisp`, already
  covered by e2e tests), and thin dead wrappers `%js-typed-array-p`/`%js-regexp-p` around
  the real, pervasively-used unprefixed struct predicates `js-typed-array-p`/`js-regexp-p`.
  `%js-promise-finally` was the same pattern (`.finally()` is really implemented by a
  dispatch-table lambda in `runtime-method-resolver-dispatch.lisp`) — but tracing it
  surfaced that the real, active `.finally()` implementation had **zero** end-to-end test
  coverage (only the dead standalone function was unit-tested directly); added
  `js-e2e-promise-finally` to `t/e2e-modern-test.lisp` before deleting it, so removing the
  dead code does not regress coverage of the real feature.

## [0.2.0] - 2026-07-31

### Added

- `.github/workflows/`: `ci.yml`, `docs.yml`, `release.yml` and `flake-update.yml`, plus
  the shared `nix-setup` composite action. This repository previously had no CI at all.
- `flake.lock`. The flake declared ten inputs and locked none of them, so no two builds
  resolved to the same dependency tree.
- `CHANGELOG.md` and the `docs/` site (MkDocs Material), neither of which existed.
- `checks.formatting` (treefmt/nixfmt) and `checks.docs` (`mkdocs --strict`) alongside
  the existing compile and test checks, and an `apps.test` entry point.
- `packages.coverage-report` and `checks.coverage`: `scripts/run-coverage.lisp`
  (SB-COVER + cl-weave) existed but was never wired into `flake.nix`, so no CI run or
  local `nix build` ever produced a coverage report. `checks.coverage` asserts the
  report exists; it does not gate on a percentage yet (no `check-coverage.pl`-equivalent
  exists in this repository, unlike some siblings).
- A `cl-weave` custom matcher, `:to-have-set-values`, replacing a helper function
  (`%jr-assert-set-has-all`) that issued multiple disconnected `expect` calls internally
  with one properly-reported assertion.
- A second `cl-weave` custom matcher, `:to-be-js-undefined` (`t/runtime-core-test.lisp`,
  loaded first so every `runtime-*-test.lisp` file can use it), replacing the verbose
  `(expect ... :to-be cl-cc/javascript::+js-undefined+)` spelling repeated at 43 call
  sites across 13 test files with `(expect ... :to-be-js-undefined)`. Defined via the
  public `defmatcher` macro (not cl-weave's internal, unexported `defpredicate-matcher`
  that its own built-in zero-argument matchers like `:to-be-truthy` use) — same pattern
  as the pre-existing `:to-have-set-values` matcher above. No behavior change: `eq`
  against `+js-undefined+` is exactly what the old `:to-be` spelling already checked
  (`:to-be` itself is `eql`, and this runtime's `+js-undefined+` is a single interned
  sentinel, so `eq`/`eql` agree here).
- Two new `cl-weave` `it-property` tests, extending this codebase's very sparse use of
  property-based testing (previously exactly one `it-property`, for `btoa`/`atob`) to
  two more genuine round-trip functions: `js-rt-encode-decode-uri-component-roundtrip-
  property` (`decodeURIComponent(encodeURIComponent(s)) = s`,
  `t/runtime-collections-weak-test.lisp`) and `js-rt-text-encoder-decoder-roundtrip-
  property` (`TextDecoder().decode(TextEncoder().encode(s)) = s`,
  `t/runtime-builtins-platform-test.lisp`, exercising 1/2/3-byte UTF-8 sequences via a
  mixed ASCII/é/€ generator alphabet). Both complement pre-existing fixed-example tests
  covering the same functions rather than replacing them — the generated cases cover
  many more character-run orderings and lengths than a handful of hand-picked strings
  can.
- `cl-concurrent-kit` (pinned `v0.1.0`), a `nerima-lisp` dependency-free SBCL concurrency
  toolkit, adopted directly — not through an adapter — for the generator runtime's
  suspend/resume coroutine hand-off (`src/runtime-generator.lisp`). `%js-generator-
  channel` previously hand-rolled a mutex, condition variable, and an explicit `:body`/
  `:driver` turn flag to enforce that exactly one of the two threads runs at a time.
  Replaced with a pair of `cl-concurrent-kit:channel`s (`make-channel`'s default,
  unbuffered/rendezvous mode): an unbuffered channel's `send` already blocks until the
  matching `recv` takes the value, so each `send`/`recv` pair below is itself the
  synchronization point — no separate turn-tracking is needed at all. Wired through the
  standard four points other `nerima-lisp` source-tree dependencies in this repo use:
  `flake.nix` (input pinned to the tag, `CL_CC_JAVASCRIPT_CL_CONCURRENT_KIT_ROOT` env
  var), `cl-cc-javascript.asd` (`:depends-on`), `scripts/dependency-roots.lisp`
  (env-var → sibling-dir mapping), `src/package.lisp` (`:import-from`). This was
  specifically evaluated on its own merits (not as a side effect of another dependency
  bump) per a standing note in `flake.nix`'s `cl-log-kit` comment flagging it as worth
  revisiting. No observable behavior change — verified via two consecutive `nix build
  .#checks.aarch64-darwin.default` runs (concurrency-sensitive code warrants more than
  one pass): 1319 passed both times, 0 failed.
- `docs/src/architecture.md`/`docs/src/development.md` corrected to match this session's
  changes: stale file/line counts (`t/` file count, `package.lisp`'s line count), a gate
  table missing the new `checks.coverage`, the coverage section not mentioning the
  `nix build .#coverage-report` path, and a reference to `t/parser-stmt-test.lisp`,
  which no longer exists after this session's test-file split.
- `%jr-assert-string-props` (a test helper checking several object properties in one
  call, e.g. every URL component) now wraps its checks in `cl-weave`'s
  `with-soft-assertions`, so a mismatch on one property no longer hides mismatches on
  the others — previously the first failing `expect` aborted the whole helper.
- [`cl-date-kit`](https://github.com/nerima-lisp/cl-date-kit) (pinned `v0.2.0`), adopted
  directly (no adapter) for real IANA time zone support in the Temporal runtime, which was
  previously silently hardcoded to `"UTC"` everywhere — an undisclosed gap this now both
  fixes and documents honestly. `Temporal.Now.timeZoneId` reports the host's actual IANA
  zone (via `TZ` or `/etc/localtime`) instead of a literal `"UTC"`, and
  `Temporal.Now.zonedDateTimeISO`, `Temporal.Instant.prototype.toZonedDateTimeISO`, and the
  `Temporal.ZonedDateTime` epoch-based constructor now project an absolute instant into any
  IANA zone `cl-date-kit`'s tzdata recognizes — an unambiguous instant → local-zone
  projection, not the reverse (constructing from local wall-clock fields in a non-UTC zone,
  which needs a DST gap/overlap disambiguation policy, is explicitly out of scope and
  documented as such in `docs/src/compatibility.md`). `flake.nix`'s `checks.default`,
  `apps.test`, and `devShells.default` now point `TZDIR` at nixpkgs' `tzdata` package so
  this is exercised for real inside the Nix sandbox, not silently skipped.
- `Date.prototype.getTimezoneOffset()` now uses the same `cl-date-kit` host-zone
  discovery and instant → local-zone projection as Temporal (above), reporting genuine
  minutes-west-of-UTC for the host's discovered IANA zone instead of a hardcoded `0`.
  Unlike the Temporal gap, this one already had an honest docstring ("UTC assumed"), so
  this is a feature addition built on newly-adopted infrastructure, not a disclosure fix.
  Falls back to `0` under the same conditions Temporal's zone functions do (unresolvable
  host zone, no readable tzdata).
- [`cl-json-kit`](https://github.com/nerima-lisp/cl-json-kit) (pinned `v1.0.1`), adopted
  directly (no adapter, through its own `:null-value`/`:false-value`/`:true-value`/
  `:number-encoder` parse and write hooks) to replace `runtime-json.lisp`'s ~100-line
  hand-rolled JSON parser/writer with an RFC-8259-conformant one (95/95 JSONTestSuite
  must-accept, 188/188 must-reject, per its own README) — comparing the two surfaced
  three real, previously undisclosed `JSON.parse`/`JSON.stringify` bugs, all now fixed:
  1. **`\uXXXX` escapes were never decoded during `JSON.parse`.** The hand-rolled string
     scanner's escape `case` had no `\u` clause at all, so `JSON.parse("\"\\u0041\"")`
     produced the six literal characters `u0041` prefixed by nothing sensible, not `"A"`.
  2. **`JSON.parse` on malformed input silently returned `undefined`** instead of
     throwing — real `JSON.parse` throws a `SyntaxError`. `%js-json-parse` now signals a
     genuine `*js-syntax-error-class*` instance via `%js-throw`, JS-catchable like any
     other thrown error.
  3. **`JSON.stringify` never omitted `undefined`-valued object properties.** The
     omission check (`unless (string= vs "undefined") ...`) compared against the
     stringified text of the value, but `undefined` itself always stringified to the
     text `"null"` first — so the comparison could never be true, and
     `JSON.stringify({a: undefined})` produced `{"a":null}` instead of `{}`. Fixed with
     genuinely context-aware handling (`%js-json-stringify-normalize`): an
     `undefined`/function/Symbol value is omitted from an object property, becomes
     `null` in an array, and makes a top-level `JSON.stringify` call return `undefined`
     itself (not a string) — three different real-JS behaviors the old code conflated
     into one wrong one.
  `JSON.rawJSON`'s raw-fragment splicing (json-kit has no native "write this text
  verbatim" leaf type) is done via a marker-substitution pass — normalize each raw
  wrapper to a unique `gensym`-named string, let `json-kit:stringify` write it as an
  ordinary JSON string, then replace that string's own quoted form in the output text
  with the real raw text. Previously implemented but never actually tested end-to-end;
  now covered by the existing `js-rt-json-raw-json` test, unchanged and still green.
  Number formatting (bare digits for a whole number, `~F` otherwise) is preserved
  exactly via `:number-encoder` — `json-kit`'s own default keeps a float's decimal
  point unconditionally (for CL integer/float round-trip fidelity, a distinction JS
  numbers don't make), which would have regressed every whole-number `JSON.stringify`
  call from `"42"` to `"42.0"` without this hook. Verified via `nix build
  .#checks.aarch64-darwin.default`: 1333 → 1336 passed (one case removed — subsumed by
  a dedicated new test — one existing test's assertion corrected, four new), 0 failed —
  including the E2E tests that exercise `JSON.parse`/`stringify`/`rawJSON` through
  actually-compiled JS source.
- `scripts/coverage-summary.lisp`: parses the LCOV report (see below) and prints an
  aggregate line-coverage percentage for this repository's own `src/*.lisp` files —
  filtered by absolute path, unlike the HTML report's basename-keyed per-file links,
  which collide across sibling packages that happen to share a generic filename.
- A `cl-weave` `it-property` test (`js-rt-btoa-atob-roundtrip-property`) asserting
  `atob(btoa(s)) = s` for generated binary strings, alongside the existing single-example
  test — covers every base64 padding remainder (string lengths not divisible by 3) across
  many generated inputs instead of one hand-picked one.
- A `cl-weave` `it-fuzz` test (`js-rt-regex-fuzz-compile-and-exec-never-crashes`,
  `t/runtime-regex-test.lisp`) generating 300 random (pattern, subject) pairs from an
  alphabet weighted toward regex metacharacters (groups, classes, quantifiers, anchors,
  escapes) and asserting compiling and testing each pair never signals an unhandled Lisp
  error. `%js-make-regex` already catches a *compile-time* error (an invalid pattern
  just becomes an uncompiled `RegExp`, matching nothing); this fuzzes the previously-
  unverified other failure mode — a pattern that compiles "successfully" but whose
  matcher closure crashes at *match* time against adversarial input (an out-of-bounds
  `aref`, for instance) — across the regex engine as extended this session (capturing
  groups, `{n,m}` quantifiers). Found no crashes across 300 trials; `it-fuzz` was
  previously unused in this test suite despite fitting this exact "does this ever throw
  something it shouldn't" question better than a fixed set of hand-picked inputs could.
- Regex capturing groups: `(expr)` and `(?<name>expr)` now record their matched span
  in a `groups` vector threaded through the whole matcher (`src/runtime-regex.lisp`'s
  `%js-regex-capturing-group-matcher`), numbered by opening-parenthesis order, and
  `%js-regex-exec` (`src/runtime-regex-api.lisp`) surfaces them as `"1"`..`"N"` on the
  match object plus a null-prototype `groups` object for named captures —
  `match(/(\d+)-(\d+)/)[1]` no longer returns `undefined`. `regex-replace-placeholders`
  expands `$1`-`$99`, `$<name>`, and `$$` alongside the pre-existing `$&`. Previously
  the compiled matcher was always called with `groups` bound to `nil` and this data
  simply didn't exist anywhere in the engine.
- Regex bounded-repetition quantifiers `{n}`/`{n,}`/`{n,m}` (and their lazy `?` suffix)
  via `%js-regex-parse-brace-quantifier`/`%js-regex-bounded-repeat-matcher`
  (`src/runtime-regex.lisp`). `{...}` that isn't a well-formed quantifier (no digits, a
  missing minimum before the comma, an unclosed brace) falls back to matching its
  characters literally — the same Annex-B-style leniency real JS engines apply outside
  Unicode mode — rather than erroring. Previously `*`/`+`/`?` were the only recognized
  quantifiers and `a{3}` matched the four literal characters `a`, `{`, `3`, `}`. See
  `docs/src/compatibility.md`'s regex section (updated) for what's still genuinely
  unimplemented (lookbehind).

### Changed

- `js-parse-function-expr` (`src/parser-expr-literal.lisp`) — found via a `paredit
  inspect clone-classes` sweep, whose top-ranked "duplication" in this file turned out
  to be a self-similarity artifact (the same 5-level-deep `multiple-value-bind` chain
  matched against itself at every nesting level, not real cross-location copy-paste) —
  investigating it anyway surfaced a genuine, separate readability problem the false
  "clone" was pointing at: 8 levels of nesting (5 `multiple-value-bind`s, 2 `let`s, a
  `cond`) in one function, the same shape an earlier session already fixed once for
  `regex-replace-placeholders`. Split the AST-building tail (everything after parsing
  finishes needing the stream — splitting params by defaults, building the rest
  binding, wrapping async/generator, the letrec self-recursion binding for named
  function expressions) into a new `%js-build-function-expr-ast`, taking plain values
  (`params optionals rest-sym body-forms async-p is-generator name`) instead of
  threading through nested stream-parsing binds. `js-parse-function-expr` itself drops
  from 8 nesting levels to 3 (just the stream-threading `multiple-value-bind`s a
  recursive-descent parser genuinely needs). Pure extraction, no behavior change —
  verified via `nix build .#checks.aarch64-darwin.default`: 1328 passed both before and
  after, 0 failed, exercising every branch this function has (named/anonymous,
  async/generator/async-generator/plain).
- `%js-compile-pattern`'s `compile-atom` (`src/runtime-regex.lisp`) — the regex
  compiler's atom parser, and by extension this codebase's single largest function
  (previously ~230 lines: one `defun` wrapping a `labels` form for
  `compile-atom`/`compile-seq`/`compile-alt`'s mutual recursion) — had the exact same
  4-line "adjust END past a group's closing `)`, if present" computation duplicated
  verbatim across all four parenthesized-group branches (lookahead, non-capturing,
  named-capturing, plain capturing). Extracted to a new `compile-group-close` function,
  added as a fifth sibling inside the SAME `labels` form (not a top-level `defun`) so it
  can still close over `pat` the same way its callers already do, with no calling-
  convention change and none of the risk a full top-level extraction of
  `compile-atom`/`-seq`/`-alt` into separate `defun`s would carry (each closes over
  several `let`-bound locals — `pat`, `ic`, `ml`, `group-count`, `group-names`,
  `compile-depth` — that a top-level function would need explicitly threaded through
  every call; deliberately still not attempted here, a separate, larger, riskier
  decision from this purely-internal helper extraction). Pure deduplication, no behavior
  change — verified via `nix build .#checks.aarch64-darwin.default`: 1328 passed both
  before and after, 0 failed, including the existing 300-trial regex fuzz test that
  exercises every one of these branches.
- `%js-char-set` (`src/runtime-ops-encoding.lisp`) built its membership hash-table with
  an explicit `:test #'eql` — `eql` is already `make-hash-table`'s default test, so this
  was pure noise, found via a fresh `paredit inspect lint` sweep. Simplified to
  `(make-hash-table)`. No behavior change, verified via `nix build
  .#checks.aarch64-darwin.default`: 1328 passed both before and after, 0 failed.
- `cl-boundary-kit` (transitive-only: needed for `cl-cc`'s own build to resolve,
  `cl-cc-javascript` never imports it directly) `v1.0.0` → `v2.0.0`: a real breaking
  release per its own `CHANGELOG.md` — native-environment `set-fn`/`unset-fn` now
  default to a real `cl-host-kit`-backed implementation instead of `nil`,
  `hostname-fn`/`username-fn`/`exit-fn`/args-source defaults moved onto `cl-host-kit`
  (no observable behavior change, implementation only), and the optional
  `cl-boundary-kit/process-kit`/`cl-boundary-kit/json` subsystems were removed. None of
  this touches surface `cl-cc-javascript` is exposed to. The blocker to bumping at all
  was `cl-host-kit` becoming a new *required* dependency of `cl-boundary-kit`'s core
  system — added as a new flake input (`v0.2.1`, latest tag) purely to satisfy this
  transitive requirement (not adopted for direct use — already evaluated and rejected
  on its own merits earlier this session) and wired through the same
  `dependencyEnv`/`scripts/dependency-roots.lisp` mechanism every other source-tree
  dependency here uses. `flake.nix`'s `cl-log-kit` pin comment updated to reflect that
  `cl-host-kit` is now available as an input (removing that specific blocker to a
  future `cl-log-kit` v2.0.0 evaluation) without bumping `cl-log-kit` itself in this
  pass — that pin's own breaking-change surface is a separate decision, not touched
  here. Verified via `nix flake check` (compile, tests, docs, formatting, coverage all
  green) and `nix build .#checks.aarch64-darwin.default`: 1328 passed, 0 failed.
- `regex-replace-placeholders` (`src/runtime-regex-api.lisp`) — the `$`-escape parser
  behind `String.prototype.replace`'s replacement-string handling — was 6 levels deep
  at its most nested point (a `loop` inside a `cond` inside an `if` inside a `let`
  inside another `cond`...). Extracted each escape kind's own logic into a focused
  helper (`%js-regex-named-escape-text` for `$<name>`,
  `%js-regex-numbered-escape-text` for `$1`-`$99`) called from a new
  `%js-regex-dollar-escape-text` dispatcher, so the main loop now reads as a flat
  "does TEMPLATE have a recognized escape at this position? emit its text and jump
  past it, or emit the literal character and advance by one" — no behavior change, all
  5 existing replacement-placeholder tests pass unchanged. Verified via `nix build
  .#checks.aarch64-darwin.default`: 1332 passed (unchanged count), 0 failed.
- `%js-emit-object-pattern-bindings`/`%js-emit-array-pattern-bindings`
  (`src/parser-stmt-binding.lisp`) — the two functions that turn a parsed
  destructuring pattern into a `let*` bindings alist were the deepest-nested
  functions in the codebase (indent depth 60 and 48 respectively), each inlining
  the AST-construction for every field/element kind directly in a `cond`. Extracted
  `%js-emit-rest-property-binding`/`%js-emit-named-property-bindings` (object
  patterns) and `%js-emit-array-rest-binding`/`%js-emit-array-element-bindings`
  (array patterns). The array-pattern extraction also collapsed two branches that
  were previously separate (`:default` vs. plain element) into one shared
  `%js-emit-array-element-bindings` call, since `%js-default-access` already
  returns its access expression unchanged when passed a `nil` default — the two
  branches differed only in whether that argument was present. No behavior change.
- `js-parse-function-decl` (`src/parser-stmt-fn.lisp`) — the generator/async
  body-wrapping `cond` (deciding whether the compiled defun's body becomes
  `(%js-make-generator (lambda () ...))`, `(%js-async (lambda () ...))`, or the
  plain body) was inlined at the function's deepest nesting point. Extracted as
  `%js-wrap-callable-body`, a self-contained named helper with no change to the
  token-stream-threading `multiple-value-bind` chain around it, which mirrors the
  same sequential-parse idiom used throughout this file's sibling parsers
  (`%js-parse-if-tail`, `js-parse-while-stmt`, `js-parse-do-while-stmt`) and was
  left alone. No behavior change.
- `js-parse-try-stmt` (`src/parser-stmt-flow.lisp`) — parsing catch clause(s),
  the optional finally clause, and lowering the result to the
  `%js-try-catch-finally` call were all inlined in one function reaching indent
  depth 54. Extracted `%js-parse-catch-binding` (the optional `(e)` after
  `catch`), `%js-parse-catch-clauses` (the catch-clause loop), `%js-parse-finally-
  clause`, and `%js-build-catch-dispatch` (the catch-clause-to-AST lowering),
  leaving `js-parse-try-stmt` itself as a flat `multiple-value-bind` chain over
  the four pieces. No behavior change.
- `%js-parse-decorator` (`src/parser-class-helpers.lisp`) — parsing the dotted
  member-access chain (`@foo.bar.baz`) and the optional argument list
  (`@decorator(args...)`) were both inlined in one function. Extracted
  `%js-parse-decorator-member-chain` and `%js-parse-decorator-args`, the
  latter's docstring now explicitly documenting why it builds an unbound
  `_decorator-arg_` placeholder per argument instead of a real parsed
  expression: `%js-lower-class-to-ast` discards its whole `decorators`
  argument today, so no decorator argument AST is ever actually evaluated —
  a real latent bug, deliberately not fixed here since it's inert until
  decorator execution is wired up, a separate, larger feature. No behavior
  change.
- `%js-make-url-search-params`'s `"set"` method (`src/runtime-builtins-
  platform-url.lisp`) inlined its whole rebuild-the-pairs-list algorithm (keep
  the first matching entry, overwrite its value, drop every later duplicate,
  append if absent) in a 15-line `let`/`dolist`/`cond`. Extracted as
  `%js-url-search-params-replace-first`, a pure function over `pairs`/`key`/
  `value` with no closure over mutable state, leaving the method itself a
  3-line `setf`+call. No behavior change.
- `%js-lower-incdec` (`src/parser-expr-postfix.lisp`) built the identical
  `(setq var (op var 1))` AST twice — once for prefix, once inside postfix's
  temp-binding body — differing only in whether the left operand was the
  original `expr` node or a freshly built `(make-ast-var :name var-sym)`
  (the same thing, since this branch only runs when `expr` already satisfies
  `ast-var-p` with that name). Extracted `%js-incdec-setq`. No behavior
  change.
- Three genuinely quadratic accumulation patterns, found via a fresh
  `paredit inspect lint` sweep of `src/*.lisp` after this session's own
  extractions (`quadratic-accumulation` rule, 7 findings total): (1)
  `%js-emit-object-pattern-bindings`/`%js-emit-array-pattern-bindings`
  (`src/parser-stmt-binding.lisp`) rebuilt their whole bindings list on every
  destructured field/element via `(setf bindings (append bindings ...))` —
  O(n²) in field count. Rewritten as `loop ... nconc`, which splices each
  field's fresh bindings onto an accumulated tail in O(1) instead of copying
  the whole list-so-far on every iteration. (2) `%js-parse-tagged-template`
  (`src/parser-expr-unary.lisp`) built up a tagged template's cooked string
  via repeated `(concatenate 'string current part)` for every consecutive
  string part — collected into a list and joined once per flush instead. (3)
  `js-parse-var-decl` (`src/parser-stmt.lisp`) rebuilt the whole bindings
  list per comma-separated declarator (`let a=1, b=2, ...`) the same way as
  (1) — each declarator's bindings now collected into a list and flattened
  once after the loop. All three are `for`/`dolist`-adjacent patterns where
  the accumulated result only grows a small, bounded amount per iteration in
  typical code (a handful of destructured fields or declarators), so the
  practical severity was low, but the fix is free and the pattern is worth
  keeping out of the codebase regardless. No behavior change — verified via
  `nix build .#checks.aarch64-darwin.default`, `paredit inspect lint`
  confirms 0 remaining `quadratic-accumulation` findings.
- `%js-percent-encode` (`src/runtime-ops-encoding.lisp`, backing
  `encodeURIComponent`/`encodeURI`) tested each input character against its
  safe-chars set with `member` — an O(9) or O(20) linear scan repeated once
  per input character, found via the same `linear-search-in-loop` lint sweep
  as the entry below. `+uri-component-safe-chars+`/`+uri-safe-chars+` are
  small, fixed, load-time constants reused across every call, so precomputing
  them once as `%js-char-set` hash-tables (O(1) `gethash` per character
  instead of an O(k) `member` walk) is a clean, unconditional win with no
  per-call construction cost. Investigated 9 other `linear-search-in-loop`
  findings from the same sweep and did NOT apply the same fix to any of them:
  most search genuinely tiny fixed lists (regex flags, a handful of escape
  characters, function parameter/optional-default alists) where a hash-table
  adds allocation overhead with no realistic win; one
  (`%js-destructure-object`'s `excluded`-keys check,
  `src/runtime-object-ops.lisp`) rebuilds its collection fresh on every call,
  so hash-table construction cost could plausibly offset the asymptotic gain
  for the small key counts real destructuring code exercises — left as
  `member`, not a clear improvement either way; and one
  (`%js-split-string-on-char`'s `position` call,
  `src/runtime-builtins-platform-url.lisp`) is a false positive — its
  `:start` argument advances every iteration, so the loop is already O(n)
  total (each character is scanned at most once across all iterations), not
  the O(n·k) the lint rule's pattern-match assumed. No behavior change,
  verified via `nix build .#checks.aarch64-darwin.default`.
- `performance.now()` (`src/runtime-builtins-table-specs.lisp`) computed
  `(- (get-internal-real-time) 0)` — subtracting the literal 0 is a no-op
  (`identity-arithmetic` lint finding). No behavior change.
- `flake.nix`'s `apps.default`/`apps.test` outputs gained a `meta.description` —
  `nix flake check` previously warned "app ... lacks attribute 'meta'" for
  both; a fresh full-file review of `flake.nix`/`cl-cc-javascript.asd` (goal:
  catch drift, not routine — the version-sync comment's own claim
  ("flake.nix reads this form... refuses to publish a tag that disagrees")
  and the `:depends-on`/dependency-roots.lisp/package.lisp wiring were all
  independently re-verified correct, no other issues found) turned this up
  as the one genuine, fixable finding. `nix flake check --no-build` now
  reports zero warnings besides the expected "dirty tree"/"omitted systems"
  ones.
- `%js-make-regex` was exported twice from `src/package.lisp` — once (stray)
  under the "Class / accessor helpers" heading between `%js-accessor` and
  `%js-assign-pattern`, and once (correctly placed) under "RegExp (ES2015+
  native engine)" alongside `%js-regexp-p`/`%js-regex-exec`. Found while
  reconciling `docs/src/index.md`'s "320 exported symbols" claim against an
  actual count — the raw symbol list had 321 entries but only 320 unique
  ones, and `docs/src/api-reference.md` (320 `###` entries, one per unique
  exported symbol) was already correct, confirming the doc's "320" was right
  and the duplicate export was the bug. Removed the stray copy. Also fixed
  `docs/src/installation.md`'s dependency-resolution env-var table, which
  still listed only the original 9 entries and said "sets all nine" — missing
  the `cl-date-kit`/`cl-json-kit`/`cl-concurrent-kit` entries this session's
  three dependency adoptions added; now lists all 12 and updated the
  introductory paragraph to note that some of these are direct dependencies
  of this frontend, not only transitive ones pulled in via `cl-cc`. No
  behavior change either way — verified via `nix build
  .#checks.aarch64-darwin.default` and `.#checks.aarch64-darwin.docs`.
- `js-rt-url-search-params-set-appends-new-key` (`t/runtime-builtins-
  platform-test.lisp`): `URLSearchParams#set` on a key not already present
  behaves like `.append()` per spec — the existing `.set()` tests only
  exercised overwriting an already-present key (including the
  collapse-duplicates case), never this branch of
  `%js-url-search-params-replace-first` (extracted from `.set()` earlier
  this session). Found while checking this session's own extracted helpers
  for real test coverage, not just an unchanged aggregate pass count.
- A `try { } catch { }` (ES2019+ optional catch binding — no `(e)` parameter)
  case added to `js-e2e-try-catch-finally`'s test table
  (`t/e2e-core-test.lisp`). This exercises `%js-build-catch-dispatch`'s
  bindless-catch branch (the `(make-ast-progn :forms body)` path, as opposed
  to the `(make-ast-let ...)` path when a catch variable is present) — a
  grep across the whole `t/` tree found no prior test with a bare `catch {`
  anywhere, despite the parser/lowering explicitly supporting it
  (`%js-parse-catch-binding`'s own docstring: "VAR-SYM is nil for a bindless
  `catch {}`"). A real end-to-end coverage gap dating back well before this
  session's `js-parse-try-stmt` extraction (the original, un-extracted
  function had the identical branch, equally untested) — passes, confirming
  this was an unexercised-but-correct path rather than a hidden bug.
  Verified via `nix build .#checks.aarch64-darwin.default`: 1320 passed
  (unchanged — this case joined an existing batch test rather than adding a
  new standalone one), 0 failed.
- `js-e2e-generator-return-and-throw` (`t/e2e-advanced-builtins-test.lisp`):
  explicit `.return()`/`.throw()` calls on a suspended generator — genuinely
  untested anywhere in this suite before now (a grep for `.throw(`/`.return(`
  or the string literals `"throw"`/`"return"` across all of `t/` found
  nothing generator-related), despite `%js-make-generator`'s coroutine
  channel being rewritten onto `cl-concurrent-kit` this same session. Two of
  the three cases found the real `*standard-output*` bug documented in the
  `### Fixed` entry above — this is what found it, not a targeted hunt for
  it.
- `js-parser-decorators-with-nested-call-arg` (`t/parser-stmt-misc-test.lisp`)
  checks the rest-stream position after a decorator whose argument is itself
  a call — the pre-existing `js-parser-decorators-with-args` test only
  checks the parsed argument count, never the returned rest-stream, which is
  exactly what let the parser-corruption bug documented in the `### Fixed`
  entry above go unnoticed.
- A class-method case added to `js-e2e-class-getters-setters`
  (`t/e2e-advanced-test.lisp`) checking that a method *after* one with a
  nested-call default parameter value still parses and runs — the same
  "check the tests actually assert on what follows, not just the immediate
  parse result" gap as the decorator entry above, and what caught the
  `### Fixed` entry directly below it.
- `js-e2e-class-static-blocks` (`t/e2e-advanced-test.lisp`): the first tests
  anywhere in this suite for ES2022 `static { ... }` class initialisation
  blocks, despite the feature being explicitly listed as supported in
  `src/parser-class.lisp`'s own header comment — this is what found the
  "never actually runs at all" bug documented in the `### Fixed` entry
  below.
- `js-e2e-private-fields-and-methods` (`t/e2e-advanced-test.lisp`): the first
  tests anywhere in this suite that actually call a private method or read/
  write a private field through real execution, rather than only checking
  that `#name` syntax parses into class slots — this is what found the
  broken/not-actually-private private-methods bug documented in the
  `### Fixed` entry below (private fields turned out already correct).
- Two more cases in `js-e2e-private-fields-and-methods`
  (`t/e2e-advanced-test.lisp`) covering `static #name()` private methods
  specifically, added proactively right after fixing the instance-method
  version above, on the hypothesis that the same missing-privacy bug would
  exist in the static path too — it did, confirmed by these cases failing
  against the pre-fix code with the identical error before any fix was
  attempted; see the corresponding `### Fixed` entry below.
- `src/runtime-temporal.lisp` (398 lines, above the org's 300-line file
  guideline — its siblings `runtime-temporal-duration.lisp`/`-parse.lisp`/
  `-global.lisp` are 71/31/144 lines) split by concern: `%js-temporal-plain-
  time`/`%js-temporal-plain-datetime`/`%js-temporal-zoned-datetime` — the
  three Temporal types that carry a time-of-day component — moved to a new
  `src/runtime-temporal-datetime.lisp` (133 lines). `runtime-temporal.lisp`
  keeps the shared helpers, IANA time-zone support, `Temporal.Now`, and the
  types with no time-of-day field (`Instant`, `PlainDate`, `PlainYearMonth`,
  `PlainMonthDay`), now 281 lines. Also fixed a stale comment in the original
  file claiming `PlainYearMonth`/`PlainMonthDay` "live in
  runtime-temporal-duration.lisp" when they were defined right there in the
  same file the whole time. No behavior change — a pure move, `nix build
  .#checks.aarch64-darwin.default` still reports 1317 passed, 0 failed.
- `src/parser-class-lower.lisp` (400 lines, above the org's 300-line file
  guideline, and grown further by this same session's bug #4/#5/#6 class
  fixes above) split by concern into classification vs. lowering: the
  slot/key accessor helpers (`%js-slot-method-p`, `%js-slot-to-method-
  lambda`, `%js-super-ref`, `%js-wrap-method-super`, `%js-class-member-key`,
  `%js-class-member-key-ast`) and the eight `%js-class-*-slots` predicates
  that partition a class's parsed member list by role (constructor, public/
  private instance methods, public/private static methods, static fields,
  instance fields) moved to a new `src/parser-class-lower-classify.lisp`
  (answers "which slot is this," no `%js-make-class`-argument building) —
  `parser-class-lower.lisp` keeps the per-role lowering functions (turning a
  classified slot into `%js-make-class` arguments), `%js-lower-class-to-ast`,
  and the public `js-parse-class-decl` entry point, now 220 lines. Three
  stale filename references in doc comments (`parser-class.lisp`,
  `runtime-property.lisp`, `t/e2e-advanced-test.lisp`) pointing at functions
  that moved were updated to match. No behavior change — a pure move,
  verified via `nix build .#checks.aarch64-darwin.default`: 1326 passed
  both before and after, 0 failed.
- Real `String.raw`/tagged-template-`.raw` coverage: `js-e2e-string-static-
  methods` (`t/e2e-advanced-builtins-test.lisp`) gained two cases checking
  actual raw (escapes-untouched) output, replacing a comment that had
  explained why it was "intentionally not covered"; `js-e2e-tagged-templates`
  (`t/e2e-advanced-test.lisp`) gained two cases where a CUSTOM tag function
  (not the String.raw built-in) reads `.raw` directly, proving the fix is
  the real general TC39 protocol and not a shortcut special-cased to one
  built-in. New `js-e2e-array-extra-properties`
  (`t/e2e-advanced-builtins-test.lisp`) covers `arr.foo = 1`/`'foo' in arr`/
  `.length`/method-still-works-after — the more general capability the
  `.raw` fix needed and that turned out to be a genuine, separate,
  previously-untested gap; see the `### Fixed` entry above. Four existing
  lexer-internals unit tests in `t/lexer-test.lisp` (`lex-template-simple`,
  `-escaped-cook`, `-interpolated`, `-nested-interpolation`) updated for the
  template lexer's new `(:text cooked raw)` part shape (previously a bare
  cooked string) — a legitimate representation-change update, not a
  weakened assertion; each still checks the same cooked value plus a new
  raw-value assertion.
- `js-rt-array-flat-infinity-depth` (`t/runtime-array-test.lisp`): the first
  test for `arr.flat(Infinity)` — the idiomatic "flatten however deep it
  goes" call — which had never been exercised with anything but a small
  integer depth. Written to check a specific hypothesis (found while
  auditing test coverage across common Array methods after the `sort`/
  `undefined` bug below): that `Infinity` might reach `%js-array-flat`'s
  depth countdown as the SEPARATE `:js-infinity` keyword sentinel some other
  code paths use, which would signal a real `TYPE-ERROR` on `(plusp d)`. The
  hypothesis was wrong before any code was touched — `Infinity` the global
  identifier resolves to `*js-inf-float*`, a genuine IEEE-754 double-float
  bit pattern (`src/runtime.lisp`), which `plusp`/`1-` handle correctly as
  an ordinary (if unusual) number — confirmed by writing the test with the
  CORRECT value and it passing cleanly, not by reasoning alone. No bug, no
  code change; a real regression test for previously-untested-but-correct
  behavior, and a documented reminder that this codebase has two distinct
  "infinity" representations for different purposes, easy to conflate.
- Two new cases in `js-e2e-object-static-methods` (`t/e2e-modern-test.lisp`):
  a 5-key object literal checking that string-key insertion order survives
  past 2 keys (it does), and `Object.keys({2:'b',foo:'bar',1:'a'})` checking
  the array-index-keys-sort-numerically-first ordering rule — the case that
  found (and, combined with a unit-level `nix build` run against the fix, is
  what verified) the two `### Fixed` entries directly above.
- A third case in `js-e2e-for-in` (`t/e2e-advanced-builtins-test.lisp`)
  checking the same array-index-keys-first ordering rule through
  `for...in` — the case that found the `%js-for-in` bug documented in the
  `### Fixed` entry above.
- Two new tests in `t/runtime-json-test.lisp`: `js-rt-json-stringify-
  object-key-order` (exact-string check, not the pre-existing substring-
  inclusion style, which can't distinguish "order was applied" from
  "nothing needed reordering") and `js-rt-json-stringify-object-getter-
  property` — the two cases that found the `JSON.stringify` bugs
  documented in the `### Fixed` entry above.
- Two new cases in `js-e2e-regex-string-methods` (`t/e2e-modern-test.lisp`):
  `"2023-01-15".split(/(-)/)` (the classic capturing-group splice example)
  and an optional non-participating group splicing `undefined` — the cases
  that found the `String.prototype.split` bug documented in the `### Fixed`
  entry above.
- A fourth `cl-weave` `it-property` test, `js-rt-json-stringify-parse-
  roundtrip-property` (`t/runtime-json-test.lisp`), asserting `JSON.parse
  (JSON.stringify(v)) = v` for arbitrarily nested trees (up to 3 levels,
  built via `gen-recursive`) of every JSON-representable JS value kind —
  numbers, strings, booleans, null, arrays, and objects — rather than the
  one hand-picked flat `{name, age}` object the existing
  `js-rt-json-roundtrip` example covers. Uses cl-weave's `:to-equalp`
  matcher (CL `EQUALP`), not the more common `:to-equal` (CL `EQUAL`) —
  `EQUAL` only compares general vectors/hash-tables by object identity, so
  it would have silently accepted a completely wrong roundtrip; `EQUALP`
  recurses into both, which is what a structural-equality property
  actually needs. Extends this codebase's still-sparse use of property-
  based testing (4 `it-property` tests total now, up from the 3 documented
  earlier in this file, plus one separate `it-fuzz` test) with a fourth,
  chosen because the JSON engine was
  itself swapped to `cl-json-kit` earlier this session and previously had
  no test exercising structural nesting beyond one level.
- `%js-iterator-zip`/`%js-iterator-zip-keyed` (`src/runtime-collections-zip.lisp`) had
  identical 4-line terminal decision logic — done vs. `"strict"`-mode type error vs.
  `"shortest"`-mode truncation vs. wrap-and-continue — differing only in whether the
  collected row was an array or a keyed object. Extracted to a shared
  `%js-zip-finish-step` helper; each call site now differs only in what container it
  passes through as `row-or-result`. No behavior change — verified via `nix build
  .#checks.aarch64-darwin.default` at an unchanged 1336 passed / 0 failed.
- Split `t/e2e-advanced-test.lisp` (506 lines, one over the org's 500-line cap — grown
  past it incrementally over several sessions' regression tests) at its existing
  "Class features" section boundary into itself (240 lines: optional chaining through
  standalone global builtins) and a new `t/e2e-advanced-builtins-test.lisp` (280 lines:
  class features, contextual keywords/Symbols/globals, for-in/of, generators, and every
  builtin static-method family). Pure move, verified via `nix build
  .#checks.aarch64-darwin.default` at an unchanged 1336 passed / 0 failed. Also fixed
  while auditing this: `docs/src/architecture.md`'s file/line-count table and "Known
  issue: the duplicate definition in cl-cc" section had drifted stale (93 files → 95,
  `packages/cl-cc-javascript/` → the actual `packages/javascript/`, "46 differ" → a
  freshly re-verified 71-of-88-common-files-differ plus 7 files unique to this checkout
  and 1 unique to the monorepo copy, re-checked by actually cloning the pinned `cl-cc`
  commit and diffing `src/` against it rather than trusting the old numbers).
- `flake.lock`: adding the `cl-json-kit` input moved several other floating-tag inputs'
  locked revisions forward too (`cl-boundary-kit`, `cl-cli`, `cl-dataflow`,
  `cl-nix-forge`, `cl-parser-kit`, `cl-prolog`, `cl-tty-kit`, `cl-weave`) — `nix flake
  update cl-json-kit` (the correctly-scoped, non-deprecated form; `--update-input` warns
  it is now just an alias for a full `flake update`) still re-resolved every ref-pinned
  input, not only the one named. Each of those tags' `url` in `flake.nix` is unchanged;
  only the commit each tag *currently* points to moved, which for a set of siblings this
  actively developed (every one tagged within roughly the same week) plausibly reflects
  a tag that was re-pushed upstream after this repo's lock file was first written, not
  a version bump this repo asked for. Accepted rather than fought after `nix build
  .#checks.aarch64-darwin.default` came back green against the refreshed lock — the
  correctness contract is "these pinned tags build and pass," not "these exact commit
  hashes never move without a `flake.nix` edit," and `nix flake update <name>` appears
  unable to scope more narrowly than this in the pinned `cl-nix-forge`-era Nix. Worth
  knowing before assuming a future single-input update touched only that input.
- 9 hand-rolled `(let ((signaled nil)) (handler-case ... (js-exception () (setf signaled
  t))) (expect signaled :to-be-truthy))` blocks, across `t/runtime-collections-
  iterators-test.lisp` (6), `t/runtime-method-resolver-dispatch-test.lisp` (1), and
  `t/runtime-collections-values-test.lisp` (1), replaced with `cl-weave`'s own
  `expect-rejects` + `:to-be-instance-of` — `(expect-rejects (lambda () ...)
  :to-be-instance-of 'cl-cc/javascript:js-exception)`. `expect-rejects` was previously
  unused in this test suite despite fitting this exact pattern natively: unlike
  `signals` (see the `feedback-cl-weave-signals-error-only` note — hardcoded to catch
  only `error` subtypes, which `js-exception` is not), `expect-rejects`'s own
  implementation (`call-rejecting-expectation-thunk`, `cl-weave/src/expect-runtime.lisp`)
  catches plain CL `condition`, so it works correctly against this codebase's own
  non-`error` `js-exception` with no adapter or workaround needed. Also asserts more
  precisely than before — the old pattern's `handler-case` had exactly one clause
  (`js-exception`), so a wrong-type condition would propagate uncaught straight through
  `let` and crash the whole test-runner process rather than fail just that test (the
  same failure mode `feedback-cl-weave-signals-error-only` describes for `signals`);
  `expect-rejects` catches any `condition` first and only then applies the
  `:to-be-instance-of` matcher, so a wrong-type rejection becomes a normal, readable
  assertion failure reporting what was actually thrown, not a process crash. Pure
  test-code refactor — verified
  via `nix build .#checks.aarch64-darwin.default` at the same 1333 passed / 0 failed.
- `cl-parser-kit` (transitive-only: `cl-cc`'s own build resolves it for `optimize`'s
  e-graph rules, `cl-cc-javascript` never imports it directly) `v1.0.1` → `v1.0.2`:
  two upstream bug fixes (a dropped `:position` on `parse-pratt`'s token-limit failure
  path, and a decimal-literal tokenizer overflow on very long integer parts), no public
  API change — checked against `cl-parser-kit`'s own `CHANGELOG.md` before bumping, per
  this file's existing per-dependency-pin convention. Audited every other pinned
  `nerima-lisp/*` input's tags (`git ls-remote --tags`) against `flake.nix`'s current
  pins this session: `cl-weave`, `cl-prolog`, `cl-dataflow`, `cl-boundary-kit`,
  `cl-cli`, `cl-tty-kit`, `cl-date-kit`, and `cl-nix-forge` were all already at their
  latest tag. `cl-log-kit` (`v1.0.0`, latest `v2.0.0`) was deliberately left alone —
  `flake.nix`'s own comment on that pin already explains it's transitive-only and
  needs its own `scripts/dependency-roots.lisp` wiring evaluated on its own merits
  before bumping, a prior decision this session found no new reason to revisit. `cl-cc`
  stays pinned to a specific commit (not a tag) for the documented reason already in
  `flake.nix`: its own `v0.1.0` release's test suite currently fails (55 failures, 31
  errors), so the commit pin is the actually-working reference, not an oversight.
- `paredit fix apply` swept `t/*.lisp` (never covered by the earlier `src/*.lisp`
  sweep above) with the same rule set and `--no-destructive-fixes` safety flag: 51
  rewrites across 17 files — mostly `sign-comparison` (`(= 0 x)` → `(zerop x)`,
  `(< x 0)`/`(> x 0)` → `(minusp x)`/`(plusp x)`), plus `redundant-let-star` (a
  single-binding `let*` has no binding to depend on the others) and
  `redundant-progn`/`de-morgan`/`one-step-arithmetic`/`nil-comparison` singles. Given
  the prior sweep's quote/backquote-stripping incident (see the entry below), every
  hunk was read by hand before applying and re-checked with `paredit inspect lint
  --category malformed` after (0 findings) — none of the 51 touch either of `t/`'s two
  `defmacro` forms (`t/e2e-core-test.lisp`'s `deftest-js-run`/`deftest-js-run-isolated-
  batch`, `t/runtime-builtins-promises-test.lisp`'s `with-fresh-js-module-exports`) or
  any quoted/backquoted template; every rewrite lands in an ordinary `it-sequential`
  test body or plain `defun`. Pure mechanical cleanup — verified via `nix build
  .#checks.aarch64-darwin.default` at the same 1333 passed / 0 failed as before.
- Split `src/runtime-regex.lisp` (its data tables, matcher-closure combinators, and
  character-class parser — everything `%js-compile-pattern`'s recursive-descent parser
  assembles but doesn't itself decide the control flow for) into a new sibling
  `src/runtime-regex-combinators.lisp`, leaving `runtime-regex.lisp` holding only
  `%js-compile-pattern` itself. The regex work above had grown the file to 448 lines,
  the largest non-`defpackage` source file in the tree; the split follows this
  codebase's existing "core + helpers" convention (`runtime-array-core`/
  `runtime-array-transforms`, `parser-class`/`parser-class-helpers`, ...) rather than
  introducing a new one. Pure reorganization — verified via `nix build
  .#checks.aarch64-darwin.default` at the exact same 1332 passed / 0 failed as
  immediately before the split. Two stale file-location references caught and fixed
  while at it: a comment in `src/runtime-ops.lisp` claiming `%js-make-regex` lives in
  `runtime-regex.lisp` (it's always been in `runtime-regex-api.lisp`, predating this
  split) and `docs/src/api-reference.md`'s `%js-regexp-p` entry, which did move.
- `paredit inspect lint`/`fix apply` swept `src/*.lisp` for its full mechanical-fix
  rule set — 130 rewrites across 45 files (`sign-comparison`, `cons-to-list`,
  `negated-if`, `nil-comparison`, `format-to-string`, `one-step-arithmetic`,
  `de-morgan`, `explicit-nil-return`, `list-star-to-cons`, `redundant-if-nil`,
  `redundant-progn`, `if-to-or`, `if-to-unless`, `redundant-let-star`,
  `negated-when-unless`, `redundant-body-progn`, `redundant-funcall`,
  `single-value-bind`, `constant-if-test`), followed by `paredit edit format --write`
  on every touched file to clean up the branch-reordering rewrites' line-wrapping,
  plus a scope-aware `paredit refactor rename-binding` (`setq` → `setq-ast` in
  `src/parser-expr.lisp`'s `%js-lower-logical-assign`, a local variable shadowing the
  CL special-operator name closely enough that it triggered two of the lint tool's
  own `setf-arity`/`setq-non-variable` false positives). Performance/security/
  concurrency findings (`quadratic-accumulation`, `eval-of-non-constant`,
  `implementation-package-symbol`, and so on) need human judgment and were correctly
  left out of the auto-fix set — not applied, not otherwise addressed this pass.
  **Six of the 130 mechanical rewrites were wrong**, silently dropping a `quote` or
  backquote from macro-template code that a purely syntactic rewrite couldn't
  distinguish from live code — caught by the mandatory full-suite `nix build`
  (four as hard compile errors: "the variable I is unbound" from a `one-step-arithmetic`
  rewrite of a quoted `'(- i 1)` template in `define-js-array-reducer`
  (`src/runtime-array-core.lisp`); "comma not inside a backquote" from
  `redundant-progn`/`redundant-body-progn` stripping the backquote off a `` `(progn
  (defun ...) (defun ...)) `` macro body in `define-js-map-like-get-or-insert`
  (`src/runtime-map.lisp`), `define-js-weak-membership-ops`
  (`src/runtime-weak-collections.lisp`), and `define-js-error-subclasses`
  (`src/runtime-class.lisp`); one silently producing wrong *runtime* behavior with no
  compile error at all — `define-js-type-resolver`'s (`src/runtime-method-resolver-
  core.lisp`) `,@(loop ...)` splice lost its `,@`, turning a `cond` clause list built
  from `special-props` into one malformed clause, which actively broke `.length`/
  `.size` resolution for Array/String/Map/Set (every one of those types passes a
  non-empty `special-props`) until reconstructed by hand; and one dropped a necessary
  `progn` in an `if` then-branch in `%with-private-ht` (`src/runtime-class.lisp`),
  where `if` — unlike a `loop`'s `do` clause or a function-call argument list, both of
  which natively splice multiple forms — has a fixed two-or-three-argument arity. All
  six were found by first tracing the specific compile failure to its rule, then
  (once the failure mode recurred across different rules) exhaustively reading every
  one of the 31 `defmacro` bodies across the 45 touched files by hand, not by
  trusting the tool's own "fixable"/safe categorization. Verified clean afterward via
  `nix build .#checks.aarch64-darwin.default` (1315 passed, matching the pre-batch
  baseline exactly — same count, 0 failed, 0 errored). See the `feedback-paredit-
  lint-quote-stripping` session note for the full forensic detail; this is the kind
  of thing worth knowing before trusting a bulk `paredit fix apply` in a
  macro-code-generation-heavy codebase like this one's `define-js-*` family again.
- `%js-array-group`, `%js-array-group-to-map`, `%js-object-group-by`, and
  `%js-map-group-by` (`src/runtime-array-es2023.lisp`,
  `src/runtime-object-ops.lisp`, `src/runtime-builtins-globals.lisp`) each
  repeated the same "find this key's bucket array, lazily creating it if this
  is the key's first item, then push" branch against their own container API
  (hash-table vs js-map). A new CPS-style `%js-group-into`
  (`src/runtime-array-core.lisp`, next to `%js-make-array`, which every
  caller's bucket-creator still uses directly) unifies that shared part: each
  caller supplies an `iterate-fn` that walks its own source with its own
  key-fn arity/coercion (the two Array methods use an index loop and a 3-arg
  key-fn; `Object.groupBy`/`Map.groupBy` use `%js-for-of` and a 2-/1-arg
  key-fn) and calls a `visit` continuation with `(key item)`, plus a
  `get-bucket` continuation that returns — creating first if needed — the
  bucket array for a key. What stayed different (iteration mechanism, key-fn
  arity, string-coercion, container type) stayed different; only the
  duplicated get-or-create-then-push shape moved into one place.
- `%js-date-time-format-option-string` and `%js-number-format-option-integer`
  (`src/runtime-builtins-intl-date-time-format.lisp` /
  `-intl-number-format.lisp`) shared the same "missing means DEFAULT, present
  means coerce" shape, found via `paredit inspect similarity` — now both call
  a new `%js-intl-coerced-option` (`src/runtime-builtins-intl-core.lisp`, next
  to `%js-intl-option` which it wraps), each supplying only its own coercion
  function (`#'%js-to-string` / a integer-clamping lambda).
- 13 of `t/*.lisp`'s 21 hand-rolled `(let ((sig nil)) (handler-case (progn body)
  (COND () (setf sig t))) (expect sig :to-be-truthy))` exception-testing sites — the
  ones catching plain `error` — now use cl-weave's own `signals` macro:
  `(signals error body)`. Found via `paredit query find` with a structural pattern
  (`(let ((?sig nil)) (handler-case (progn ?body...) (?cond () (setf ?sig t)))
  (expect ?sig :to-be-truthy))`), converted with `paredit query replace`, across
  `t/parser-stmt-module-test.lisp`, `t/parser-stmt-pattern-internals-test.lisp`,
  `t/runtime-builtins-platform-object-test.lisp`, `t/runtime-builtins-platform-test.lisp`,
  `t/runtime-json-test.lisp`, and `t/runtime-string-number-test.lisp`. The other 8
  sites (catching `cl-cc/javascript:js-exception`) were converted too on the first
  pass, then reverted: `js-exception` is a plain `condition`, not an `error` subtype,
  and cl-weave's `signals`/`:to-throw` only ever catches `error`
  (`cl-weave/src/matcher-runtime.lisp`'s `thrown-condition` hardcodes `(handler-case
  ... (error (c) c))`) — so those 8 sites crashed the whole test runner instead of
  failing one test the first time `nix build` ran ("Unhandled
  CL-CC/JAVASCRIPT:JS-EXCEPTION in thread ... main thread"), caught by the mandatory
  full-suite verification step and reverted to the original `handler-case` form.
  Recorded as a cl-weave constraint worth knowing before attempting this again.
- `%js-compile-pattern`'s `compile-atom`/`compile-seq` (`src/runtime-regex.lisp`) no
  longer repeat two pieces of logic inline at every call site: the case-insensitive
  character read (`(if ic (char-downcase (char str i)) (char str i))`, previously
  written out identically at three separate atom-matcher sites) is now
  `%js-regex-char-at`, and the near-identical greedy-loop bodies inside the `*`/`+`
  quantifier wrappers are now one shared `%js-regex-greedy-match` — `*` calls it
  directly (zero or more matches), `+` calls it only after its one required match
  already succeeded (one or more). Also dropped a stale `(declare (ignore groups))`
  on the `*` wrapper's lambda that was inaccurate even before this change (the loop
  it wrapped already passed `groups` through to `fn`). Behavior-preserving —
  verified via `nix build .#checks.aarch64-darwin.default` (1313 passed) — the
  quantifier and case-insensitive-flag tests in `t/runtime-regex-test.lisp` already
  covered every call site touched.
- `src/macros.lisp` (new, loaded straight after `package`) holds
  `define-builder-table`, which replaces the hand-written
  `let`/`dolist`/`setf (gethash ...)` block that eight dispatch tables each
  carried their own copy of: `*js-keywords*`, `*js-op-infix-prec*`,
  `*js-direct-binop-keywords*`, `*js-binop-runtime-helpers*`,
  `*js-coercion-call-helpers*`, the two unary builder tables, and the Map and
  RegExp constructor globals. Only the data is left at each call site.
- `lex-js-operator` is a maximal-munch lookup in a new `*js-operator-tokens*`
  table rather than a 15-arm `case` over the first character with the 2-, 3-
  and 4-character checks written out by hand. Every JS operator spelling now
  appears exactly once, as data.
- `lex-js-number`'s three radix branches (`0x`, `0o`, `0b`), which differed only
  in a digit reader and a radix, became one lookup in `*js-radix-prefix-readers*`.
- The base64 arithmetic is shared: `%js-base64-encode-bytes` and
  `%js-base64-decode-bytes` back both `atob`/`btoa` and
  `Uint8Array.toBase64`/`fromBase64`, which previously carried independent
  copies of the same RFC 4648 bit shuffling and `=` padding rules.
- `with-js-loop-tags` establishes the loop-control specials for all five loop
  parsers (`while`, `do-while`, `for`, `for-in`, `for-of`), which each spelled
  out the same six bindings.
- `%js-comma-list-step`, `%js-chain-step`, `%js-parse-as-alias-specifiers`,
  `%js-array-relative-start`/`-end`, `%js-regex-escape-literal`, `%js-not` and
  `js-at-op-p` each replace a block that had been open-coded in three or more
  places. `js-parse-import-specifiers` and `js-parse-export-specifiers` also
  lose a `cond` whose two branches had become identical, and now share their
  entire specifier-list loop (not just one `name [as alias]` pair) through
  `%js-parse-as-alias-specifiers`'s builder-callback parameter.
- `define-js-type-resolver` now generates `%js-resolve-promise-method`,
  `%js-resolve-number-method` and `%js-resolve-weak-ref-method`, the three
  resolvers that were still written out by hand, and
  `define-js-weak-membership-ops` generates the WeakMap and WeakSet
  `has`/`delete` pairs.
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
- `flake.nix` adopts [cl-nix-forge](https://github.com/nerima-lisp/cl-nix-forge) (pinned
  `v0.4.0`) for the two pieces that fit without forcing an adapter: `fromAsdSystem` (the
  `:version` single source of truth, replacing a hand-rolled regex) and `mkDocsSite`
  (the MkDocs Material site, byte-for-byte the same derivation this file used to
  hand-roll). `mkPackageFlake` and the `lispDerivation` dependency-graph model it is
  built on were deliberately NOT adopted for the main package/checks/devShell: this
  repository's production system depends on four `cl-cc` sub-systems that only exist
  because `cl-cc.asd` registers them as a load-time side effect, a bootstrap step
  `lispDerivation`'s fixed `(asdf:load-system ...)` build phase has no hook to express.
  Every hand-rolled `timeout N` in `flake.nix` is now `timeout --kill-after=30 N`,
  matching cl-nix-forge's own documented grace-period default.
- Seven sibling dependency pins bumped after individually confirming no breaking change
  from each release's own CHANGELOG.md: `cl-weave` v1.0.0→v1.1.0, `cl-prolog`
  v1.0.1→v1.1.0, `cl-parser-kit` v1.0.0→v1.0.1, `cl-dataflow` v1.0.0→v1.1.0, `cl-cli`
  v1.0.1→v1.1.0, `cl-tty-kit` v1.0.0→v1.0.3, `cl-boundary-kit` v0.6.0→v1.0.0.
  `cl-log-kit` stays at v1.0.0: its v2.0.0 adds three new runtime dependencies
  (`cl-date-kit`, `cl-concurrent-kit`, `cl-host-kit`) not wired into this repository's
  flake, a real breaking change rather than a safe bump.
- Five test files that had grown past the org's 500-line cap (`runtime-builtins-test.lisp`
  695 lines, `runtime-collections-test.lisp` 669, `runtime-date-json-test.lisp` 594,
  `parser-stmt-test.lisp` 538, `runtime-method-resolver-test.lisp` 527) split into 18
  focused files along their own existing section boundaries, each under 300 lines. No
  test content changed; the `.asd` component list was updated in place.
- Several exact/near-exact code duplications consolidated into shared helpers, each
  verified behavior-preserving by the full test suite: base64 encode/decode (previously
  duplicated between the global `btoa`/`atob` and `Uint8Array.toBase64`/`fromBase64`),
  `for-in`/`for-of` statement parsing, `yield`/`yield*` expression parsing (previously
  byte-for-byte duplicated across two parser files), the Temporal `add`/`subtract`
  encode-shift-decode shape, and the regex `/g`-flag match-collection loop.
- Both `defpackage` forms (`src/package.lisp`, `t/package.lisp`) now use `#:` designators
  throughout — matching the org standard several sibling packages already conform to —
  instead of a mix of `:` (keyword, interns into the `KEYWORD` package as a side effect)
  and `#:` (uninterned symbol) for the package name, `:use`, `:import-from`'s package
  name, and `:shadowing-import-from`. `src/package.lisp`'s body already used `#:`
  consistently; only its own package name on line 1 was a straggler. `t/package.lisp`
  mixed both styles within the same form.
- `%js-compile-pattern`'s (`src/runtime-regex.lisp`) mutually-recursive
  `compile-atom`/`compile-seq`/`compile-alt` closures moved from a
  forward-declare-then-`setf` idiom to `LABELS`, which supports mutual recursion
  natively — no signature or behavior change, just direct calls
  (`(compile-alt pos)`) instead of `(funcall compile-alt pos)` on a variable.
- `js-parse-primary`'s six near-identical constant-literal branches (`true`/`false`/
  `null`/`undefined`/`this`/`super`) now dispatch through a data table
  (`*js-primary-constant-builders*`) plus a CPS-style `consume-and-build` helper,
  mirroring the existing `*js-unary-kw-builders*` precedent in
  `parser-expr-unary.lisp`. `js-parse-import-specifiers`/`js-parse-export-specifiers`'s
  duplicated `{ name [as alias], ... }` parse loop is now one CPS-style shared loop
  (`%js-parse-as-alias-specifiers`) taking a per-caller builder callback — collapsing a
  dead `cond` (both branches did the same thing) along the way.

- `scripts/run-coverage.lisp` also emits `coverage.lcov` (best-effort — see Known
  issues) alongside the existing HTML report.

### Known issues

- `SB-COVER:LCOV-REPORT` (SBCL 2.6.0) signals an internal `TYPE-ERROR` on this
  codebase's coverage data (confirmed via backtrace to be inside SB-COVER's own code,
  not this repository's). `run-coverage.lisp` catches it and continues — the HTML
  report still builds — so `coverage.lcov` and `scripts/coverage-summary.lisp`'s
  aggregate percentage are unavailable until this is fixed upstream or the pinned SBCL
  moves past 2.6.0.

- **Date-time string parsing always assumes UTC, never local time.** A date-TIME string
  with no explicit timezone suffix should parse as the host's LOCAL time (only a
  date-ONLY string is UTC), and an explicit `Z`/`+HH:MM`/`-HH:MM` suffix is currently
  ignored entirely if present — `%js-date-parse-string` (`src/runtime-date.lisp`)
  always encodes via `encode-universal-time`'s zone fixed at `0` (UTC) regardless of
  which ISO form was given. A correct fix needs the same host-timezone projection
  `Date.prototype.getTimezoneOffset`/the Temporal runtime already use, applied
  conditionally on the parsed string's own shape. See `docs/src/compatibility.md`. (The
  sibling "no Invalid Date representation" gap this entry used to also describe is
  FIXED — see the `### Fixed` section.)

### Fixed

- **`Date` had no "Invalid Date" representation at all — any NaN-producing path
  (`new Date(NaN)`, `new Date("garbage")`, `new Date(2020, NaN, 1)`, `d.setTime(NaN)`,
  `d.setFullYear(NaN)`, ...) crashed the whole process with a real
  `FLOATING-POINT-INVALID-OPERATION`, not a graceful JS NaN result.** Found while
  investigating the (initially assumed lower-severity, deferred) "date-time parsing
  assumes UTC" gap below — writing a diagnostic test for `new Date(NaN).getTime()`
  turned up an actual crash, not just wrong output, which raised this from "documented
  gap" to "fix now." `js-date`'s millisecond slot was declared `:type integer`
  (`src/runtime-date.lisp`), structurally incapable of holding `NaN` — every `TRUNCATE`/
  `FLOOR`/`MOD`/`ENCODE-UNIVERSAL-TIME` call reachable from a Date constructor, getter,
  or setter would trap on a NaN argument instead of the IEEE double-float NaN silently
  propagating the way JS expects. Fixed by widening the slot to `:type real` and adding
  `%js-date-invalid-p`/`%js-date-truncate-or-nan` — the latter now used at every
  component-parsing site (`%js-make-date`, `%js-date-utc`, `%js-date-set-time`, every
  `%js-date-set-*` setter, the `define-js-date-cascading-setter` macro) instead of a
  bare `truncate`, and `%js-date-components-to-ms` itself short-circuits to NaN before
  running any of its arithmetic if any component it receives already is NaN.
  `%js-date-parse-string` now returns NaN on a parse failure instead of silently
  substituting `(%js-date-now)` (the CURRENT time) — the real bug the original,
  lower-severity investigation had found, now fixed alongside the crash. Every getter
  (the `define-js-date-getter` macro, `getMilliseconds`, `getTimezoneOffset`) and every
  `toString`-family formatter in `src/runtime-date-methods.lisp` now checks
  `%js-date-invalid-p` first, returning NaN or the literal string `"Invalid Date"`
  (`"null"` for `toJSON`, per spec) instead of decoding a NaN time value. **A genuinely
  separate, pre-existing bug surfaced while testing this fix, fixed alongside it:**
  `%js-to-string` (`src/runtime-property.lisp`) had no case for a `js-date` value at
  all, so `String(date)`/template-literal interpolation/string concatenation of ANY
  Date (valid or not) fell through to a catch-all `PRINC-TO-STRING`, dumping the raw
  `#S(JS-DATE :MS ...)` struct instead of calling `toString()` — added a `%js-date-p`
  branch delegating to `%js-date-to-string`. Verified via `nix build
  .#checks.aarch64-darwin.default`: 1342 → 1351 passed (a real crash reproduced with a
  failing/errored test before the fix, per the established discipline), 0 failed, 0
  errored — including setters, getters, both constructor paths, and every
  `toString`-family method exercised against an Invalid Date.
- `console.log`/`.error`/`.warn` called directly from *inside* a generator body
  (as opposed to by the driver/consumer after receiving a yielded value — e.g.
  a log statement inside a `finally` or `catch` block wrapping a `yield`)
  silently wrote to the wrong stream and never appeared in the caller's
  captured output. `%js-make-generator`'s body runs on its own OS thread
  (`src/runtime-generator.lisp`); that thread's spawn site
  (`%js-gen-chan-ensure-started`) already captured and rebound the driver
  thread's `cl-cc/vm:*vm-state*` and `%js-this` — its own docstring explains
  why: "a new SBCL thread does not inherit another thread's dynamic
  bindings" — but never `*standard-output*`/`*error-output*`, so
  `%js-console-log`'s `(format t ...)` (`t` meaning "whatever
  `*standard-output*` is right now") resolved to the body thread's own
  default stream instead of the one the caller is actually capturing (e.g. a
  test's `%js-run-capture`, or in production, whatever redirection the
  embedding application set up). Found by adding the first tests in this
  suite to call `console.log` directly from within a generator body (see the
  `js-e2e-generator-return-and-throw` entry below) — the two cases exercising
  this crashed with an empty captured string instead of the expected
  console.log output, not a compile error, so nothing short of an actual
  execution assertion would have caught it. This predates this session's
  `cl-concurrent-kit` channel rewrite entirely: the thread-spawning
  architecture is unchanged, only the driver/body hand-off mechanism moved
  from mutex/condvar to channels, and the original code had exactly the same
  gap. Fixed by capturing `*standard-output*`/`*error-output*` alongside
  `*vm-state*`/`this` at the same spawn site and rebinding them in
  `%%js-run-generator-body`. Verified via `nix build
  .#checks.aarch64-darwin.default`: 1320 → 1323 passed (the 3 new test cases
  below — the first two failed against the pre-fix code, confirming this is
  a real fix rather than a speculative hardening), 0 failed.
- `@decorator(...)` with an argument that is itself a call or bracketed
  literal (`@dec(foo(1,2))`, `@dec([1,2])`) failed to parse at all — not
  merely "the decorator has no effect" (already documented as deliberate),
  but a genuine parser corruption breaking the rest of the file.
  `%js-parse-decorator-args`'s (`src/parser-class-helpers.lisp`)
  argument-skipping loop scanned for the next comma or `)` with no nesting
  tracking, so it stopped at the nested call's own inner `)` instead of the
  decorator's outer one, leaving the returned rest-stream pointing at a
  stray, unconsumed `)` — everything parsed after the decorator (the `class`
  keyword, in the test that found this) saw that leftover token first and
  failed. Found the same way as the entry above: adding
  `js-parser-decorators-with-nested-call-arg` (`t/parser-stmt-misc-test.lisp`)
  to check the returned rest-stream position (which the pre-existing
  `js-parser-decorators-with-args` test never did) failed immediately
  against the unfixed parser. Fixed by tracking paren/bracket/brace nesting
  depth in the skip loop and only treating a comma/`)` as an argument
  separator/terminator at depth 0. Verified via `nix build
  .#checks.aarch64-darwin.default`: 1323 → 1324 passed (the one new test
  case — failed against the pre-fix code), 0 failed.
- The identical unguarded-nesting parse bug as the decorator entry directly
  above, in the far more commonly-hit `%js-parse-method-params-body`
  (`src/parser-class-helpers.lisp`, every class method/getter/setter/
  constructor's parameter list): a default parameter value that is itself a
  call or bracketed literal (`class C{m(a,b=foo(1,2)){...}}`) corrupted the
  parser position the same way, producing `JS parse error: expected
  :T-LBRACE but got :T-RPAREN` for the method body that should have parsed
  fine — not a silently-wrong result, a hard failure for the whole class
  declaration. Found the same way: adding a class-method case to the
  existing `js-e2e-class-getters-setters` batch (`t/e2e-advanced-test.lisp`)
  checking that a *second*, unrelated method still parses and runs correctly
  after one with a nested-call default — this is what caught it, not a
  targeted hunt (the search for other instances of the decorator bug's exact
  code shape, `grep -rn "skip tokens until\|until comma" src/*.lisp`, is what
  led to checking this function at all). Both this and the decorator fix now
  share one `%js-skip-balanced-until` helper (paren/bracket/brace
  nesting-depth-aware token skip to a target delimiter set) instead of
  duplicating the same tracking logic twice in the same file. Note: the
  parameter's default *value* is still discarded rather than actually
  applied at the call site (`b`'s default in the test above never runs `foo`
  — the whole default-value expression is skipped, not evaluated) — that is
  a separate, much larger, pre-existing gap (class methods use a simpler,
  incomplete parameter parser than regular functions and arrow functions,
  which do apply defaults correctly via `%js-split-params-by-defaults`
  in `parser-stmt-fn.lisp`), deliberately NOT attempted in this pass; this
  fix only stops the parser from corrupting on such a default's *syntax*.
  Documented for a future dedicated pass in the `project_known_gaps` memory
  note. Verified via `nix build .#checks.aarch64-darwin.default`: 1324
  passed (the earlier decorator fix's count, since the new class-method test
  case had already been added and was failing against the pre-fix parser in
  the immediately preceding build attempt — this build is the one where it
  first passes), 0 failed.
- `static { ... }` class initialisation blocks (ES2022) parsed correctly and
  claimed support in `src/parser-class.lisp`'s own header comment, but never
  ran at all — not a subtly wrong result, a complete no-op.
  `%js-class-static-field-slots` (`src/parser-class-lower.lisp`), the only
  place that threads a static member's initform into the class's
  `%js-make-class` call, filtered for `:js-member-kind :field` specifically;
  a static block's slot was tagged `:js-member-kind :static-block` (a
  distinct kind, correctly, since it isn't a real named field) and simply
  never matched, so it was silently excluded — its initform (the parsed,
  real, executable block body) was built and then discarded, exactly the
  class of bug this codebase's own `remove-unused-definitions`-driven
  investigations elsewhere in this file kept finding: correct code that
  nothing ever calls. Found by adding the first tests anywhere in this suite
  for static blocks (`js-e2e-class-static-blocks`, `t/e2e-advanced-test.lisp`)
  — a coverage gap noticed after finding the two nesting-depth bugs directly
  above, not a targeted hunt for this specific issue. Also found, separately:
  the static-block slot's `:imports` never set `:js-static t` at all (hand-
  built inline instead of going through the `%js-member-kind-metadata`
  helper every other class member uses), which would have kept it excluded
  even after widening the `:js-member-kind` filter. Fixed both: the slot now
  uses `%js-member-kind-metadata`, and `%js-class-static-field-slots`
  accepts `:static-block` alongside `:field`. **A separate, deeper
  limitation surfaced while testing the fix and is NOT fixed here**:
  referencing the class by its own name from inside a static field or static
  block initializer (`class C { static { C.x = 1; } }`) signals an unbound-
  variable error, because static field/block initforms are evaluated as
  plain argument expressions to `%js-make-class` itself — before its result
  is ever bound to the class's name — unlike a method body, which is a
  lambda invoked lazily after the binding exists (this is exactly why the
  pre-existing `js-e2e-static-fields`/`js-e2e-class-self-reference` tests,
  which do reference the class by name, only ever do so from inside method
  bodies). The new tests observe a static block's side effect through an
  outer variable instead, sidestepping this separate issue rather than
  fixing it; documented in `docs/src/compatibility.md` and the
  `project_known_gaps` memory note for a future pass. Verified via `nix
  build .#checks.aarch64-darwin.default`: 1324 → 1325 passed (failed with
  "Unbound global variable: C" against the first version of this fix using
  class-name references, then passed once the tests were rewritten to avoid
  that separate issue — both failure and eventual pass confirmed against a
  real build, not assumed), 0 failed.
- **Private methods (`class C { #secret() {...} } `) were fully broken and,
  worse, not actually private at all.** `%js-lower-class-method-args`
  (`src/parser-class-lower.lisp`) registered every instance method on
  `__prototype__` under its bare name regardless of `:js-private`, so a
  `#secret` method became reachable as ordinary public `obj.secret` (its
  intended access-control silently defeated) while the *correct* syntax,
  `this.#secret()`, failed outright — `%js-class-private-field-get` looks in
  the per-instance `__private__` table, which a method wired only onto
  `__prototype__` was never added to, so the lookup returned `undefined` and
  the subsequent call attempt signalled `Undefined function: :JS-UNDEFINED`.
  Found the same way as the entries above: adding the first tests anywhere
  in this suite that actually CALL a private method or read/write a private
  field through real execution (`js-e2e-private-fields-and-methods`,
  `t/e2e-advanced-test.lisp`) — private *fields* already worked correctly
  (no bug there); only private *methods* were affected, isolated by removing
  test cases one at a time until a single-case build reproduced the failure
  in isolation, then confirmed by reading `%js-class-method-slots`'s filter
  (excludes static/constructor but never checked `:js-private`) alongside
  `%js-class-private-field-set`'s existing per-instance private-field
  mechanism. Fixed by excluding private methods from
  `%js-class-method-slots` entirely (new docstring explains why) and adding
  a parallel `%js-class-private-method-slots`/`%js-lower-class-private-
  method-inits` that stores each private method's closure into the
  instance's own `__private__` table via `%js-class-private-field-set`,
  prepended to the constructor body alongside the pre-existing field inits
  (the exact same per-instance-initialization mechanism, extended to cover
  methods too — a private method's closure is rebuilt once per instance
  rather than shared on the prototype, the natural consequence of using the
  private-field storage). The new test suite includes a case specifically
  asserting `typeof obj.secret === "undefined"` — verifying the fix restores
  genuine privacy, not merely that the `#name()` call syntax works. Verified
  via `nix build .#checks.aarch64-darwin.default`: 1325 → 1326 passed (the
  new test batch — the isolated single-case reproduction failed against the
  pre-fix code with the exact error above, confirmed via a real build before
  attempting the fix), 0 failed.
- **The identical public-leakage bug as the private instance-method entry
  directly above, in static private methods
  (`class C { static #secret() {...} }`).** `%js-class-static-slots`
  (`src/parser-class-lower.lisp`) had the same missing `:js-private` filter
  as the instance-method version — a proactive check added right after
  fixing that one, not a separately-discovered gap. Fixing this one needed a
  different mechanism than the instance case, though: a static method's
  closure can't be stored via a constructor-prologue call (there is no
  per-instance constructor step for STATIC members — they're set once,
  directly on the class object, as part of building it). `%js-make-class`
  (`src/runtime-class.lisp`) gained a second, optional `"@@private-static"`
  marker after the existing `"@@static"` one: name/fn pairs following it are
  routed through `%js-class-private-field-set` on the class object itself
  (`klass`) instead of the ordinary `(setf (gethash name klass) fn)` public
  path, so `C.#secret()` (`this` bound to `C` for any static method call)
  resolves it via `%js-class-private-field-get` exactly like an instance's
  private member does, and `C.secret` stays genuinely undefined.
  `%js-lower-class-static-args` (already existing, previously only used for
  public statics) is reused unchanged for the private-static group too — it
  never cared about privacy, only about building `(name fn ...)` pairs; the
  caller now decides which marker section they land in. Verified via `nix
  build .#checks.aarch64-darwin.default`: 1326 passed both before and after
  this specific fix (the 2 new test cases joined the same existing batch —
  failed against the pre-fix code with the identical "Undefined function:
  :JS-UNDEFINED" error, confirmed via a real build), 0 failed.
- **`String.raw` returned cooked (escapes-processed) output instead of raw
  (as-written) text — the deferred, "most user-visible" gap this memory of
  the project had flagged as needing "threading a second raw text value
  alongside the cooked value through the whole template lexer → parser AST →
  tag-function-call codegen path." Fixed 2026-07-31, done properly (not
  papered over), and it uncovered two more real bugs along the way.**
  `js-lex-template-text-part` (`src/lexer-template.lisp`) now returns both
  COOKED (escapes-processed) and RAW (verbatim source slice) text for every
  template literal text segment; `js-lex-template`'s parts-list text
  elements changed shape from a bare cooked string to `(:text cooked raw)`.
  `%js-parse-tagged-template` (`src/parser-expr-unary.lisp`) now lowers a
  tagged template's first argument through a new
  `%js-make-tagged-template-strings` (`src/runtime-array-core.lisp`), which
  attaches the raw-strings array to the cooked-strings array's new `raw`
  property (per the TC39 tagged-template protocol) instead of passing the
  cooked array alone. Along the way, fixing this surfaced a genuine
  **second bug this codebase never had a test for: `arr.foo = 1` on a JS
  array silently no-op'd.** This runtime represents JS arrays as plain CL
  adjustable vectors, which have no slot for arbitrary named properties —
  `%js-set-prop`'s vector branch had a bare `(t nil)` for any non-index,
  non-"length" key. Since a tagged template's `strings.raw` is exactly this
  same "array with an extra named property" shape, fixing `.raw` for real
  meant fixing this too, not routing around it: added
  `*js-array-extra-properties*`, a lazily-populated EQ-keyed side table
  (`src/runtime-property.lisp`), and wired it into `%js-get-prop`/
  `%js-set-prop`/`%js-in`'s vector branches (own extra property shadows an
  inherited `Array.prototype` method of the same name, matching real JS
  precedence). **A third, independent bug surfaced while verifying the fix
  against a real build: `%js-string-raw` was defined TWICE** — once in
  `src/runtime-string.lisp` (the one this fix edited first) and, unnoticed,
  again in `src/runtime-builtins-globals.lisp`, which loads LATER in
  `cl-cc-javascript.asd`'s `:serial t` order and silently redefined the
  global function, shadowing the fix (and meaning `t/runtime-string-number-
  test.lisp`'s pre-existing `js-rt-string-raw-tag` unit test had, since
  whenever `String.raw` was first wired up, always been exercising the
  OTHER (duplicate, never-fixed, and now-deleted) definition, not the one
  in `runtime-string.lisp` its own file placement suggests). First build
  after the lexer/property-system/lowering changes still failed 5 tests
  with the OLD cooked-output behavior, which is what led to finding the
  duplicate; deleted the stale copy in `runtime-builtins-globals.lisp`,
  keeping the (now-correct) one in `runtime-string.lisp`. Verified via `nix
  build .#checks.aarch64-darwin.default`: 1327 passed, 0 failed (up from
  1326 — new tests below), including a real 5-test regression the
  duplicate-definition bug caused on the first attempt, caught and fixed
  before declaring success.
- **`Array.prototype.sort`/`toSorted` compared `undefined` elements like any
  other value instead of always sorting them to the end, per ECMA-262's
  SortCompare — found and fixed 2026-07-31 (later session), via a "this
  method has zero e2e/undefined-handling test coverage" check, not a
  targeted hunt.** `%js-sort-comparator` (`src/runtime-array-transforms.lisp`)
  built either a lexicographic-string or a raw-JS-comparator predicate and
  handed it straight to `stable-sort` with no special case for
  `+js-undefined+` — so the default comparator placed `undefined` wherever
  its `%js-to-string` value ("undefined") happened to fall lexicographically
  (confirmed with a real failing test: `[undefined,"zebra","apple"].sort()`
  landed `undefined` in the MIDDLE, not last, since "apple" < "undefined" <
  "zebra"), and a custom comparator would have been CALLED with `undefined`
  as an argument at all (the spec requires excluding it from comparison
  entirely — a numeric comparator like `(a,b)=>a-b` would see
  `%js-to-number(undefined)` = NaN and misbehave). Both `%js-array-sort`
  (mutating) and `%js-array-to-sorted` (ES2023 non-mutating) shared this bug
  through the same comparator builder. Fixed with a new shared
  `%js-array-stable-sort-undefined-last`: partitions out every `+js-undefined+`
  element before sorting, stable-sorts only the defined elements, then
  appends the undefined elements back at the end — same shape both callers
  now use instead of calling `stable-sort` directly. Verified via `nix build
  .#checks.aarch64-darwin.default`: 1328 → 1331 passed (a real failing test
  reproduced the bug before the fix, per the established discipline), 0
  failed, including a case asserting a custom comparator is never even
  CALLED with `undefined` (errors if it is) and real end-to-end `.sort()`/
  `.toSorted()` JS-source coverage, both previously entirely absent.
- **Object literals with a non-string-literal key crashed outright — found and
  fixed 2026-07-31 (later session), while auditing Object.keys ordering (the
  investigation that led to it is documented in the entry directly below).**
  `%js-make-object` (`src/runtime-object.lisp`) coerced each key via CL's
  bare `(string k)`, which only accepts a string, symbol, or character and
  signals a real type error on anything else — so `{2: 'b'}` (a perfectly
  ordinary numeric-literal object key) crashed with "2 is not a string
  designator" instead of building `{"2": "b"}` the way real JS's ToString
  key coercion does, and a computed key whose expression evaluates to a
  number/boolean/Symbol (`{[1+1]: 'v'}`) would have hit the identical crash.
  Every OTHER property-key site in this codebase already goes through
  `%js-to-property-key` (`%js-get-prop`/`%js-set-prop`, and the spread-merge
  path for object literals via `%js-object-spread-set` → `%js-set-prop`) —
  `%js-make-object`, used for the plain (non-spread) object-literal case,
  was the one holdout still using the wrong coercion. Fixed by switching to
  `%js-to-property-key`, the same one every other path already uses.
  Confirmed as a real, reproducible crash with a failing test before writing
  the fix. Verified via `nix build .#checks.aarch64-darwin.default`: 1333
  passed, 0 failed, 0 errored (up from 1 errored before the fix).
- **`Object.keys`/`values`/`entries`/`for...in`/`Reflect.ownKeys` never
  applied the ES2015+ [[OwnPropertyKeys]] ordering rule — canonical
  array-index keys (`"0"`, `"1"`, `"2"`, ... no leading zeros) must sort
  NUMERICALLY ASCENDING ahead of every other own key, regardless of
  insertion order. Found and fixed 2026-07-31 (later session), via the same
  "does this extremely common, spec-subtle behavior have ANY test coverage"
  check that found the `sort`/`undefined` bug above — it had none.**
  `%js-object-own-string-property-keys` (`src/runtime-object.lisp`) just
  returned whatever order `maphash` happened to produce, with no ordering
  logic at all — confirmed with a real failing test:
  `Object.keys({2:'b',foo:'bar',1:'a'})` returned `["2","foo","1"]` (raw
  encounter order) instead of the spec-required `["1","2","foo"]`. Fixed by
  partitioning the collected keys into a new `%js-canonical-array-index-key-p`
  predicate's two groups, sorting the array-index group numerically, and
  placing it first — every other key keeps its prior (encounter) order
  after it. The rebuilt result had to stay the same adjustable,
  fill-pointered vector shape the function always returned (not a fresh
  `CONCATENATE` simple-vector) — `%js-object-own-property-keys` (backing
  `Reflect.ownKeys`) `VECTOR-PUSH-EXTEND`s Symbol keys onto this same return
  value, which a non-adjustable vector can't support; caught this by SBCL's
  own compile-time type-derivation warning turning into a real
  `COMPILE-FILE-ERROR` on the first attempt, fixed before declaring success.
  Non-array-index string-key insertion order itself was NOT touched (a
  separate concern) — empirically confirmed already correct via a 5-key
  test (`{z:1,y:2,x:3,w:4,v:5}` → `z,y,x,w,v`) added alongside this fix,
  even though this runtime's plain CL hash tables have no portable
  insertion-order guarantee; worth re-checking if this project's own
  representation of objects ever changes. Verified via `nix build
  .#checks.aarch64-darwin.default`: 1333 → 1334 passed, 0 failed.
- **`for...in` had the identical missing-ordering bug as `Object.keys` above,
  in its own separate implementation, plus a second real bug: it silently
  EXCLUDED getter/setter accessor properties entirely instead of enumerating
  them under their real name.** `%js-for-in` (`src/runtime-control.lisp`)
  did its own raw, unordered `maphash` over OBJ's hash table, only
  filtering internal keys — confirmed with a real failing test:
  `for (k in {2:'b',foo:'bar',1:'a'})` produced `2,foo,1` instead of the
  spec-required `1,2,foo`. Separately, real JS enumerates an accessor
  property (`{get foo(){}}`) via `for...in` exactly like a plain data
  property (object-literal properties, accessors included, are enumerable
  by default) — but `%js-for-in`'s own internal-key filter treated the
  `__get_foo`/`__set_foo` storage keys as opaque internals to skip
  entirely, silently dropping "foo" from enumeration rather than
  recognizing and translating it, unlike `Object.keys`/`values`/`entries`
  (which already correctly translate accessor storage keys to their real
  property name via `%js-object-accessor-property-name`). Fixed by making
  `%js-for-in` share `%js-object-own-string-property-keys` — the same
  ordered, accessor-aware key collector `Object.keys` already used —
  instead of its own separate, less-correct `maphash` loop. This also
  fixed the accessor-property gap for free, as a consequence of sharing the
  logic, not a separately-scoped change. Updated the one existing test that
  had locked in the old (wrong) behavior,
  `js-rt-for-in-skips-accessor-keys` → renamed
  `js-rt-for-in-includes-accessor-keys-under-their-real-name`, now
  asserting "foo" IS enumerated. Verified via `nix build
  .#checks.aarch64-darwin.default`: 1334 → 1335 passed, 0 failed.
  **Deliberately NOT touched: `for...in`'s own docstring already only
  promised "each enumerable string key in OBJ" (own keys) — real JS
  `for...in` also walks the prototype chain, enumerating inherited
  enumerable properties, which this implementation still does not do.**
  Scoped as a separate, likely lower-value gap: real JS class methods are
  themselves non-enumerable on the prototype by spec, so the common
  "class instance in a for...in loop" case is accidentally unaffected;
  only manual `Object.create(protoWithEnumerableOwnProps)`-style
  inheritance chains would actually differ. See `docs/src/compatibility.md`.
- **`JSON.stringify` had the SAME two bugs as `Object.keys`/`for...in` above,
  in its own third separate implementation — found by checking whether this
  sibling shared the pattern immediately after fixing `for...in`.**
  `%js-json-stringify-normalize`'s object branch (`src/runtime-json.lisp`)
  rebuilt a fresh hash-table via a raw `maphash`, filtering internal keys
  via `%js-internal-key-p` and reading each value via the raw stored
  `GETHASH` value — confirmed with real failing tests:
  `JSON.stringify({2:'b',foo:'bar',1:'a'})` produced
  `'{"2":"b","foo":"bar","1":"a"}'` instead of the spec-required
  `'{"1":"a","2":"b","foo":"bar"}'` (array-index keys numerically ascending
  first), and `JSON.stringify({get foo(){return 42}})` produced `'{}'`
  instead of `'{"foo":42}'` — a getter's raw stored value is the accessor
  FUNCTION under an internal `__get_foo` key, filtered out entirely rather
  than recognized, invoked, and serialized under its real name. Real JS
  reads each own enumerable key through `[[Get]]`, which invokes a getter.
  Fixed by replacing the raw `maphash`+`gethash` pair with
  `%js-object-own-string-property-keys` (ordered, accessor-aware — the
  same collector `Object.keys`/`for...in` now share) and `%js-get-prop`
  (invokes a getter correctly, unlike a raw `gethash`) — one coherent fix
  for both bugs, not two separate changes, the same shape as the
  `for...in` fix directly above. Verified via `nix build
  .#checks.aarch64-darwin.default`: 1335 → 1336 passed (ordering fix) →
  1337 passed (getter-serialization test also added and passing), 0 failed
  throughout, each bug confirmed with a real failing test before its fix.
- **`String.prototype.split` with a regex separator never spliced captured
  groups into the result array — a real, previously-undiscovered ES2015+
  gap, found by checking whether `split` had any test coverage for the
  capturing-group case (it had none; the one existing regex-split test
  used a group-free pattern).** Real JS: `"2023-01-15".split(/(-)/)` →
  `["2023","-","01","-","15"]` — each capturing group's matched text (or
  `undefined`, if that group didn't participate in the match) is spliced
  into the result right after the field it separates. `%js-string-split-
  regex` (`src/runtime-regex-api.lisp`) called its compiled matcher with
  `nil` for the GROUPS argument during its separator scan — groups were
  never even captured, let alone spliced in. Fixed by allocating a real
  groups vector per scan attempt (the same `(make-array num-groups
  :initial-element nil)` pattern `%js-regex-exec` already uses) and, once a
  separator match is found, iterating its captured groups into the result
  (`(subseq str (car g) (cdr g))` per participating group, `+js-undefined+`
  for a non-participating one) before continuing the scan — bounded by the
  same LIMIT argument that already bounded plain fields. Verified via `nix
  build .#checks.aarch64-darwin.default`: 1337 → 1339 passed (both new test
  predictions matched exactly on the first attempt), 0 failed.
- **`Number.parseInt`/`Number.parseFloat` were wired to `%js-to-number`
  (generic ToNumber coercion) instead of the actual `parseInt`/`parseFloat`
  implementations — found by noticing a PRE-EXISTING test had locked in the
  wrong behavior (`Number.parseInt('42x')` asserted `"NaN"`, when real JS
  returns `42`) rather than catching the bug.** Per spec, `Number.parseInt`
  and `Number.parseFloat` are literally `===` the global `parseInt`/
  `parseFloat` (the same function object) — `%js-to-number`, by contrast,
  requires the ENTIRE string to be a valid numeric literal and returns NaN
  on any trailing junk, the opposite of `parseInt`/`parseFloat`'s
  "parse-the-longest-valid-prefix" contract. `runtime-builtins-table-
  specs.lisp`'s `"Number.parseInt"`/`"Number.parseFloat"` entries now point
  at `#'%js-parse-int`/`#'%js-parse-float`, the same functions the global
  `"parseInt"`/`"parseFloat"` entries already used. Fixed the pre-existing
  test that had asserted the wrong values (`js-e2e-number-static-methods`,
  `t/e2e-advanced-builtins-test.lisp`) to assert the correct ones.
- **`parseInt` (and, via the fix directly above, `Number.parseInt`) never
  auto-detected a `\"0x\"`/`\"0X\"` hex prefix when no radix is given — a
  real, previously-undiscovered ES5+ gap, found by checking test coverage
  for this specific, commonly-cited spec detail (there was none).** Real
  JS: `parseInt(\"0x1F\")` → `31` (auto-detects hex from the prefix and
  switches radix to 16), but `parseInt(\"0x1F\", 10)` → `0` (an EXPLICIT
  non-16 radix must NOT auto-detect the prefix — parsing stops at the
  leading `\"0\"`, since `\"x\"` isn't a valid base-10 digit). `%js-parse-
  int` (`src/runtime-builtins-globals.lisp`) always defaulted its radix to
  10 with no prefix-sniffing logic at all, so `parseInt(\"0x1F\")` returned
  `0` instead of `31` — confirmed as a real bug with failing tests before
  the fix. Rewrote to manually detect an optional sign, then (only when the
  radix is omitted/0 or explicitly 16) an immediately-following `\"0x\"`/
  `\"0X\"` prefix, switching the effective radix to 16 and advancing past
  it before handing the remainder to `parse-integer` — any OTHER explicit
  radix skips the prefix-detection step entirely, matching spec. Verified
  via `nix build .#checks.aarch64-darwin.default`: 1339 passed (test case
  count grew within existing `deftest-js-run-isolated-batch` batches, which
  report as one test each regardless of internal case count, so the total
  count is unchanged — both batches confirmed passing by name), 0 failed.
- `Array.from({length, 0, 1, ...})` (the array-LIKE, non-iterable code
  path — every existing test used a genuinely iterable source: an array, a
  string, a Set) added to `js-e2e-array-from` (`t/e2e-advanced-builtins-
  test.lisp`). Confirmed correct, not a bug — verified via `nix build
  .#checks.aarch64-darwin.default`: 1339 → 1340 passed, 0 failed. A real
  coverage gap closed either way: this code path (`%js-array-to-length` +
  a `%js-get-prop`-per-index loop, `src/runtime-array-from.lisp`) had never
  been exercised by any test before this.
- Two new cases in `js-e2e-runs-arrays-and-closures` (`t/e2e-core-test.lisp`)
  checking `Array.prototype.concat`'s one-level-only flattening (a nested
  array inside an array argument stays nested; a non-array argument is
  appended whole, never recursively spread) — previously untested beyond a
  single flat-arrays example. Confirmed already correct, not a bug —
  verified via `nix build .#checks.aarch64-darwin.default`: 1340 → 1342
  passed, 0 failed.
- Nine new cases in `js-e2e-date-constructor-and-methods` (`t/e2e-modern-test.lisp`)
  covering Invalid Date across every construction path, getters, `setTime`/
  `setFullYear`, `toString`, and `toJSON` — the cases that found the real crash and the
  `%js-to-string`/Date bug documented in the `### Fixed` entry above. Also updated
  `js-rt-date-parse-string-error` (`t/runtime-date-test.lisp`), a pre-existing unit test
  that had asserted the OLD, wrong "parse failure returns an integer" behavior.
- `%js-compile-pattern`'s recursive-descent regex compiler
  (`compile-atom`/`compile-seq`/`compile-alt`, `src/runtime-regex.lisp`) had no
  recursion-depth bound on group nesting — a pattern with thousands of nested groups
  (`"((((((...))))))"`) could exhaust the control stack (CWE-674 denial of service)
  during `new RegExp(pattern)`/a literal `/pattern/` instead of failing cleanly, the
  same class of risk `with-js-parse-depth` (`parser.lisp`) already guards against for
  the JS statement/expression parser. Added the equivalent guard here:
  `*js-regex-max-compile-depth*` (1000, `src/runtime-regex-combinators.lisp`) and a new
  shared `compile-group-body` helper every group-parsing branch (lookahead,
  non-capturing, named-capturing, capturing) now routes through instead of calling
  `compile-alt` directly — past the limit, compilation signals a normal Lisp error,
  which `%js-make-regex`'s existing `handler-case` already turns into an uncompiled
  (never-matching) `RegExp` rather than propagating a crash. Verified via `nix build
  .#checks.aarch64-darwin.default`: 1330 → 1332 passed (one confirming ordinary nesting
  well under the limit still compiles and captures correctly, one confirming a pattern
  deliberately 1000 groups past the limit fails gracefully instead of hanging/crashing
  the test process — which is exactly what it would have done before this fix), 0
  failed. Alternation chaining (`a|a|a|...`) recurses through a similar unbounded path
  in `compile-alt` and was deliberately left unguarded this pass — a real, if
  independent, residual risk not addressed here to keep this fix scoped to the more
  severe group-nesting case.
- `Promise.any` rejected with a plain object (`{errors, message}`) when every input
  promise rejected, instead of a real `AggregateError` — `err instanceof AggregateError`
  and `err instanceof Error` both failed, unlike real `Promise.any`. `%js-make-
  aggregate-error` (`src/runtime-class.lisp`) already existed, fully correct and unit-
  tested in isolation (`js-rt-make-aggregate-error`, `js-rt-aggregate-error-make`), but
  `%js-promise-any` (`src/runtime-promise.lisp`) built its own plain object with
  matching property names instead of calling it — found via `paredit refactor
  remove-unused-definitions`, which (correctly) flagged `%js-make-aggregate-error` as
  unreferenced from `src/`; tracing *why* surfaced this missing call site rather than
  genuine dead code. Verified via `nix build .#checks.aarch64-darwin.default`: 1337
  passed / 0 failed, with `js-rt-promise-any-all-rejected` strengthened to assert
  `instanceof AggregateError` so this can't silently regress back to a lookalike object.
- `checks.formatting` (nixfmt via treefmt) was failing against `flake.nix`'s own
  `checks.coverage` attribute — a pre-existing drift from before this session, never
  caught because nothing had run the full `nix flake check` (only `checks.default`) in
  a long enough while. Fixed with a plain `nix fmt`; the diff is whitespace-only, no
  semantic change. `nix flake check` (every check: default/tests, docs, compile,
  formatting, coverage) now passes cleanly end to end.
- `TextDecoder.prototype.decode` discarded the entire output string on a single invalid
  UTF-8 byte (`%js-text-decode-octets`, `src/runtime-ops-encoding.lisp`, caught any
  decode error and returned `""`) — despite the decoder's own `"fatal"` property always
  reporting `false` (non-fatal/lenient mode, matching JS's default), which promises
  exactly the opposite: invalid bytes become individual U+FFFD replacement characters
  and decoding continues around them. `decode(new Uint8Array([65, 255, 66]))` returned
  `""`; now returns `"A�B"`. Fixed by passing SBCL's own `:replacement` external-
  format option to `sb-ext:octets-to-string` instead of catching the error after the
  fact — no hand-rolled resync logic needed.
- A computed class member name (`class C { [Symbol.iterator]() {} }`, or a computed
  field/getter/setter/static member) compiled to a method registered under a
  meaningless gensym string, permanently unreachable from JS — silently wrong rather
  than erroring, and uncovered by any existing test (only computed keys on plain object
  literals were tested). The parser now parses the bracketed expression for real and
  lowers it to a runtime `%js-to-property-key` call, matching the normalization
  `obj[expr]` reads already use, instead of discarding it into a gensym.
- `docs/src/quick-start.md` claimed `parse-js-source`'s `:strict-mode`/`:module-p`
  keyword arguments "change how source is read"; neither is actually consulted anywhere
  (`import`/`export` parses unconditionally regardless of `:module-p`, and no
  strict-mode-only restriction is ever rejected). Corrected the documentation and
  recorded the gap honestly in `docs/src/compatibility.md` rather than leaving the false
  claim in place.
- Four dead functions removed (`%js-lex-peek-char`, superseded by `%js-lex-peek-char2`;
  `js-try-consume` and `js-skip-semi`, superseded by `js-skip-semis`; an unused test
  helper) after confirming via whole-repository grep — not just the local file — that
  each had zero remaining callers and was not part of the package's `:export` list
  (several other flagged candidates turned out to be exported runtime-bridge API used
  by generated code, not dead code, and were left alone).
- `%js-lex-peek-char2` itself (the "superseding" function in the entry directly above)
  turned out to have zero callers of its own — a `paredit inspect unused-definitions`
  sweep of `src/*.lisp` caught what a same-file-only grep would not. Removed, along with
  the now-empty `;;; Peek helpers` section header it left behind in `src/lexer.lisp`.
- `\b`/`\B` word boundary (`src/runtime-regex.lisp`) was worse than unimplemented: its
  match predicate resolved to `nil` unconditionally, making it an *always-failing*
  atom — any pattern containing `\b` could never match anything, silently, with no
  error. Found while auditing the regex engine's header comment against what
  `compile-atom` actually handles (prompted by `(?=expr)` lookahead, next entry, also
  being claimed there but not implemented). Now a real zero-width boundary test
  (`%js-regex-word-boundary-p`: exactly one of the characters adjacent to the tested
  position is a word character). `(?=expr)`/`(?!expr)` lookahead didn't exist as a
  parse case at all — `(?=foo)` fell through to the plain capturing-group branch,
  which treated `?=foo` as four literal characters to match, so it could never behave
  like an assertion. Now real zero-width lookahead/negative-lookahead, reusing the
  existing `compile-alt` sub-parser and consuming no input either way. Both verified
  via `nix build .#checks.aarch64-darwin.default` (1313 passed) plus new
  `t/runtime-regex-test.lisp` cases (`js-rt-regex-word-boundary`,
  `js-rt-regex-lookahead`). The same audit found several more gaps the header comment
  claimed — capturing-group extraction, `$1`/`$2` replacement placeholders, named
  groups, lookbehind, `{n,m}` quantifiers — deliberately left unfixed and disclosed
  instead in `docs/src/compatibility.md`; capturing-group extraction in particular is
  a real, nontrivial feature, not a quick follow-up to this fix.

### Removed

- `src/parser-pattern-lower.lisp` (229 lines) and its 7 dedicated tests in
  `t/parser-stmt-pattern-internals-test.lisp` — a whole parallel, superseded
  destructuring-pattern-lowering implementation (`js-lower-binding-pattern`,
  `%js-build-pattern-let`, `%js-build-array-pattern-let`,
  `%js-build-object-pattern-let`, `%js-lower-element`, `%js-lower-property`,
  `%js-make-get-prop`, `%js-wrap-default`) converting a `js-binding-pattern`
  struct (`src/parser-pattern.lisp`) into `ast-let` trees. Real destructuring
  (`const {a,b}=obj`, `const [x,y]=arr`) has always gone through a completely
  separate, actively-used plist-based implementation instead
  (`%js-parse-binding-pattern`/`%js-emit-object-pattern-bindings`/
  `%js-emit-array-pattern-bindings`, `src/parser-stmt-binding.lisp`) —
  confirmed via exact-symbol grep (not substring, which false-positives on
  the similarly-named `%`-prefixed sibling functions) that the whole
  struct-based path was reachable only from its own dedicated test file,
  never from any real statement or expression parser. Found via `paredit
  refactor remove-unused-definitions src/*.lisp`, which flagged
  `js-lower-binding-pattern` specifically (the one symbol in this connected
  component with zero incoming references from *anywhere* in `src/`, not
  even a sibling call) — the rest of the cluster call each other internally,
  which is why the tool's simple per-symbol "is this referenced" check
  didn't also catch them; tracing the one flagged symbol's actual callers
  surfaced the whole dead component by hand. `js-parse-binding-pattern` and
  friends (the struct-CONSTRUCTION side, still in `parser-pattern.lisp`) are
  equally unreachable but were NOT removed this pass — that file also
  defines genuinely load-bearing token-stream primitives (`%js-peek`,
  `%js-consume`, `%js-expect`, ...) the rest of the parser calls, so
  finishing this cleanup needs relocating those first, a separate,
  coordinated pass (see the `project_2026_refactor_goal`/
  `project_known_gaps` memory notes for the full plan — deleting the whole
  file the way this one could be would have broken the parser's compile).
  Verified via `nix build .#checks.aarch64-darwin.default`: 1337 → 1330
  passed (7 orphaned tests removed, none replaced — there was no remaining
  behavior to test once the dead functions were gone), 0 failed.
- `src/parser-pattern.lisp` (384 lines) and its 15 dedicated tests in
  `t/parser-stmt-pattern-internals-test.lisp` — the struct-CONSTRUCTION half
  of the destructuring-pattern implementation left behind by the
  `parser-pattern-lower.lisp` removal above, plus every token-stream helper
  this file defined (`%js-peek`, `%js-peek-type`, `%js-peek-value`,
  `%js-consume`, `%js-expect`, `%js-tok-type`, `%js-tok-value`,
  `%js-ident-sym`, `%js-skip-token!`, `%js-expect!`). The prior entry deferred
  removing this file because an earlier investigation believed those helpers
  were "genuinely load-bearing... called from dozens of sites" elsewhere in
  the parser. Re-checked with precise (non-substring) greps this pass and
  found that belief was based on two false-positive matches: `%js-consume`
  (this file) was being confused with `%js-consume-expected`
  (`src/parser-stmt-binding.lisp`, a distinct, unrelated function whose name
  merely contains `%js-consume` as a substring), and this file's own
  `js-parse-binding-pattern` dispatcher was being confused with
  `%js-parse-binding-pattern` (also `parser-stmt-binding.lisp`, the real,
  live destructuring parser — same substring-of-a-longer-name confusion).
  Once distinguished, every one of this file's 15 definitions — the
  `js-binding-pattern` struct, all 10 token-stream helpers, and the 4
  remaining pattern-parsing functions (`js-parse-array-pattern`,
  `js-parse-object-pattern`, `%js-parse-object-pattern-member`,
  `%js-parse-property-key-string`, `%js-parse-default-expr`,
  `%js-toks-to-ast`, `js-parse-binding-pattern`) — had zero references from
  outside this file except its own dedicated test file. The whole file was
  fully dead, not partially dead as previously believed, so no relocation or
  call-site-renaming surgery was needed — a straight deletion, same as
  `parser-pattern-lower.lisp`. Also fixed two now-stale doc comments this
  turned up: `src/parser.lisp`'s header still listed `parser-pattern.lisp`
  among the files implementing recursive parsers, and still described
  `parse-js-source`'s signature with the `:strict-mode`/`:module-p` keywords
  removed by the entry below this one. `docs/src/architecture.md`'s file/line
  counts and its `cl-cc` monorepo file-diff comparison (re-run against the
  actual pinned commit's source tree, not estimated) updated to match: 94→93
  files, `parser-*` group 20→19, and `parser-pattern.lisp`/
  `parser-pattern-lower.lisp` now correctly listed among the 3 files only the
  monorepo copy still has, alongside `runtime-async.lisp`. Verified via `nix
  build .#checks.aarch64-darwin.default`: 1332 → 1317 passed (15 orphaned
  tests removed, none replaced), 0 failed.
- `parse-js-source`'s `:strict-mode`/`:module-p` keyword arguments and the
  `*js-strict-mode*`/`*js-module-mode*` dynamic variables they set, along with
  `js-program-forms`'s pass-through copies of the same two keywords. All were
  documented as intended scaffolding for real strict-mode/module validation
  (see the "### Fixed" entry above, this file) but nothing ever read either
  variable back — confirmed inert, not merely undertested. Pre-1.0 with no
  compatibility promise (`docs/src/compatibility.md`), and an API surface that
  silently does nothing when exercised is worse than not having it: a caller
  passing `:strict-mode t` expecting real validation got none, with no error to
  say so. `parse-js-module` stays as a plain alias for `parse-js-source` — genuinely
  useful as a self-documenting call site for "this is a module" even though it now
  behaves identically, and it has real callers across `t/parser-stmt-module-test.lisp`
  and `t/e2e-ast-test.lisp`. Implementing real ECMAScript strict-mode semantics
  (octal literal rejection, duplicate parameter names, `eval`/`arguments` assignment,
  and so on) remains a genuine, undone feature — this change only removes the false
  impression that flipping a keyword already did it.

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
