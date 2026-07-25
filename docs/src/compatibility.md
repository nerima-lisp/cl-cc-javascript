# Compatibility

## Implementation

SBCL only. The runtime uses `sb-thread` for the generator coroutine and constructs
IEEE-754 specials from raw bit patterns through SBCL-specific entry points. There is no
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

The authoritative list is [the API reference](api-reference.md), which is generated
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

**`Intl` is a stub.** Constructors exist and are callable, so feature detection and
construction succeed, but formatting is not locale-aware. `Date.prototype.toString` and
`toLocaleDateString` are likewise simplified (`YYYY/MM/DD`).

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

**The regex engine is a native NFA** in `runtime-regex.lisp`, not a binding to a host
engine. Lazy quantifiers are handled with a simplified match-shortest-first strategy.

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
