# Core Concepts

Four ideas explain most of this package: the pipeline stages, the value model, the
runtime bridge, and inline lowering.

## The pipeline

```
JavaScript source
      │  tokenize-js-source
      ▼
  token plists            (:type :T-CONST :value "const")
      │  parse-js-source
      ▼
  cl-cc AST nodes         ast-let, ast-call, ast-var, ...
      │  cl-cc backend
      ▼
  VM program
```

The important thing about the middle arrow is what it does *not* produce. There is no
JavaScript-shaped syntax tree: `parse-js-source` emits cl-cc AST nodes directly, so
`const x = 42` comes back as an `ast-let`, not as a `VariableDeclaration`. Everything
downstream — optimisation, code generation, the VM — is cl-cc's, shared with the other
frontends.

The consequence is that this package cannot be used as a general-purpose JavaScript
parser. If you want an ESTree-shaped tree, this is the wrong library.

## The value model

JavaScript values are represented as ordinary Common Lisp values wherever one exists,
and as keyword sentinels where none does.

| JavaScript | Common Lisp |
|---|---|
| `true` / `false` | `t` / `nil` |
| `null` | `+js-null+`, the keyword `:js-null` |
| `undefined` | `+js-undefined+`, the keyword `:js-undefined` |
| number | `integer` or `double-float` |
| `NaN`, `Infinity`, `-Infinity` | real IEEE-754 doubles (`*js-nan-float*`, `*js-inf-float*`, `*js-neg-inf-float*`) |
| string | `string` |
| array | adjustable `vector` with a fill pointer |
| object | `hash-table` with `equal` test |
| function | CL function, or a cl-cc VM closure object |

Two of these rows cause most of the confusion.

**`nil` is `false`, not `null`.** Both `null` and `undefined` are distinct keyword
sentinels precisely so that they stay distinguishable from `false` and from each other,
which JavaScript requires: `null == undefined` is true but `null === undefined` is
false, and `typeof null` is `"object"` while `typeof undefined` is `"undefined"`.

**`NaN` is a float, not the sentinel.** `+js-nan+` (`:js-nan`) exists, but the value a
`NaN` literal evaluates to is `*js-nan-float*`, a genuine IEEE-754 NaN. Code that tests
for NaN must use `%js-nan-p` rather than comparing against the keyword; `%js-truthy`
carries a comment recording the bug that resulted from getting this wrong. The float
specials are constructed from raw bit patterns rather than from expressions like
`(/ 0.0d0 0.0d0)`, because SBCL would constant-fold that at compile time and trap.

Objects are hash tables, and a *callable* object stores its implementation under the
`"__call__"` key. That is how `%js-typeof` can answer `"function"` for something that is
not a CL function.

## The runtime bridge

Generated code cannot call JavaScript builtins directly, because there is no JavaScript
object graph at runtime — there is a VM. So every builtin is a Lisp function named
`%js-<something>`, and the parser emits calls to it. `Math.max(a, b)` compiles into a
call to `%js-math-max`.

This is why roughly 300 of the 320 exported symbols carry the `%js-` prefix and why they
are exported at all: they are not a public API in the usual sense, they are the names
generated code has to be able to resolve. Treat them as the compiler's ABI.

`src/runtime-bridge-provider.lisp` registers the whole set with cl-cc as a backend
bridge provider, and must load after every `%js-*` function is defined — which is why it
is second-to-last in the `.asd` component list.

`src/vm-integration.lisp` is last. It installs the other direction of the bridge: how
the JavaScript runtime invokes a *VM closure*. `Array.prototype.map` has to be able to
call a callback that was itself compiled from JavaScript, so `*js-apply-fn*` dispatches
on whether the callee is a VM closure, a callable object with `"__call__"`, or a plain
CL function. This is also the reason the production system depends on `cl-cc-vm` at all.

## Inline lowering

There is deliberately no separate AST-lowering pass. JavaScript-specific forms are
lowered by the parser as it goes: `&&=`, `||=` and `??=` are expanded by
`%js-lower-assignment` at parse time, and `this` is emitted directly as `%js-this`.

This matches the PHP frontend's model. An earlier `ast-lower.lisp` existed, was never
called, and drifted out of sync with the parser; it was removed rather than repaired.
The trade-off is that the parser is larger and does two jobs, in exchange for there
being exactly one place where a JS form's shape is decided.

## Parse depth is bounded

`*js-max-parse-depth*` defaults to 2500. Beyond it the parser signals a plain parse
error instead of recursing further, so deeply nested input produces a diagnosable
failure rather than a control-stack exhaustion. Adversarial input is the case this
guards.

## Next

- [Architecture](architecture.md) — how those ideas are distributed across `src/`.
- [API Reference](api-reference.md) — the symbols themselves.
