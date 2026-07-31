# API Reference

Every symbol exported from the `cl-cc/javascript` package, in the order and under the
groupings `src/package.lisp` itself uses for its `:export` list. Lambda lists are
reproduced from the definitions in `src/`.

## Reading this page

Symbols prefixed with `%js-` are **runtime bridge helpers**. They are not an API to
call by hand: the parser emits calls to them, and cl-cc's backend resolves them
through the bridge provider registered in `src/runtime-bridge-provider.lisp`. They are
exported because generated code has to name them. The handful of symbols without the
prefix — `tokenize-js-source`, `parse-js-source`, `parse-js-module`, `js-program-forms`
and the `js-exception` condition — are the surface most callers want; see
[Quick Start](quick-start.md).

Two conventions hold across the whole page, so they are not repeated per entry.

**Signals.** A runtime helper signals `js-exception` wherever the ECMAScript
specification defines a thrown error, and otherwise propagates standard Common Lisp
conditions (`type-error`, `division-by-zero`) for inputs the code generator does not
produce. Entries that deviate say so. See [Conditions](conditions.md).

**Undefined.** `+js-undefined+` (the keyword `:js-undefined`) is the sentinel for
JavaScript `undefined`, and `+js-null+` (`:js-null`) is `null`. Neither is `nil`: `nil`
and `t` are JavaScript `false` and `true`. See
[Core Concepts](core-concepts.md#the-value-model).

## Entry points

### `tokenize-js-source`

```lisp
(cl-cc/javascript:tokenize-js-source source)
```

Tokenize JavaScript SOURCE string into a list of token plists.

Defined in `src/lexer-operator.lisp`.

### `parse-js-source`

```lisp
(cl-cc/javascript:parse-js-source source)
```

Parse a JavaScript SOURCE string and return a list of top-level AST nodes.

Defined in `src/parser.lisp`.

### `parse-js-module`

```lisp
(cl-cc/javascript:parse-js-module source)
```

Parse a JavaScript ES module SOURCE string. Identical to `parse-js-source` today
(import/export syntax already parses unconditionally); kept as its own named entry
point for callers who mean "this is a module", ahead of any future module-only
validation.

Defined in `src/parser.lisp`.

### `js-program-forms`

```lisp
(cl-cc/javascript:js-program-forms source)
```

Parse JS SOURCE prepending the standard-globals prelude.

Defined in `src/runtime-builtins-prelude.lisp`.

### `%js-make-console`

```lisp
(cl-cc/javascript:%js-make-console)
```

Construct the JS `console' global object from *%js-console-method-specs*.

Defined in `src/runtime-console.lisp`.

## JS-specific unary / binary operators

### `%js-typeof`

```lisp
(cl-cc/javascript:%js-typeof x)
```

Return JS typeof string for X.

Defined in `src/runtime.lisp`.

### `%js-instanceof`

```lisp
(cl-cc/javascript:%js-instanceof obj constructor)
```

JS instanceof.

Defined in `src/runtime.lisp`.

### `%js-void`

```lisp
(cl-cc/javascript:%js-void x)
```

JS void operator.

Defined in `src/runtime-class.lisp`.

### `%js-delete`

```lisp
(cl-cc/javascript:%js-delete obj key)
```

JS delete operator.

Defined in `src/runtime-property.lisp`.

### `%js-in`

```lisp
(cl-cc/javascript:%js-in key obj)
```

JS 'key in obj'.

Defined in `src/runtime-property.lisp`.

### `%js-loose-eq`

```lisp
(cl-cc/javascript:%js-loose-eq a b)
```

JS == with type coercion.

Defined in `src/runtime.lisp`.

### `%js-strict-eq`

```lisp
(cl-cc/javascript:%js-strict-eq a b)
```

JS === strict equality, no coercion.

Defined in `src/runtime.lisp`.

### `%js-nullish-coalesce`

```lisp
(cl-cc/javascript:%js-nullish-coalesce a b)
```

JS ?? operator.

Defined in `src/runtime-class.lisp`.

### `%js-optional-chain`

```lisp
(cl-cc/javascript:%js-optional-chain obj key)
```

Return nil if OBJ is null/undefined, else %js-get-prop.

Defined in `src/runtime-property.lisp`.

### `%js-optional-call`

```lisp
(cl-cc/javascript:%js-optional-call func &rest args)
```

Call FUNC with ARGS unless FUNC is null/undefined.

Defined in `src/runtime-property.lisp`.

### `%js-optional-method-call`

```lisp
(cl-cc/javascript:%js-optional-method-call obj key &rest args)
```

obj?.method(args) — short-circuit to undefined when OBJ is null/undefined.

Defined in `src/runtime-property.lisp`.

### `%js-spread`

```lisp
(cl-cc/javascript:%js-spread iterable)
```

Expand iterable into a CL list (for use with apply).

Defined in `src/runtime-class.lisp`.

## Destructuring

### `%js-destructure-array`

```lisp
(cl-cc/javascript:%js-destructure-array arr &rest indices-and-defaults)
```

Array-destructuring rest helper.

Defined in `src/runtime-object-ops.lisp`.

### `%js-destructure-object`

```lisp
(cl-cc/javascript:%js-destructure-object obj &rest keys-and-defaults)
```

Object-destructuring rest helper.

Defined in `src/runtime-object-ops.lisp`.

## String / template helpers

### `%js-template-string`

```lisp
(cl-cc/javascript:%js-template-string parts)
```

Concatenate template literal parts (already evaluated).

Defined in `src/runtime-property.lisp`.

### `%js-to-string`

```lisp
(cl-cc/javascript:%js-to-string x)
```

JS ToString coercion.

Defined in `src/runtime-property.lisp`.

## Property access / object construction

### `%js-get-prop`

```lisp
(cl-cc/javascript:%js-get-prop obj key)
```

Get property KEY from JS object/array/string.

Defined in `src/runtime-property.lisp`.

### `%js-set-prop`

```lisp
(cl-cc/javascript:%js-set-prop obj key value)
```

Set property KEY on JS object/array.

Defined in `src/runtime-property.lisp`.

### `%js-make-object`

```lisp
(cl-cc/javascript:%js-make-object &rest key-value-pairs)
```

Create a JS object from alternating key/value args.

Defined in `src/runtime-object.lisp`.

### `%js-make-array`

```lisp
(cl-cc/javascript:%js-make-array &rest elements)
```

Create a JS array from ELEMENTS.

Defined in `src/runtime-array-core.lisp`.

## Private class fields

### `%js-class-private-field-get`

```lisp
(cl-cc/javascript:%js-class-private-field-get obj field-name)
```

Read a private field from OBJ.

Defined in `src/runtime-class.lisp`.

### `%js-class-private-field-set`

```lisp
(cl-cc/javascript:%js-class-private-field-set obj field-name value)
```

Write a private field on OBJ.

Defined in `src/runtime-class.lisp`.

### `%js-has-private-field`

```lisp
(cl-cc/javascript:%js-has-private-field obj field-name)
```

True if OBJ has the named private field.

Defined in `src/runtime-class.lisp`.

## Promise type

### `js-promise-p`

```lisp
(cl-cc/javascript:js-promise-p object)
```

True when OBJECT is a `js-promise` structure.

Defined in `src/runtime-promise.lisp`.

### `js-promise-value`

```lisp
(cl-cc/javascript:js-promise-value promise)
```

Settled value of PROMISE.

Defined in `src/runtime-promise.lisp`.

### `js-promise-rejected-p`

```lisp
(cl-cc/javascript:js-promise-rejected-p promise)
```

True when PROMISE settled as rejected.

Defined in `src/runtime-promise.lisp`.

## Async / generator

### `%js-yield`

```lisp
(cl-cc/javascript:%js-yield &optional (value +js-undefined+))
```

Suspend the active generator body, handing VALUE to its consumer, and resume with whatever the next .next(v)/.throw(e)/.return(v) call sends — returning V, raising E at this point, or unwinding out to end the body.

Defined in `src/runtime-generator.lisp`.

### `%js-yield-from`

```lisp
(cl-cc/javascript:%js-yield-from iterable)
```

yield* — drain ITERABLE into the active generator by reusing %js-for-of, so each drained element suspends/resumes exactly like a direct yield.

Defined in `src/runtime-generator.lisp`.

### `%js-await`

```lisp
(cl-cc/javascript:%js-await promise)
```

Synchronously unwrap a promise (for simplified async model).

Defined in `src/runtime-promise.lisp`.

### `%js-async`

```lisp
(cl-cc/javascript:%js-async thunk)
```

Execute THUNK, wrapping result/exception in a promise.

Defined in `src/runtime-promise.lisp`.

### `%js-make-async`

```lisp
(cl-cc/javascript:%js-make-async fn)
```

Wrap FN as an async function: invoking it returns a resolved/rejected promise.

Defined in `src/runtime-generator.lisp`.

### `%js-make-async-generator`

```lisp
(cl-cc/javascript:%js-make-async-generator fn)
```

Simplified async generator: delegates to %js-make-async.

Defined in `src/runtime-generator.lisp`.

### `%js-make-generator`

```lisp
(cl-cc/javascript:%js-make-generator body-fn)
```

Return a JS iterator object that runs BODY-FN as a suspend/resume coroutine: each .next()/.throw()/.return() call resumes it for exactly one step and blocks until it yields, returns, or throws.

Defined in `src/runtime-generator.lisp`.

### `%js-generator-next`

```lisp
(cl-cc/javascript:%js-generator-next gen &optional (value +js-undefined+))
```

Advance GEN by one step (delegates to its 'next' method).

Defined in `src/runtime-generator.lisp`.

### `%js-wrap-generator-body`

```lisp
(cl-cc/javascript:%js-wrap-generator-body body-fn)
```

Return a function that, when called, produces a fresh generator from BODY-FN.

Defined in `src/runtime-generator.lisp`.

## Temporal API (ES2026)

### `*js-temporal-global*`

```lisp
cl-cc/javascript:*js-temporal-global*
```

The Temporal global namespace (immutable datetime API, ES2026).

Defined in `src/runtime-temporal-global.lisp`.

### `%js-temporal-instant`

```lisp
(cl-cc/javascript:%js-temporal-instant unix-seconds)
```

epochMilliseconds.

Defined in `src/runtime-temporal.lisp`.

### `%js-temporal-plain-date`

```lisp
(cl-cc/javascript:%js-temporal-plain-date year month day)
```

month.

Defined in `src/runtime-temporal.lisp`.

### `%js-temporal-plain-time`

```lisp
(cl-cc/javascript:%js-temporal-plain-time hour minute second &optional (ms 0) (us 0) (ns 0))
```

minute.

Defined in `src/runtime-temporal-datetime.lisp`.

### `%js-temporal-plain-datetime`

```lisp
(cl-cc/javascript:%js-temporal-plain-datetime year month day hour minute second)
```

month.

Defined in `src/runtime-temporal-datetime.lisp`.

### `%js-temporal-zoned-datetime`

```lisp
(cl-cc/javascript:%js-temporal-zoned-datetime year month day hour minute second tz)
```

month.

Defined in `src/runtime-temporal-datetime.lisp`.

### `%js-temporal-duration`

```lisp
(cl-cc/javascript:%js-temporal-duration &key (years 0) (months 0) (weeks 0) (days 0) (hours 0) (minutes 0) (seconds 0) (milliseconds 0) (microseconds 0) (nanoseconds 0))
```

months.

Defined in `src/runtime-temporal-duration.lisp`.

### `%js-temporal-plain-year-month`

```lisp
(cl-cc/javascript:%js-temporal-plain-year-month year month)
```

month.

Defined in `src/runtime-temporal.lisp`.

### `%js-temporal-plain-month-day`

```lisp
(cl-cc/javascript:%js-temporal-plain-month-day month day)
```

day.

Defined in `src/runtime-temporal.lisp`.

## ES2025 TypedArray

### `%js-uint8-from-hex`

```lisp
(cl-cc/javascript:%js-uint8-from-hex hex-str)
```

Uint8Array.fromHex(string) — ES2025.

Defined in `src/runtime-typed-arrays-encoding.lisp`.

### `%js-uint8-from-base64`

```lisp
(cl-cc/javascript:%js-uint8-from-base64 b64-str &optional opts)
```

Uint8Array.fromBase64(string) — ES2025.

Defined in `src/runtime-typed-arrays-encoding.lisp`.

### `%js-uint8-to-hex`

```lisp
(cl-cc/javascript:%js-uint8-to-hex ta)
```

Uint8Array.prototype.toHex() — ES2025.

Defined in `src/runtime-typed-arrays-encoding.lisp`.

### `%js-uint8-to-base64`

```lisp
(cl-cc/javascript:%js-uint8-to-base64 ta &optional opts)
```

Uint8Array.prototype.toBase64() — ES2025.

Defined in `src/runtime-typed-arrays-encoding.lisp`.

## Exception handling

### `js-exception`

```lisp
(cl-cc/javascript:js-exception)
```

Condition signalled by `%js-throw` for a JavaScript `throw`. The thrown JS value is read back with `js-exception-value`.

Defined in `src/runtime-control.lisp`.

### `js-exception-value`

```lisp
(cl-cc/javascript:js-exception-value condition)
```

The JS value carried by a JS-EXCEPTION.

Defined in `src/runtime-control.lisp`.

### `%js-throw`

```lisp
(cl-cc/javascript:%js-throw value)
```

Signal `js-exception` carrying VALUE. This is the JavaScript `throw` statement.

Defined in `src/runtime-control.lisp`.

### `%js-try-catch-finally`

```lisp
(cl-cc/javascript:%js-try-catch-finally try-thunk catch-thunk finally-thunk)
```

Execute TRY-THUNK; on JS exception call CATCH-THUNK with the value.

Defined in `src/runtime-control.lisp`.

## Iteration protocols

### `%js-for-in`

```lisp
(cl-cc/javascript:%js-for-in obj body-fn)
```

Execute BODY-FN for each enumerable string key in OBJ.

Defined in `src/runtime-control.lisp`.

### `%js-for-of`

```lisp
(cl-cc/javascript:%js-for-of iterable body-fn)
```

Execute BODY-FN for each element of ITERABLE.

Defined in `src/runtime-control.lisp`.

### `%js-for-await-of`

```lisp
(cl-cc/javascript:%js-for-await-of iterable body-fn)
```

Synchronous for-await-of: resolves each element through %js-await eagerly.

Defined in `src/runtime-promise.lisp`.

## Module system

### `%js-new`

```lisp
(cl-cc/javascript:%js-new constructor &optional (args nil))
```

Instantiate a JS class.

Defined in `src/runtime-class.lisp`.

### `%js-import`

```lisp
(cl-cc/javascript:%js-import module-name &optional with-opts)
```

Dynamic import host hook returning a resolved module namespace promise.

Defined in `src/runtime-module.lisp`.

### `%js-import-meta`

```lisp
(cl-cc/javascript:%js-import-meta)
```

Return host metadata for import.meta.

Defined in `src/runtime-module.lisp`.

### `%js-export`

```lisp
(cl-cc/javascript:%js-export kind value &optional from-module declaration-names)
```

Record a module export and return VALUE.

Defined in `src/runtime-module.lisp`.

### `%js-debugger`

```lisp
(cl-cc/javascript:%js-debugger)
```

JS debugger statement — no-op.

Defined in `src/runtime-class.lisp`.

### `%js-new-target`

```lisp
(cl-cc/javascript:%js-new-target)
```

Return new.target — undefined outside a constructor.

Defined in `src/runtime-ops.lisp`.

## Operator helpers (bitwise, shift, unary, increment)

### `%js-bitwise-not`

```lisp
(cl-cc/javascript:%js-bitwise-not x)
```

JS ~x: flip all 32 bits then sign-extend.

Defined in `src/runtime-ops.lisp`.

### `%js-bitwise-or`

```lisp
(cl-cc/javascript:%js-bitwise-or a b)
```

JS `a | b`. Both operands are coerced to 32-bit integers and the result is sign-extended.

Defined in `src/runtime-ops.lisp`.

### `%js-bitwise-and`

```lisp
(cl-cc/javascript:%js-bitwise-and a b)
```

JS `a & b`. Both operands are coerced to 32-bit integers and the result is sign-extended.

Defined in `src/runtime-ops.lisp`.

### `%js-bitwise-xor`

```lisp
(cl-cc/javascript:%js-bitwise-xor a b)
```

JS `a ^ b`. Both operands are coerced to 32-bit integers and the result is sign-extended.

Defined in `src/runtime-ops.lisp`.

### `%js-shift-left`

```lisp
(cl-cc/javascript:%js-shift-left a b)
```

JS a << b (b taken mod 32).

Defined in `src/runtime-ops.lisp`.

### `%js-shift-right`

```lisp
(cl-cc/javascript:%js-shift-right a b)
```

JS a >> b, arithmetic (signed).

Defined in `src/runtime-ops.lisp`.

### `%js-unsigned-shift-right`

```lisp
(cl-cc/javascript:%js-unsigned-shift-right a b)
```

JS a >>> b, logical (unsigned, always non-negative).

Defined in `src/runtime-ops.lisp`.

### `%js-unary-plus`

```lisp
(cl-cc/javascript:%js-unary-plus x)
```

JS unary +: numeric coercion.

Defined in `src/runtime-ops.lisp`.

### `%js-postfix-inc`

```lisp
(cl-cc/javascript:%js-postfix-inc val)
```

Value of the postfix `x++` expression, which is the operand *before* incrementing. The store itself is emitted separately by the parser.

Defined in `src/runtime-ops.lisp`.

### `%js-postfix-dec`

```lisp
(cl-cc/javascript:%js-postfix-dec val)
```

Value of the postfix `x--` expression, which is the operand *before* decrementing. The store itself is emitted separately by the parser.

Defined in `src/runtime-ops.lisp`.

### `%js-prefix-inc`

```lisp
(cl-cc/javascript:%js-prefix-inc val)
```

JS `++x`: coerce VAL to a number and add one.

Defined in `src/runtime-ops.lisp`.

### `%js-prefix-dec`

```lisp
(cl-cc/javascript:%js-prefix-dec val)
```

JS `--x`: coerce VAL to a number and subtract one.

Defined in `src/runtime-ops.lisp`.

## Class / accessor helpers

### `%js-accessor`

```lisp
(cl-cc/javascript:%js-accessor kind fn)
```

Tag FN as a get/set accessor descriptor.

Defined in `src/runtime-ops.lisp`.

### `%js-make-regex`

```lisp
(cl-cc/javascript:%js-make-regex pattern &optional (flags ""))
```

Create a JS RegExp from PATTERN and FLAGS strings.

Defined in `src/runtime-regex-api.lisp`.

### `%js-assign-pattern`

```lisp
(cl-cc/javascript:%js-assign-pattern lhs rhs)
```

Fallback for destructuring assignment to a non-simple LHS: returns RHS.

Defined in `src/runtime-ops.lisp`.

## Resource management

### `%js-using-register`

```lisp
(cl-cc/javascript:%js-using-register resource)
```

Register RESOURCE for disposal at scope exit (simplified: identity).

Defined in `src/runtime-ops.lisp`.

## Console helpers

### `%js-console-log`

```lisp
(cl-cc/javascript:%js-console-log &rest args)
```

JS `console.log`. Writes each argument to standard output as a JS string, space separated, and returns `+js-undefined+`.

Defined in `src/runtime-console.lisp`.

### `%js-console-error`

```lisp
(cl-cc/javascript:%js-console-error &rest args)
```

JS `console.error`. As `%js-console-log`, but writes to `*error-output*`.

Defined in `src/runtime-console.lisp`.

### `%js-console-warn`

```lisp
(cl-cc/javascript:%js-console-warn &rest args)
```

JS `console.warn`. As `%js-console-log`, but writes to `*error-output*` behind a `Warning: ` prefix.

Defined in `src/runtime-console.lisp`.

## Truthiness / nullish helpers

### `%js-truthy`

```lisp
(cl-cc/javascript:%js-truthy x)
```

JS truthiness: false, 0, NaN, "", null, undefined are falsy.

Defined in `src/runtime.lisp`.

### `%js-not-nullish`

```lisp
(cl-cc/javascript:%js-not-nullish x)
```

True if X is not null or undefined.

Defined in `src/runtime.lisp`.

## Global number-parsing helpers (referenced in js-program-forms)

### `%js-parse-int`

```lisp
(cl-cc/javascript:%js-parse-int s &optional (radix 10))
```

Parse integer from string S in the given RADIX (default 10).

Defined in `src/runtime-builtins-globals.lisp`.

### `%js-parse-float`

```lisp
(cl-cc/javascript:%js-parse-float s)
```

JS parseFloat: parse the LONGEST leading numeric prefix of S (so "3.14abc" -> 3.14), or NaN when there is no leading number.

Defined in `src/runtime-builtins-globals.lisp`.

### `%js-is-nan`

```lisp
(cl-cc/javascript:%js-is-nan x)
```

Return true if X converts to NaN.

Defined in `src/runtime-builtins-globals.lisp`.

### `%js-is-finite`

```lisp
(cl-cc/javascript:%js-is-finite x)
```

Return true if X is finite (not NaN, not Infinity).

Defined in `src/runtime-builtins-globals.lisp`.

## Built-in dispatch table

### `*js-builtin-map*`

```lisp
cl-cc/javascript:*js-builtin-map*
```

Dispatch table from JS built-in name to CL function.

Defined in `src/runtime-builtins-table.lisp`.

## Math built-ins

### `%js-math-abs`

```lisp
(cl-cc/javascript:%js-math-abs x)
```

Bridge for `Math.abs`.

Defined in `src/runtime-math.lisp`.

### `%js-math-ceil`

```lisp
(cl-cc/javascript:%js-math-ceil x)
```

Bridge for `Math.ceil`.

Defined in `src/runtime-math.lisp`.

### `%js-math-floor`

```lisp
(cl-cc/javascript:%js-math-floor x)
```

Bridge for `Math.floor`.

Defined in `src/runtime-math.lisp`.

### `%js-math-round`

```lisp
(cl-cc/javascript:%js-math-round x)
```

Bridge for `Math.round`.

Defined in `src/runtime-math.lisp`.

### `%js-math-max`

```lisp
(cl-cc/javascript:%js-math-max &rest args)
```

Bridge for `Math.max`.

Defined in `src/runtime-math.lisp`.

### `%js-math-min`

```lisp
(cl-cc/javascript:%js-math-min &rest args)
```

Bridge for `Math.min`.

Defined in `src/runtime-math.lisp`.

### `%js-math-pow`

```lisp
(cl-cc/javascript:%js-math-pow base exp)
```

Bridge for `Math.pow`.

Defined in `src/runtime-math.lisp`.

### `%js-math-sqrt`

```lisp
(cl-cc/javascript:%js-math-sqrt x)
```

Bridge for `Math.sqrt`.

Defined in `src/runtime-math.lisp`.

### `%js-math-log`

```lisp
(cl-cc/javascript:%js-math-log x)
```

Bridge for `Math.log`.

Defined in `src/runtime-math.lisp`.

### `%js-math-log2`

```lisp
(cl-cc/javascript:%js-math-log2 x)
```

Bridge for `Math.log2`.

Defined in `src/runtime-math.lisp`.

### `%js-math-log10`

```lisp
(cl-cc/javascript:%js-math-log10 x)
```

Bridge for `Math.log10`.

Defined in `src/runtime-math.lisp`.

### `%js-math-exp`

```lisp
(cl-cc/javascript:%js-math-exp x)
```

Bridge for `Math.exp`.

Defined in `src/runtime-math.lisp`.

### `%js-math-sin`

```lisp
(cl-cc/javascript:%js-math-sin x)
```

Bridge for `Math.sin`.

Defined in `src/runtime-math.lisp`.

### `%js-math-cos`

```lisp
(cl-cc/javascript:%js-math-cos x)
```

Bridge for `Math.cos`.

Defined in `src/runtime-math.lisp`.

### `%js-math-tan`

```lisp
(cl-cc/javascript:%js-math-tan x)
```

Bridge for `Math.tan`.

Defined in `src/runtime-math.lisp`.

### `%js-math-asin`

```lisp
(cl-cc/javascript:%js-math-asin x)
```

Bridge for `Math.asin`.

Defined in `src/runtime-math.lisp`.

### `%js-math-acos`

```lisp
(cl-cc/javascript:%js-math-acos x)
```

Bridge for `Math.acos`.

Defined in `src/runtime-math.lisp`.

### `%js-math-atan`

```lisp
(cl-cc/javascript:%js-math-atan x)
```

Bridge for `Math.atan`.

Defined in `src/runtime-math.lisp`.

### `%js-math-atan2`

```lisp
(cl-cc/javascript:%js-math-atan2 y x)
```

Bridge for `Math.atan2`.

Defined in `src/runtime-math.lisp`.

### `%js-math-hypot`

```lisp
(cl-cc/javascript:%js-math-hypot &rest args)
```

Bridge for `Math.hypot`.

Defined in `src/runtime-math.lisp`.

### `%js-math-trunc`

```lisp
(cl-cc/javascript:%js-math-trunc x)
```

Bridge for `Math.trunc`.

Defined in `src/runtime-math.lisp`.

### `%js-math-sign`

```lisp
(cl-cc/javascript:%js-math-sign x)
```

Bridge for `Math.sign`.

Defined in `src/runtime-math.lisp`.

### `%js-math-clz32`

```lisp
(cl-cc/javascript:%js-math-clz32 x)
```

Count leading zeros in the 32-bit representation.

Defined in `src/runtime-math.lisp`.

### `%js-math-fround`

```lisp
(cl-cc/javascript:%js-math-fround x)
```

Bridge for `Math.fround`.

Defined in `src/runtime-math.lisp`.

### `%js-math-f16round`

```lisp
(cl-cc/javascript:%js-math-f16round x)
```

Bridge for `Math.f16round`.

Defined in `src/runtime-math.lisp`.

### `%js-math-imul`

```lisp
(cl-cc/javascript:%js-math-imul a b)
```

32-bit integer multiply, sign-extended.

Defined in `src/runtime-math.lisp`.

### `%js-math-random`

```lisp
(cl-cc/javascript:%js-math-random)
```

Bridge for `Math.random`.

Defined in `src/runtime-math.lisp`.

## Array built-ins

### `%js-array-for-each`

```lisp
(cl-cc/javascript:%js-array-for-each arr fn)
```

Call FN(element, index, arr) for each element of ARR; returns undefined (JS Array.prototype.forEach).

Defined in `src/runtime-array-core.lisp`.

### `%js-array-push`

```lisp
(cl-cc/javascript:%js-array-push arr val)
```

Append VAL to ARR; return new length.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-pop`

```lisp
(cl-cc/javascript:%js-array-pop arr)
```

Remove and return last element, or undefined.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-shift`

```lisp
(cl-cc/javascript:%js-array-shift arr)
```

Remove and return first element.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-unshift`

```lisp
(cl-cc/javascript:%js-array-unshift arr &rest items)
```

Prepend ITEMS to ARR; return new length.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-splice`

```lisp
(cl-cc/javascript:%js-array-splice arr start &optional (delete-count nil delete-count-supplied-p) &rest items)
```

Splice: remove DELETE-COUNT elements at START, insert ITEMS.

Defined in `src/runtime-array-transforms.lisp`.

### `%js-array-slice`

```lisp
(cl-cc/javascript:%js-array-slice arr &optional (start 0) (end nil))
```

Return a new array slice.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-concat`

```lisp
(cl-cc/javascript:%js-array-concat arr &rest others)
```

Concatenate ARR with OTHERS.

Defined in `src/runtime-array-transforms.lisp`.

### `%js-array-join`

```lisp
(cl-cc/javascript:%js-array-join arr &optional (sep ","))
```

Join array elements with separator.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-reverse`

```lisp
(cl-cc/javascript:%js-array-reverse arr)
```

Reverse ARR in place; return ARR.

Defined in `src/runtime-array-transforms.lisp`.

### `%js-array-sort`

```lisp
(cl-cc/javascript:%js-array-sort arr &optional compare-fn)
```

Sort ARR in place; return ARR.

Defined in `src/runtime-array-transforms.lisp`.

### `%js-array-flat`

```lisp
(cl-cc/javascript:%js-array-flat arr &optional (depth 1))
```

Flatten ARR up to DEPTH levels.

Defined in `src/runtime-array-transforms.lisp`.

### `%js-array-flat-map`

```lisp
(cl-cc/javascript:%js-array-flat-map arr fn)
```

Map FN then flatten one level.

Defined in `src/runtime-array-transforms.lisp`.

### `%js-array-map`

```lisp
(cl-cc/javascript:%js-array-map arr fn)
```

Map FN over ARR, returning new array.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-filter`

```lisp
(cl-cc/javascript:%js-array-filter arr fn)
```

Filter ARR by predicate FN.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-reduce`

```lisp
(cl-cc/javascript:%js-array-reduce arr fn &optional (init +js-undefined+))
```

Bridge for `Array.prototype.reduce`.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-reduce-right`

```lisp
(cl-cc/javascript:%js-array-reduce-right arr fn &optional (init +js-undefined+))
```

Bridge for `Array.prototype.reduceRight`.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-find`

```lisp
(cl-cc/javascript:%js-array-find arr fn)
```

Return first element satisfying FN, or undefined.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-find-index`

```lisp
(cl-cc/javascript:%js-array-find-index arr pred)
```

Bridge for `Array.prototype.findIndex`.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-every`

```lisp
(cl-cc/javascript:%js-array-every arr fn)
```

Bridge for `Array.prototype.every`.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-some`

```lisp
(cl-cc/javascript:%js-array-some arr fn)
```

Bridge for `Array.prototype.some`.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-includes`

```lisp
(cl-cc/javascript:%js-array-includes arr val &optional (from 0))
```

True if ARR contains VAL starting from FROM.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-index-of`

```lisp
(cl-cc/javascript:%js-array-index-of arr val &optional (from 0))
```

Return first index of VAL in ARR, or -1.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-last-index-of`

```lisp
(cl-cc/javascript:%js-array-last-index-of arr val &optional (from nil))
```

Return last index of VAL in ARR, or -1.

Defined in `src/runtime-array-core.lisp`.

### `%js-array-fill`

```lisp
(cl-cc/javascript:%js-array-fill arr value &optional (start 0) (end nil))
```

Fill ARR[start..end] with VALUE.

Defined in `src/runtime-array-transforms.lisp`.

### `%js-array-copy-within`

```lisp
(cl-cc/javascript:%js-array-copy-within arr target &optional (start 0) (end nil))
```

Copy elements within ARR.

Defined in `src/runtime-array-transforms.lisp`.

### `%js-array-entries`

```lisp
(cl-cc/javascript:%js-array-entries arr)
```

Bridge for `Array.prototype.entries`.

Defined in `src/runtime-array-iterators.lisp`.

### `%js-array-keys`

```lisp
(cl-cc/javascript:%js-array-keys arr)
```

Bridge for `Array.prototype.keys`.

Defined in `src/runtime-array-iterators.lisp`.

### `%js-array-from`

```lisp
(cl-cc/javascript:%js-array-from items &optional (map-fn +js-undefined+) (this-arg +js-undefined+))
```

JS Array.from — collects an iterable or array-like object into a fresh array.

Defined in `src/runtime-array-from.lisp`.

### `%js-array-from-async`

```lisp
(cl-cc/javascript:%js-array-from-async items &optional (map-fn +js-undefined+) (this-arg +js-undefined+))
```

ES2024 Array.fromAsync in the runtime's synchronous Promise model.

Defined in `src/runtime-array-from.lisp`.

### `%js-array-is-array`

```lisp
(cl-cc/javascript:%js-array-is-array x)
```

True if X is a JS array.

Defined in `src/runtime-array-from.lisp`.

## Object built-ins

### `%js-object-keys`

```lisp
(cl-cc/javascript:%js-object-keys obj)
```

Bridge for `Object.keys`.

Defined in `src/runtime-object.lisp`.

### `%js-object-values`

```lisp
(cl-cc/javascript:%js-object-values obj)
```

Bridge for `Object.values`.

Defined in `src/runtime-object.lisp`.

### `%js-object-entries`

```lisp
(cl-cc/javascript:%js-object-entries obj)
```

Bridge for `Object.entries`.

Defined in `src/runtime-object.lisp`.

### `%js-object-assign`

```lisp
(cl-cc/javascript:%js-object-assign target &rest sources)
```

Copy all enumerable own properties from SOURCES to TARGET.

Defined in `src/runtime-object.lisp`.

### `%js-object-create`

```lisp
(cl-cc/javascript:%js-object-create proto)
```

Create object with PROTO as prototype.

Defined in `src/runtime-object.lisp`.

### `%js-object-define-property`

```lisp
(cl-cc/javascript:%js-object-define-property obj key descriptor)
```

Bridge for `Object.defineProperty`.

Defined in `src/runtime-builtins-object.lisp`.

### `%js-object-define-properties`

```lisp
(cl-cc/javascript:%js-object-define-properties obj props)
```

Bridge for `Object.defineProperties`.

Defined in `src/runtime-builtins-object.lisp`.

### `%js-object-get-prototype-of`

```lisp
(cl-cc/javascript:%js-object-get-prototype-of obj)
```

Return prototype of OBJ.

Defined in `src/runtime-object.lisp`.

### `%js-object-set-prototype-of`

```lisp
(cl-cc/javascript:%js-object-set-prototype-of obj proto)
```

Set prototype of OBJ.

Defined in `src/runtime-object.lisp`.

### `%js-object-get-own-property-descriptor`

```lisp
(cl-cc/javascript:%js-object-get-own-property-descriptor obj key)
```

Bridge for `Object.getOwnPropertyDescriptor`.

Defined in `src/runtime-builtins-object.lisp`.

### `%js-object-has-own`

```lisp
(cl-cc/javascript:%js-object-has-own obj key)
```

True if OBJ has own property KEY.

Defined in `src/runtime-object.lisp`.

### `%js-object-from-entries`

```lisp
(cl-cc/javascript:%js-object-from-entries iterable)
```

Create object from [key, value] iterable.

Defined in `src/runtime-object.lisp`.

### `%js-object-is`

```lisp
(cl-cc/javascript:%js-object-is a b)
```

Object.is — like === but handles NaN and -0.

Defined in `src/runtime-object-ops.lisp`.

## String built-ins (ES2015+, ES2024)

### `%js-string-substring`

```lisp
(cl-cc/javascript:%js-string-substring s start &optional end)
```

JS String.prototype.substring (clamps, swaps start>end, differs from slice).

Defined in `src/runtime-string.lisp`.

### `%js-string-to-well-formed`

```lisp
(cl-cc/javascript:%js-string-to-well-formed s)
```

ES2024 String.prototype.toWellFormed — replace lone surrogates with U+FFFD.

Defined in `src/runtime-string.lisp`.

### `%js-string-is-well-formed`

```lisp
(cl-cc/javascript:%js-string-is-well-formed s)
```

ES2024 String.prototype.isWellFormed — return true iff S contains no lone surrogates.

Defined in `src/runtime-string.lisp`.

### `%js-string-to-locale-lower-case`

```lisp
(cl-cc/javascript:%js-string-to-locale-lower-case s)
```

Bridge for `String.prototype.toLocaleLowerCase`.

Defined in `src/runtime-string.lisp`.

### `%js-string-to-locale-upper-case`

```lisp
(cl-cc/javascript:%js-string-to-locale-upper-case s)
```

Bridge for `String.prototype.toLocaleUpperCase`.

Defined in `src/runtime-string.lisp`.

### `%js-string-locale-compare`

```lisp
(cl-cc/javascript:%js-string-locale-compare s other &optional locales options)
```

ES2015 String.prototype.localeCompare — returns -1, 0, or 1.

Defined in `src/runtime-string.lisp`.

### `%js-string-length`

```lisp
(cl-cc/javascript:%js-string-length s)
```

Bridge for the `String.prototype.length` accessor.

Defined in `src/runtime-string.lisp`.

### `%js-string-char-at`

```lisp
(cl-cc/javascript:%js-string-char-at s i)
```

Bridge for `String.prototype.charAt`.

Defined in `src/runtime-string.lisp`.

### `%js-string-char-code-at`

```lisp
(cl-cc/javascript:%js-string-char-code-at s i)
```

Bridge for `String.prototype.charCodeAt`.

Defined in `src/runtime-string.lisp`.

### `%js-string-concat`

```lisp
(cl-cc/javascript:%js-string-concat s &rest others)
```

Bridge for `String.prototype.concat`.

Defined in `src/runtime-string.lisp`.

### `%js-string-includes`

```lisp
(cl-cc/javascript:%js-string-includes s sub &optional (from 0))
```

JS String.prototype.includes.

Defined in `src/runtime-string.lisp`.

### `%js-string-starts-with`

```lisp
(cl-cc/javascript:%js-string-starts-with s prefix &optional (pos 0))
```

Bridge for `String.prototype.startsWith`.

Defined in `src/runtime-string.lisp`.

### `%js-string-ends-with`

```lisp
(cl-cc/javascript:%js-string-ends-with s suffix &optional (end-pos nil))
```

Bridge for `String.prototype.endsWith`.

Defined in `src/runtime-string.lisp`.

### `%js-string-index-of`

```lisp
(cl-cc/javascript:%js-string-index-of s sub &optional (from 0))
```

JS String.prototype.indexOf.

Defined in `src/runtime-string.lisp`.

### `%js-string-last-index-of`

```lisp
(cl-cc/javascript:%js-string-last-index-of s sub &optional (from nil))
```

JS String.prototype.lastIndexOf.

Defined in `src/runtime-string.lisp`.

### `%js-string-match`

```lisp
(cl-cc/javascript:%js-string-match s pattern)
```

Simplified string match (pattern is a string).

Defined in `src/runtime-string.lisp`.

### `%js-string-match-all`

```lisp
(cl-cc/javascript:%js-string-match-all s pattern)
```

Simplified matchAll — returns array of match arrays.

Defined in `src/runtime-string.lisp`.

### `%js-string-replace`

```lisp
(cl-cc/javascript:%js-string-replace s pattern replacement)
```

JS String.prototype.replace (string pattern only).

Defined in `src/runtime-string.lisp`.

### `%js-string-replace-all`

```lisp
(cl-cc/javascript:%js-string-replace-all s pattern replacement)
```

JS String.prototype.replaceAll.

Defined in `src/runtime-string.lisp`.

### `%js-string-search`

```lisp
(cl-cc/javascript:%js-string-search s pattern)
```

Return index of first match or -1.

Defined in `src/runtime-string.lisp`.

### `%js-string-slice`

```lisp
(cl-cc/javascript:%js-string-slice s &optional (start 0) (end nil))
```

JS String.prototype.slice.

Defined in `src/runtime-string.lisp`.

### `%js-string-split`

```lisp
(cl-cc/javascript:%js-string-split s &optional (sep nil) (limit nil))
```

JS String.prototype.split.

Defined in `src/runtime-string.lisp`.

### `%js-string-trim`

```lisp
(cl-cc/javascript:%js-string-trim s)
```

Bridge for `String.prototype.trim`.

Defined in `src/runtime-string.lisp`.

### `%js-string-trim-start`

```lisp
(cl-cc/javascript:%js-string-trim-start s)
```

Bridge for `String.prototype.trimStart`.

Defined in `src/runtime-string.lisp`.

### `%js-string-trim-end`

```lisp
(cl-cc/javascript:%js-string-trim-end s)
```

Bridge for `String.prototype.trimEnd`.

Defined in `src/runtime-string.lisp`.

### `%js-string-pad-start`

```lisp
(cl-cc/javascript:%js-string-pad-start s len &optional (fill " "))
```

Bridge for `String.prototype.padStart`.

Defined in `src/runtime-string.lisp`.

### `%js-string-pad-end`

```lisp
(cl-cc/javascript:%js-string-pad-end s len &optional (fill " "))
```

Bridge for `String.prototype.padEnd`.

Defined in `src/runtime-string.lisp`.

### `%js-string-repeat`

```lisp
(cl-cc/javascript:%js-string-repeat s n)
```

Repeat S n times.

Defined in `src/runtime-string.lisp`.

### `%js-string-to-lower-case`

```lisp
(cl-cc/javascript:%js-string-to-lower-case s)
```

Bridge for `String.prototype.toLowerCase`.

Defined in `src/runtime-string.lisp`.

### `%js-string-to-upper-case`

```lisp
(cl-cc/javascript:%js-string-to-upper-case s)
```

Bridge for `String.prototype.toUpperCase`.

Defined in `src/runtime-string.lisp`.

### `%js-string-normalize`

```lisp
(cl-cc/javascript:%js-string-normalize s &optional (form "NFC"))
```

JS String.prototype.normalize for NFC, NFD, NFKC, and NFKD.

Defined in `src/runtime-string.lisp`.

### `%js-string-from-char-code`

```lisp
(cl-cc/javascript:%js-string-from-char-code &rest codes)
```

String.fromCharCode / String.fromCodePoint — both map code-char over their args.

Defined in `src/runtime-string.lisp`.

### `%js-string-from-code-point`

```lisp
(cl-cc/javascript:%js-string-from-code-point &rest codes)
```

Bridge for `String.fromCodePoint`.

Defined in `src/runtime-string.lisp`.

### `%js-string-raw`

```lisp
(cl-cc/javascript:%js-string-raw strings &rest subs)
```

String.raw`...` tag: join raw literal portions with substitution values.

Defined in `src/runtime-builtins-globals.lisp`.

### `%js-string-at`

```lisp
(cl-cc/javascript:%js-string-at s index)
```

JS String.prototype.at (negative indexing).

Defined in `src/runtime-string.lisp`.

## Promise built-ins

### `%js-promise-resolve`

```lisp
(cl-cc/javascript:%js-promise-resolve value)
```

Create a resolved promise.

Defined in `src/runtime-promise.lisp`.

### `%js-promise-reject`

```lisp
(cl-cc/javascript:%js-promise-reject reason)
```

Create a rejected promise.

Defined in `src/runtime-promise.lisp`.

### `%js-promise-all`

```lisp
(cl-cc/javascript:%js-promise-all promises)
```

Resolve all promises; reject on first rejection.

Defined in `src/runtime-promise.lisp`.

### `%js-promise-all-settled`

```lisp
(cl-cc/javascript:%js-promise-all-settled promises)
```

Return array of status objects for all promises.

Defined in `src/runtime-promise.lisp`.

### `%js-promise-any`

```lisp
(cl-cc/javascript:%js-promise-any promises)
```

Resolve with first fulfillment; reject if all reject.

Defined in `src/runtime-promise.lisp`.

### `%js-promise-race`

```lisp
(cl-cc/javascript:%js-promise-race promises)
```

Return the first settled promise.

Defined in `src/runtime-promise.lisp`.

### `%js-promise-with-resolvers`

```lisp
(cl-cc/javascript:%js-promise-with-resolvers)
```

Return object with promise, resolve, reject.

Defined in `src/runtime-promise.lisp`.

### `%js-promise-then`

```lisp
(cl-cc/javascript:%js-promise-then promise on-fulfilled &optional on-rejected)
```

Chain a promise through on-fulfilled / on-rejected callbacks.

Defined in `src/runtime-promise.lisp`.

### `%js-promise-finally`

```lisp
(cl-cc/javascript:%js-promise-finally promise on-finally)
```

Run ON-FINALLY regardless of outcome.

Defined in `src/runtime-promise.lisp`.

## Set built-ins

### `js-set-p`

```lisp
(cl-cc/javascript:js-set-p object)
```

True when OBJECT is a `js-set` structure.

Defined in `src/runtime-collections-set.lisp`.

### `%js-make-set`

```lisp
(cl-cc/javascript:%js-make-set)
```

Create a new empty ordered JS Set.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-add`

```lisp
(cl-cc/javascript:%js-set-add s val)
```

Bridge for `Set.prototype.add`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-delete`

```lisp
(cl-cc/javascript:%js-set-delete s val)
```

Bridge for `Set.prototype.delete`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-has`

```lisp
(cl-cc/javascript:%js-set-has s val)
```

Bridge for `Set.prototype.has`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-clear`

```lisp
(cl-cc/javascript:%js-set-clear s)
```

Bridge for `Set.prototype.clear`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-size`

```lisp
(cl-cc/javascript:%js-set-size s)
```

Bridge for the `Set.prototype.size` accessor.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-entries`

```lisp
(cl-cc/javascript:%js-set-entries s)
```

Bridge for `Set.prototype.entries`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-keys`

```lisp
(cl-cc/javascript:%js-set-keys s)
```

Bridge for `Set.prototype.keys`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-for-each`

```lisp
(cl-cc/javascript:%js-set-for-each s fn)
```

Bridge for `Set.prototype.forEach`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-union`

```lisp
(cl-cc/javascript:%js-set-union a b)
```

Bridge for `Set.prototype.union`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-intersection`

```lisp
(cl-cc/javascript:%js-set-intersection a b)
```

Bridge for `Set.prototype.intersection`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-difference`

```lisp
(cl-cc/javascript:%js-set-difference a b)
```

Bridge for `Set.prototype.difference`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-symmetric-difference`

```lisp
(cl-cc/javascript:%js-set-symmetric-difference a b)
```

Bridge for `Set.prototype.symmetricDifference`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-is-subset-of`

```lisp
(cl-cc/javascript:%js-set-is-subset-of a b)
```

Bridge for `Set.prototype.isSubsetOf`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-is-disjoint-from`

```lisp
(cl-cc/javascript:%js-set-is-disjoint-from a b)
```

Bridge for `Set.prototype.isDisjointFrom`.

Defined in `src/runtime-collections-set.lisp`.

### `%js-set-is-superset-of`

```lisp
(cl-cc/javascript:%js-set-is-superset-of a b)
```

Bridge for `Set.prototype.isSupersetOf`.

Defined in `src/runtime-collections-set.lisp`.

## Map built-ins (ES2015+)

### `%js-map-p`

```lisp
(cl-cc/javascript:%js-map-p x)
```

True when X is a JS `Map`.

Defined in `src/runtime-map.lisp`.

### `%js-make-map`

```lisp
(cl-cc/javascript:%js-make-map &optional pairs)
```

Create a JS Map, optionally seeded from an iterable of [key,val] pairs.

Defined in `src/runtime-map.lisp`.

### `%js-map-set`

```lisp
(cl-cc/javascript:%js-map-set m key value)
```

Set KEY → VALUE in Map M, preserving insertion order.

Defined in `src/runtime-map.lisp`.

### `%js-map-get`

```lisp
(cl-cc/javascript:%js-map-get m key)
```

Return value at KEY in Map M, or undefined.

Defined in `src/runtime-map.lisp`.

### `%js-map-has`

```lisp
(cl-cc/javascript:%js-map-has m key)
```

True if Map M has KEY.

Defined in `src/runtime-map.lisp`.

### `%js-map-delete`

```lisp
(cl-cc/javascript:%js-map-delete m key)
```

Remove KEY from Map M; return true if it existed.

Defined in `src/runtime-map.lisp`.

### `%js-map-clear`

```lisp
(cl-cc/javascript:%js-map-clear m)
```

Remove all entries from Map M.

Defined in `src/runtime-map.lisp`.

### `%js-map-size`

```lisp
(cl-cc/javascript:%js-map-size m)
```

Bridge for the `Map.prototype.size` accessor.

Defined in `src/runtime-map.lisp`.

### `%js-map-keys`

```lisp
(cl-cc/javascript:%js-map-keys m)
```

Bridge for `Map.prototype.keys`.

Defined in `src/runtime-map.lisp`.

### `%js-map-values`

```lisp
(cl-cc/javascript:%js-map-values m)
```

Bridge for `Map.prototype.values`.

Defined in `src/runtime-map.lisp`.

### `%js-map-entries`

```lisp
(cl-cc/javascript:%js-map-entries m)
```

Bridge for `Map.prototype.entries`.

Defined in `src/runtime-map.lisp`.

### `%js-map-for-each`

```lisp
(cl-cc/javascript:%js-map-for-each m fn)
```

Call FN(value, key, map) for each entry in insertion order.

Defined in `src/runtime-map.lisp`.

## WeakMap built-ins (ES2015+)

### `%js-weak-map-p`

```lisp
(cl-cc/javascript:%js-weak-map-p x)
```

True when X is a JS `WeakMap`.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-make-weak-map`

```lisp
(cl-cc/javascript:%js-make-weak-map)
```

Construct an empty JS `WeakMap`.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-weak-map-set`

```lisp
(cl-cc/javascript:%js-weak-map-set m key value)
```

Bridge for `WeakMap.prototype.set`.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-weak-map-get`

```lisp
(cl-cc/javascript:%js-weak-map-get m key)
```

Bridge for `WeakMap.prototype.get`.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-weak-map-has`

```lisp
(cl-cc/javascript:%js-weak-map-has m key)
```

Bridge for `WeakMap.prototype.has`.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-weak-map-delete`

```lisp
(cl-cc/javascript:%js-weak-map-delete m key)
```

Bridge for `WeakMap.prototype.delete`.

Defined in `src/runtime-weak-collections.lisp`.

## WeakSet built-ins (ES2015+)

### `%js-weak-set-p`

```lisp
(cl-cc/javascript:%js-weak-set-p x)
```

True when X is a JS `WeakSet`.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-make-weak-set`

```lisp
(cl-cc/javascript:%js-make-weak-set)
```

Construct an empty JS `WeakSet`.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-weak-set-add`

```lisp
(cl-cc/javascript:%js-weak-set-add s value)
```

Bridge for `WeakSet.prototype.add`.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-weak-set-has`

```lisp
(cl-cc/javascript:%js-weak-set-has s value)
```

Bridge for `WeakSet.prototype.has`.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-weak-set-delete`

```lisp
(cl-cc/javascript:%js-weak-set-delete s value)
```

Bridge for `WeakSet.prototype.delete`.

Defined in `src/runtime-weak-collections.lisp`.

## WeakRef / FinalizationRegistry (ES2021)

### `%js-make-weak-ref`

```lisp
(cl-cc/javascript:%js-make-weak-ref target)
```

Create a WeakRef.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-weak-ref-deref`

```lisp
(cl-cc/javascript:%js-weak-ref-deref wr)
```

`WeakRef.prototype.deref`. Returns the referent, which this portable runtime always retains.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-make-finalization-registry`

```lisp
(cl-cc/javascript:%js-make-finalization-registry callback)
```

Construct a JS `FinalizationRegistry` holding CALLBACK. Registrations are tracked so `unregister` has observable state, but cleanup callbacks are never run by this runtime.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-finreg-register`

```lisp
(cl-cc/javascript:%js-finreg-register reg target held-value &optional (unregister-token +js-undefined+))
```

Register TARGET with HELD-VALUE.

Defined in `src/runtime-weak-collections.lisp`.

### `%js-finreg-unregister`

```lisp
(cl-cc/javascript:%js-finreg-unregister reg token)
```

Remove all registrations associated with TOKEN, returning true if any existed.

Defined in `src/runtime-weak-collections.lisp`.

## Symbol (ES2015+)

### `%js-symbol-p`

```lisp
(cl-cc/javascript:%js-symbol-p x)
```

True when X is a JS `Symbol`.

Defined in `src/runtime-symbol.lisp`.

### `%js-make-symbol`

```lisp
(cl-cc/javascript:%js-make-symbol &optional (description +js-undefined+))
```

JS Symbol([description]) — always returns a fresh unique symbol.

Defined in `src/runtime-symbol.lisp`.

### `%js-symbol-for`

```lisp
(cl-cc/javascript:%js-symbol-for key)
```

Symbol.for(key) — returns the registered symbol for KEY, creating it if absent.

Defined in `src/runtime-symbol.lisp`.

### `%js-symbol-key-for`

```lisp
(cl-cc/javascript:%js-symbol-key-for sym)
```

Symbol.keyFor(sym) — return the registry key for SYM, or undefined.

Defined in `src/runtime-symbol.lisp`.

### `%js-symbol-to-string`

```lisp
(cl-cc/javascript:%js-symbol-to-string sym)
```

Symbol.prototype.toString → 'Symbol(desc)'.

Defined in `src/runtime-symbol.lisp`.

### `%js-symbol-description`

```lisp
(cl-cc/javascript:%js-symbol-description sym)
```

Symbol.prototype.description getter.

Defined in `src/runtime-symbol.lisp`.

### `%js-symbol-as-key`

```lisp
(cl-cc/javascript:%js-symbol-as-key sym)
```

Convert a JS symbol to its hash-table storage key (string form).

Defined in `src/runtime-symbol.lisp`.

### `*js-symbol-registry*`

```lisp
cl-cc/javascript:*js-symbol-registry*
```

Global symbol registry mapping string keys to js-symbol instances.

Defined in `src/runtime-symbol.lisp`.

### `*js-symbol-global*`

```lisp
cl-cc/javascript:*js-symbol-global*
```

The global Symbol object (callable + static methods).

Defined in `src/runtime-symbol.lisp`.

## TypedArray (ES2015+)

### `%js-typed-array-p`

```lisp
(cl-cc/javascript:%js-typed-array-p x)
```

True when X is a JS TypedArray.

Defined in `src/runtime-typed-arrays.lisp`.

### `%js-make-typed-array`

```lisp
(cl-cc/javascript:%js-make-typed-array type-name &optional (arg +js-undefined+))
```

Construct a TypedArray of TYPE-NAME.

Defined in `src/runtime-typed-arrays.lisp`.

### `%js-ta-get`

```lisp
(cl-cc/javascript:%js-ta-get ta index)
```

Get element at INDEX from TypedArray TA.

Defined in `src/runtime-typed-arrays.lisp`.

### `%js-ta-set`

```lisp
(cl-cc/javascript:%js-ta-set ta index value)
```

Set element at INDEX in TypedArray TA to VALUE.

Defined in `src/runtime-typed-arrays.lisp`.

### `%js-ta-to-array`

```lisp
(cl-cc/javascript:%js-ta-to-array ta)
```

Convert TypedArray to plain JS array.

Defined in `src/runtime-typed-arrays-methods.lisp`.

### `*js-typed-array-method-table*`

```lisp
cl-cc/javascript:*js-typed-array-method-table*
```

TypedArray.prototype method dispatch.

Defined in `src/runtime-typed-arrays-methods-es2023.lisp`.

## RegExp (ES2015+ native engine)

### `%js-regexp-p`

```lisp
(cl-cc/javascript:%js-regexp-p x)
```

True when X is a JS `RegExp`.

Defined in `src/runtime-regex-combinators.lisp`.

See [`%js-make-regex`](#js-make-regex) under "Class / accessor helpers"; the same
function serves both groups.

### `%js-regex-exec`

```lisp
(cl-cc/javascript:%js-regex-exec re str &optional (start 0))
```

Execute RE against STR starting at START.

Defined in `src/runtime-regex-api.lisp`.

### `%js-regex-test`

```lisp
(cl-cc/javascript:%js-regex-test re str)
```

RegExp.prototype.test(str) — return t if match found.

Defined in `src/runtime-regex-api.lisp`.

### `%js-string-match-regex`

```lisp
(cl-cc/javascript:%js-string-match-regex str re)
```

String.prototype.match(regexp).

Defined in `src/runtime-regex-api.lisp`.

### `%js-string-search-regex`

```lisp
(cl-cc/javascript:%js-string-search-regex str re)
```

String.prototype.search(regexp) — return index or -1.

Defined in `src/runtime-regex-api.lisp`.

### `%js-string-replace-regex`

```lisp
(cl-cc/javascript:%js-string-replace-regex str re replacement)
```

String.prototype.replace(regexp, replacement).

Defined in `src/runtime-regex-api.lisp`.

### `%js-string-replace-all-regex`

```lisp
(cl-cc/javascript:%js-string-replace-all-regex str re replacement)
```

String.prototype.replaceAll with regex (must have /g flag).

Defined in `src/runtime-regex-api.lisp`.

### `%js-string-split-regex`

```lisp
(cl-cc/javascript:%js-string-split-regex str &optional re limit)
```

String.prototype.split with regex separator.

Defined in `src/runtime-regex-api.lisp`.

## ES2023 Array methods

### `%js-array-to-reversed`

```lisp
(cl-cc/javascript:%js-array-to-reversed arr)
```

Array.prototype.toReversed() — return reversed copy.

Defined in `src/runtime-array-es2023.lisp`.

### `%js-array-to-sorted`

```lisp
(cl-cc/javascript:%js-array-to-sorted arr &optional compare-fn)
```

Array.prototype.toSorted([compareFn]) — return sorted copy (stable, non-mutating).

Defined in `src/runtime-array-es2023.lisp`.

### `%js-array-to-spliced`

```lisp
(cl-cc/javascript:%js-array-to-spliced arr start &optional (delete-count nil delete-count-supplied-p) &rest items)
```

Array.prototype.toSpliced(start, deleteCount, ...items) — return modified copy.

Defined in `src/runtime-array-es2023.lisp`.

### `%js-array-with`

```lisp
(cl-cc/javascript:%js-array-with arr index value)
```

Array.prototype.with(index, value) — return copy with element replaced.

Defined in `src/runtime-array-es2023.lisp`.

### `%js-array-find-last`

```lisp
(cl-cc/javascript:%js-array-find-last arr pred)
```

Array.prototype.findLast(pred) -- last element satisfying PRED, or undefined.

Defined in `src/runtime-array-es2023.lisp`.

### `%js-array-find-last-index`

```lisp
(cl-cc/javascript:%js-array-find-last-index arr pred)
```

Bridge for `Array.prototype.findLastIndex`.

Defined in `src/runtime-array-es2023.lisp`.

### `%js-array-at`

```lisp
(cl-cc/javascript:%js-array-at arr index)
```

Array.prototype.at(index) — supports negative indices.

Defined in `src/runtime-array-es2023.lisp`.

### `%js-array-of`

```lisp
(cl-cc/javascript:%js-array-of &rest elements)
```

Array.of(...elements) — create array from positional arguments.

Defined in `src/runtime-array-es2023.lisp`.

## Date (ES2015+)

### `%js-date-p`

```lisp
(cl-cc/javascript:%js-date-p x)
```

True when X is a JS `Date`.

Defined in `src/runtime-date.lisp`.

### `%js-make-date`

```lisp
(cl-cc/javascript:%js-make-date &optional (arg +js-undefined+) &rest more)
```

Construct a JS Date object.

Defined in `src/runtime-date.lisp`.

### `%js-date-now`

```lisp
(cl-cc/javascript:%js-date-now)
```

Return current time as milliseconds since the Unix epoch (Date.now()).

Defined in `src/runtime-date.lisp`.

### `%js-date-get-time`

```lisp
(cl-cc/javascript:%js-date-get-time date)
```

Date.prototype.getTime() → milliseconds since Unix epoch.

Defined in `src/runtime-date.lisp`.

### `%js-date-get-full-year`

```lisp
(cl-cc/javascript:%js-date-get-full-year date)
```

Bridge for `Date.prototype.getFullYear`.

Defined in `src/runtime-date.lisp`.

### `%js-date-get-month`

```lisp
(cl-cc/javascript:%js-date-get-month date)
```

Bridge for `Date.prototype.getMonth`.

Defined in `src/runtime-date.lisp`.

### `%js-date-get-date`

```lisp
(cl-cc/javascript:%js-date-get-date date)
```

Bridge for `Date.prototype.getDate`.

Defined in `src/runtime-date.lisp`.

### `%js-date-get-hours`

```lisp
(cl-cc/javascript:%js-date-get-hours date)
```

Bridge for `Date.prototype.getHours`.

Defined in `src/runtime-date.lisp`.

### `%js-date-get-minutes`

```lisp
(cl-cc/javascript:%js-date-get-minutes date)
```

Bridge for `Date.prototype.getMinutes`.

Defined in `src/runtime-date.lisp`.

### `%js-date-get-seconds`

```lisp
(cl-cc/javascript:%js-date-get-seconds date)
```

Bridge for `Date.prototype.getSeconds`.

Defined in `src/runtime-date.lisp`.

### `%js-date-get-day`

```lisp
(cl-cc/javascript:%js-date-get-day date)
```

Bridge for `Date.prototype.getDay`.

Defined in `src/runtime-date.lisp`.

### `%js-date-to-iso-string`

```lisp
(cl-cc/javascript:%js-date-to-iso-string date)
```

Date.prototype.toISOString() → 'YYYY-MM-DDTHH:MM:SS.mmmZ'.

Defined in `src/runtime-date-methods.lisp`.

### `%js-date-to-string`

```lisp
(cl-cc/javascript:%js-date-to-string date)
```

Date.prototype.toString() — simplified.

Defined in `src/runtime-date-methods.lisp`.

### `*js-date-method-table*`

```lisp
cl-cc/javascript:*js-date-method-table*
```

Alist of Date.prototype method name -> host function.

Defined in `src/runtime-date-methods.lisp`.

## Well-known symbols

### `%js-symbol-iterator`

```lisp
cl-cc/javascript:%js-symbol-iterator
```

Symbol.iterator — used by for...of and spread.

Defined in `src/runtime-symbol.lisp`.

### `%js-symbol-to-primitive`

```lisp
cl-cc/javascript:%js-symbol-to-primitive
```

Symbol.toPrimitive — type coercion hook.

Defined in `src/runtime-symbol.lisp`.

### `%js-symbol-to-string-tag`

```lisp
cl-cc/javascript:%js-symbol-to-string-tag
```

Symbol.toStringTag — Object.prototype.toString tag.

Defined in `src/runtime-symbol.lisp`.

### `%js-symbol-has-instance`

```lisp
cl-cc/javascript:%js-symbol-has-instance
```

Symbol.hasInstance — instanceof hook.

Defined in `src/runtime-symbol.lisp`.

### `%js-symbol-species`

```lisp
cl-cc/javascript:%js-symbol-species
```

Symbol.species — constructor for derived objects.

Defined in `src/runtime-symbol.lisp`.

### `%js-symbol-async-iterator`

```lisp
cl-cc/javascript:%js-symbol-async-iterator
```

Symbol.asyncIterator — async iteration protocol.

Defined in `src/runtime-symbol.lisp`.

## Object extended built-ins

### `%js-object-without-keys`

```lisp
(cl-cc/javascript:%js-object-without-keys obj keys)
```

Return a copy of OBJ without the given KEYS (vector of strings).

Defined in `src/runtime-object-ops.lisp`.

### `%js-object-group-by`

```lisp
(cl-cc/javascript:%js-object-group-by iterable key-fn)
```

Object.groupBy(iterable, keyFn): group values into a null-prototype object.

Defined in `src/runtime-object-ops.lisp`.

## Iterator helpers (stage-3 / ES2025)

### `%js-iterator-map`

```lisp
(cl-cc/javascript:%js-iterator-map iter fn)
```

Bridge for `Iterator.prototype.map`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iterator-filter`

```lisp
(cl-cc/javascript:%js-iterator-filter iter fn)
```

Bridge for `Iterator.prototype.filter`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iterator-reduce`

```lisp
(cl-cc/javascript:%js-iterator-reduce iter fn &optional (init +js-undefined+))
```

Bridge for `Iterator.prototype.reduce`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iterator-take`

```lisp
(cl-cc/javascript:%js-iterator-take iter n)
```

Bridge for `Iterator.prototype.take`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iterator-drop`

```lisp
(cl-cc/javascript:%js-iterator-drop iter n)
```

Bridge for `Iterator.prototype.drop`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iterator-flat-map`

```lisp
(cl-cc/javascript:%js-iterator-flat-map iter fn)
```

Bridge for `Iterator.prototype.flatMap`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iterator-for-each`

```lisp
(cl-cc/javascript:%js-iterator-for-each iter fn)
```

Bridge for `Iterator.prototype.forEach`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iterator-some`

```lisp
(cl-cc/javascript:%js-iterator-some iter fn)
```

Bridge for `Iterator.prototype.some`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iterator-every`

```lisp
(cl-cc/javascript:%js-iterator-every iter fn)
```

Bridge for `Iterator.prototype.every`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iterator-find`

```lisp
(cl-cc/javascript:%js-iterator-find iter fn)
```

Bridge for `Iterator.prototype.find`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iterator-to-array`

```lisp
(cl-cc/javascript:%js-iterator-to-array iter)
```

Bridge for `Iterator.prototype.toArray`.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-add-iterator-helpers!`

```lisp
(cl-cc/javascript:%js-add-iterator-helpers! it)
```

Attach ES2025 Iterator.prototype methods and @@iterator to IT.

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-make-cl-iterator`

```lisp
(cl-cc/javascript:%js-make-cl-iterator get-next-fn)
```

Create a JS iterator object from a CL thunk that returns (value .

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-iter-next`

```lisp
(cl-cc/javascript:%js-iter-next iter)
```

Advance iter; return (values value done-p).

Defined in `src/runtime-collections-iterators.lisp`.

### `%js-vec-to-iter`

```lisp
(cl-cc/javascript:%js-vec-to-iter vec)
```

Create iterator over a vector.

Defined in `src/runtime-collections-iterators.lisp`.

