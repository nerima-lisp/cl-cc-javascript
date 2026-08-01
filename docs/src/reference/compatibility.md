# Compatibility

## Implementation

SBCL only. The runtime uses
[`cl-concurrent-kit`](https://github.com/nerima-lisp/cl-concurrent-kit)'s unbuffered
CSP channels (themselves built directly on `sb-thread`) for the generator coroutine's
suspend/resume hand-off, and constructs IEEE-754 specials from raw bit patterns through
SBCL-specific entry points. There is no
portable fallback path and none is planned; the org's
[coding standard](https://github.com/nerima-lisp/.github/blob/main/CODING_STANDARD.md)
asks packages to name the implementation they target rather than claim portability that
CI does not verify.

## Language coverage

The lexer and parser cover the modern language, including editions well past ES2015:

- **Syntax** — `let`/`const`, arrow functions, classes (including private `#fields`,
  static members, getters and setters), destructuring with defaults and rest, spread,
  template literals, tagged templates, optional chaining (`?.`), nullish coalescing
  (`??`), logical assignment (`&&=`, `||=`, `??=`), `for...of`, `for await...of`,
  generators, `async`/`await`, ES modules (`import`/`export`, `import.meta`,
  `new.target`), labelled statements, `using` declarations, numeric separators, BigInt
  literals, and regular expression literals.
- **Builtins** — `Object`, `Array` (through the ES2023 change-by-copy methods
  `toReversed`, `toSorted`, `toSpliced`, `with`, and `findLast`/`findLastIndex`),
  `String` (through ES2024 `isWellFormed`/`toWellFormed`), `Math`, `JSON`, `Map`, `Set`
  (including the ES2024 set operations `union`, `intersection`, `difference`,
  `symmetricDifference`, `isSubsetOf`, `isSupersetOf`, `isDisjointFrom`), `WeakMap`,
  `WeakSet`, `WeakRef`, `FinalizationRegistry`, `Symbol` and the well-known symbols,
  `Promise` (including `withResolvers`), `Date`, `RegExp`, TypedArrays (including the
  ES2025 `Uint8Array` base64/hex conversions), the ES2025 iterator helpers, and
  `Temporal`.

The authoritative list is [the API reference](api.md), which is generated
against the actual `:export` list.

## Deliberate simplifications

These are known and intentional. They are recorded here because the alternative is that
each one is rediscovered as a bug.

**Promises are synchronous.** A promise is always already settled by the time JavaScript
can observe it, so `.then`, `.catch` and `.finally` run their handler immediately rather
than queuing a microtask. Code whose correctness depends on microtask *ordering* — for
instance interleaving between two promise chains, or a `then` callback observing a
mutation made later in the same synchronous block — will not behave as it does in a real
engine.

**Async generators are not truly asynchronous.** `%js-make-async-generator` delegates to
`%js-make-async`, following from the promise model above.

**`FinalizationRegistry` never fires.** Registrations are tracked so `unregister` has
ECMAScript-compatible observable state, but cleanup callbacks are not run. `WeakRef`
targets are retained, so `deref` never returns `undefined`.

**Date string parsing always treats a date-time string as UTC, never local time.**
Real JS treats a date-ONLY ISO string (`"2024-01-15"`) as UTC, but a date-TIME string with
no explicit timezone suffix (`"2024-01-15T10:00:00"`, no `Z`/`+HH:MM`/`-HH:MM`) as the
host's LOCAL time — a well-known, frequently-cited parsing subtlety. `%js-date-parse-string`
does not distinguish the two cases (nor does it read an explicit timezone suffix at all,
silently ignoring one if present) — every parsed string is encoded as UTC via
`encode-universal-time`'s zone argument fixed at `0`. Deferred alongside the Invalid Date
gap above since a correct fix needs the same host-timezone projection `Date.prototype.
getTimezoneOffset` and the Temporal runtime already use (`runtime-temporal.lisp`), applied
conditionally based on which ISO string form was actually given.

**`Intl` is a stub.** Constructors exist and are callable, so feature detection and
construction succeed, but formatting is not locale-aware. `Date.prototype.toString` and
`toLocaleDateString` are likewise simplified (`YYYY/MM/DD`).

**Temporal's IANA time zone support covers instant → local projection, not local →
instant resolution or zone-aware arithmetic.** `Temporal.Now.timeZoneId` reports the
host's actual IANA zone name (via
[`cl-date-kit`](https://github.com/nerima-lisp/cl-date-kit), reading `TZ` or resolving
the `/etc/localtime` symlink) instead of a hardcoded `"UTC"`, and
`Temporal.Now.zonedDateTimeISO`, `Temporal.Instant.prototype.toZonedDateTimeISO`, and the
`Temporal.ZonedDateTime` epoch-nanoseconds constructor project an absolute instant into
any IANA zone `cl-date-kit`'s tzdata copy recognizes, producing the correct local
wall-clock fields and UTC offset for that instant. That direction is unambiguous — an
instant has exactly one local reading in a given zone — which is what keeps it in scope.
Left unimplemented, deliberately: constructing a `ZonedDateTime` from *local* wall-clock
fields in a non-UTC zone, which is the reverse, potentially ambiguous direction that
requires a daylight-saving gap/overlap disambiguation policy; zone-aware `add`/`subtract`
arithmetic (arithmetic stays plain UTC-second math even when a `ZonedDateTime`'s
displayed zone is not UTC); `Temporal.Now.plainDateTimeISO`/`plainDateISO`/`plainTimeISO`,
which still ignore their `timeZone` argument and always report UTC calendar fields; and
`Temporal.ZonedDateTime.from()` on a string, which still ignores any `[Zone]` bracket in
the input and reports `"UTC"`. All of the implemented paths degrade to the pre-existing
UTC-only behavior, rather than erroring, whenever `cl-date-kit` has no readable IANA
tzdata for a zone name — routine inside a Nix build sandbox, which has neither `TZ` set
nor a `/usr/share/zoneinfo` to read (see `checks.default` in `flake.nix`, which points
`TZDIR` at nixpkgs' `tzdata` package precisely so the zone-aware test coverage still runs
there).

**`Date.prototype.getTimezoneOffset()` shares the same host-zone discovery as Temporal,
with the same UTC fallback.** It reports genuine minutes-west-of-UTC for the host's
discovered IANA zone (negative east of UTC, per JS's own sign convention — the opposite of
a `"+09:00"`-style offset string) instead of a hardcoded `0`, but only when a zone is
actually discoverable; it degrades to `0` under the exact same conditions Temporal does.

**`Proxy` is simplified.** The constructor returns a wrapped object rather than
installing real traps.

**`crypto` is a stub.** Do not use it for anything security-relevant.

**Automatic semicolon insertion is simplified.** ASI consumes a semicolon when one is
present rather than implementing the full restricted-production rules, so a program that
relies on the corner cases of ASI may parse differently than in a browser.

**An abandoned generator leaks a thread.** Generators are real coroutines: the body runs
on its own thread and hands a baton back and forth with the driver, so exactly one of
the two runs at a time and `.next(value)` genuinely resumes at the suspended `yield`.
The cost is that a generator which is never drained — for example one left behind by a
`break` out of a `for...of` — leaves its body thread blocked on the next hand-off
forever. Nothing calls `.return()` on early loop exit to collect it, so it is reclaimed
only at process exit.

**`String.prototype.match`/`matchAll` have a string-pattern path** separate from the
regex engine path (`%js-string-match-regex`, `%js-string-match-all` and friends).

**The regex engine compiles a pattern to a single-pass, non-backtracking matcher
closure** in `runtime-regex.lisp`, not a binding to a host engine. Each quantifier
commits greedily to as many repetitions as it can get and never retries with fewer, so
a pattern shape that genuinely needs backtracking to match (`a*ab` against `"aab"`) can
fail to match where a real backtracking engine would succeed. Lazy quantifiers (`*?`,
`+?`, `{n,m}?`) are a simplification of this same shape: they stop right after their
minimum required repetitions (0 for `*?`, `n` for `{n,m}?`) rather than truly
backtracking to find the shortest match the rest of the pattern needs. `\b`/`\B` word
boundaries and `(?=expr)`/`(?!expr)` lookahead are implemented as zero-width
assertions. Several other pieces the file's own header comment used to claim as
supported were not, discovered and corrected here rather than left as a silent mismatch
between the comment and the code:

- **Capturing groups, numbered and named, are extracted.** `(expr)` and `(?<name>expr)`
  each record their matched span in a `groups` vector threaded through every matcher
  closure, indexed by the order their opening parenthesis appears in the pattern
  (nesting doesn't change this — `((a)(b))` numbers the outer group `1`, then `2`, `3`
  left to right). `match(/(\d+)-(\d+)/)[1]` returns the first captured number as a
  string; a group that didn't participate in the match (the losing side of an
  alternation, or an unexercised iteration under `?`/`*`) reports `undefined`, matching
  JS. A group repeated under a quantifier (`(a)+`) captures its *last* successful
  iteration, the same rule JS itself uses — this engine has no backtracking to begin
  with, so there is only ever one "last" attempt to record. `(?<name>expr)` populates
  the match object's `groups` property (a null-prototype object, `undefined` when the
  pattern has no named groups) in addition to its own numbered slot.
