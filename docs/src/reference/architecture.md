# Architecture

`src/` is flat and loaded `:serial t`, so the component order in `cl-cc-javascript.asd`
*is* the dependency order. 95 files, about 16,300 lines.

| Group | Files | Role |
|---|---|---|
| `package` / `macros` | 2 | the `defpackage` form and the shared `define-*-table`-style codegen macros every group below builds on |
| `lexer*.lisp` | 5 | source text to token plists |
| `parser*.lisp` | 20 | tokens to cl-cc AST nodes |
| `runtime*.lisp` | 67 | the `%js-*` helpers generated code calls |
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

## Compiler source boundary

The umbrella compiler consumes `cl-cc-javascript` as an external system from this
repository. The child flake pins `cl-cc-ast`, `cl-cc-bootstrap`, `cl-cc-parse`,
`cl-cc-runtime`, and `cl-cc-vm` as separate source inputs and does not depend on the
umbrella checkout. This keeps the dependency flow one-way from the umbrella to the
frontend and then to compiler components.

## Testing

`t/` holds 34 files and about 8,100 lines, split by concern: lexer, parser, AST shape,
pipeline execution, and runtime tests per builtin family. Each file stays under the
org's 500-line cap. The child test system runs lexer, parser, AST-shape, and runtime
tests. Pipeline execution cases remain in their source files but are excluded from the
child system because they require the umbrella compiler pipeline. See
[Development](../project/development.md).
