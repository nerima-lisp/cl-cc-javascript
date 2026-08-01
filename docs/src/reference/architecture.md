# Architecture

`src/` is flat and loaded `:serial t`, so the component order in `cl-cc-javascript.asd`
*is* the dependency order. 94 files, about 15,900 lines.

| Group | Files | Role |
|---|---|---|
| `package` / `macros` | 2 | the `defpackage` form and the shared `define-*-table`-style codegen macros every group below builds on |
| `lexer-*` | 5 | source text to token plists |
| `parser-*` | 19 | tokens to cl-cc AST nodes |
| `runtime-*` | 67 | the `%js-*` helpers generated code calls |
| `vm-integration` | 1 | the JS-to-VM callback direction |

## Why the runtime dominates

Two thirds of the file count is runtime. That is not accidental complexity: it is the
size of the JavaScript standard library. Every `Array.prototype` method, every
`Math` function, `Map`/`Set`/`WeakMap`/`WeakSet`, `Promise`, `Date`, `Intl`, `RegExp`,
TypedArrays and `Temporal` each need a Lisp implementation, because the VM has no host
JavaScript engine to delegate to.

The split within `runtime-*` is by builtin family, one or more files each
(`runtime-array-core`, `runtime-array-transforms`, `runtime-array-es2023`, ...), which
keeps individual files near the org's 300-line guideline. The alternative — one
`runtime-array.lisp` of 1,500 lines — was rejected for the usual reason: nothing else in
the file gives you context for the function you are reading.

## Load order constraints

Three positions in the component list are load-bearing and are commented as such in the
`.asd`.

`runtime-bridge-provider` must come after every `%js-*` definition, because it registers
the whole set of helpers with cl-cc as a backend bridge provider. Registering a name
that is not yet fbound would fail at load time.

`vm-integration` is last. It writes into the runtime specials (`*js-apply-fn*`,
`*js-callable-p*`, `*js-apply-with-this-fn*`), so it has to load after `runtime-call`
defines them.

`package` is first, and is the only file containing a `defpackage`. It is 489 lines,
which makes it the largest file in the repository — almost entirely the `:import-from`
and `:export` lists. As a manifest, it is exempt from the file-length guideline; a large
`defpackage` form is one CL idiom to keep as a single file regardless of line count,
unlike a large function or a data-plus-logic file, which genuinely benefit from a split
(see `runtime-regex-combinators.lisp`/`runtime-regex.lisp` for an example of the latter).

## Where the frontend boundary sits

cl-cc-javascript owns tokenizing, parsing, and the JavaScript standard library. It does
not own AST optimisation, code generation, or the VM. The AST types it constructs
(`ast-let`, `ast-call`, `ast-var`, ...) belong to `cl-cc-ast`.

The dependency edge that surprises people is `cl-cc-vm`. A frontend should not need the
virtual machine — but `vm-integration.lisp` does, because `Array.prototype.map` must be
able to invoke a callback that is a compiled VM closure rather than a CL function. That
glue used to live in cl-cc's pipeline, which coupled the pipeline to this package's
internals; moving it here inverted the dependency, at the cost of this one edge. The
pipeline now runs every registered backend's installer without naming any backend.

## Known issue: the duplicate definition in cl-cc

The cl-cc monorepo still contains `packages/javascript/`, a second system with the same
name. The two trees have diverged further with every session: as of this checkout's
pinned `cl-cc` commit, of the 86 files common to both, 70 differ; this checkout also has
8 files the monorepo copy lacks entirely (`macros.lisp`, `runtime-bridge-provider.lisp`,
`runtime-console.lisp`, `runtime-generator.lisp`, `runtime-promise.lisp`,
`runtime-regex-combinators.lisp`, `runtime-temporal-datetime.lisp`, `vm-integration.lisp`),
and the monorepo copy has three
this checkout lacks: `runtime-async.lisp` (an older combined Console/Promise/Generator
file, itself "a simplified synchronous model" per its own header comment; this checkout
split and materially upgraded all three, replacing it — Generator, for one, now runs on
a real second thread rather than a synchronous approximation), and `parser-pattern.lisp`/
`parser-pattern-lower.lisp` (a whole parallel destructuring-pattern parser+lowering
implementation, confirmed fully dead in this checkout and removed — real destructuring
has always gone through the separate, actively-used implementation in
`parser-stmt-binding.lisp`). The `:depends-on` lists also disagree — this repository
declares `:cl-cc-vm`, the monorepo copy does not.

This is a known design problem and is not resolved here. For anything in this
repository, treat `cl-cc-javascript.asd` at the root of *this* checkout as authoritative.
Which copy ASDF actually loads depends on the source registry, so a build that resolves
to the monorepo copy will silently lack the VM integration described above and fall back
to `runtime-async.lisp`'s weaker Generator/Promise model.

## Testing

`t/` holds 32 files and about 7,700 lines, split by concern: lexer tests, parser tests
(declarations, statements), end-to-end execution tests (core, AST-shape, advanced,
modern), and runtime tests per builtin family, each file kept under the org's 500-line
cap (five files that had grown past it were split along their own existing section
boundaries; the largest is now 477 lines). End-to-end tests compile to the VM and
compare captured `console.log` output, so they exercise the real path rather than the
parser alone. See [Development](../project/development.md).