- **`$&`, `$$`, `$1`-`$99`, and `$<name>` replacement placeholders are implemented.**
  `regex-replace-placeholders` expands all four against the match object `%js-regex-exec`
  built; an out-of-range group number, an unterminated `$<name>`, or a `$` followed by
  anything else is copied through literally, per spec. `` $` `` (pre-match) and `$'`
  (post-match) are not implemented — no pattern in this codebase's own test suite or
  documented usage needs them yet.
- **Lookbehind `(?<=expr)`/`(?<!expr)` is not implemented.** Unlike lookahead and named
  groups, which only needed distinguishing `<` from a bare capturing group's opening
  `(`, lookbehind needs variable-length backward matching, which this forward-scanning
  engine has no support for regardless of the `<` parsing question.
- **`{n}`/`{n,}`/`{n,m}` bounded-repetition quantifiers are implemented**, including
  their lazy `?` suffix (with the same simplification as `*?`/`+?` above). `{...}` that
  doesn't parse as a well-formed quantifier — not all digits, a missing minimum before
  the comma, an unclosed brace — falls back to matching its characters literally, the
  same Annex-B-style leniency real JS engines apply outside Unicode mode: `a{3}` matches
  three `a`s, but `a{,3}` (no minimum) matches the five literal characters `a`, `{`,
  `,`, `3`, `}` unchanged.
- **`\xHH` (2 hex digits) and `\uHHHH` (4 hex digits) hex/unicode escapes, and `\f`
  (form feed), are recognized.** These were missing until 2026-07-31: `\xHH`/`\uHHHH`
  fell through to the generic escape handling's "self-denoting" fallback (`\x61`
  matched the literal two-character text `x61`, not the character `a`), and `\f` was
  missing from the same fallback's exception table (matched literal `f`, not a form
  feed) — both broke `RegExp.escape`'s fundamental contract, since it emits exactly
  these forms for punctuation, control characters, and a leading alphanumeric
  character. `new RegExp(RegExp.escape(s)).test(s)` now always holds.

**No strict-mode restrictions are enforced.** Octal literals, duplicate parameter names,
assigning to `eval`/`arguments`, and the other ECMAScript strict-mode-only rejections all
parse successfully; there is no `"use strict"` directive handling and no separate strict
parse mode. `import`/`export` syntax parses unconditionally too — `parse-js-module` is a
plain alias for `parse-js-source`, not a validating module parser (see
[Quick Start](../getting-started.md)). `js-exception` (see [Conditions](conditions.md)) would be
the signal for a real violation if strict-mode validation is implemented later.

**Class method default parameter values are parsed but never applied.**
`class C { m(a, b = 1) {...} }` parses `b` as an ordinary required parameter
and silently discards the `= 1` — calling `new C().m(5)` (omitting `b`)
leaves `b` as `undefined`, not `1`. Destructuring parameters in a method's
parameter list have the same gap. Regular function declarations and arrow
functions apply defaults correctly; only class methods/getters/setters/
constructors go through a separate, simpler parameter parser
(`%js-parse-method-params-body`) that was never extended to match. The
syntax itself always parses without error (as of this fix — see the
[release notes](https://github.com/nerima-lisp/cl-cc-javascript/releases); a
nested-call or bracketed-literal default like
`m(a, b = foo(1,2))` previously corrupted the parser entirely instead of
merely ignoring the default's value).

**A static field or `static { ... }` block initializer cannot reference the
class by its own name.** `class C { static { C.x = 1; } }` signals an
unbound-variable error. The class's own construction call
(`%js-make-class(...)`) evaluates every static field/block initform as one
of its own arguments, before the result is ever bound to the class's name —
unlike a method body, which is a lambda invoked lazily, well after that
binding exists. Referencing the class by name from inside a *method* works
fine; only a field/block initializer that runs during construction itself
is affected. Static field/block initializers currently work correctly as
long as they don't need to see the class object under construction (plain
literals, or references to anything already in scope from outside the
class).

**`for...in` only enumerates OBJ's own enumerable string keys, never inherited ones.**
Real JS `for...in` also walks the prototype chain, enumerating inherited enumerable
properties. In practice this rarely matters: real JS class methods are themselves
non-enumerable on the prototype by spec, so iterating a class instance with `for...in`
is unaffected — the gap only shows up for manual `Object.create(protoWithEnumerable
OwnProps)`-style prototype chains where the prototype itself carries enumerable data
properties, an uncommon pattern. `Object.keys`/`values`/`entries` are unaffected by this
note — they are own-properties-only by spec, exactly what this runtime already does.

## Resource limits

`*js-max-parse-depth*` bounds expression and statement nesting at 2500. Past that the
parser signals a parse error rather than overflowing the control stack. This is a
deliberate guard against adversarial input; raise the parameter if you have legitimate
input that is more deeply nested.

## Stability

The package is at `0.1.0` and has no release tag yet. Nothing here is covered by a
compatibility promise, and the `%js-*` runtime bridge in particular is the compiler's
internal ABI — it changes whenever the code generator changes. See
[Versioning](https://github.com/nerima-lisp/.github/blob/main/RELEASE_STANDARD.md) for
the org-wide policy.
