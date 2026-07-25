# Conditions

This package exports exactly one condition type.

## `js-exception`

```lisp
(define-condition js-exception ()
  ((value :initarg :value :reader js-exception-value)))
```

A JavaScript `throw`. `%js-throw` signals it, and `js-exception-value` reads back the
thrown JavaScript value — which can be any JS value at all, not necessarily an `Error`
object, because `throw 42` is legal JavaScript.

Note that it inherits from `condition`, not from `error`. `handler-case` on `error` will
not catch it; handle `js-exception` by name.

```lisp
(handler-case
    (cl-cc/javascript:%js-throw "boom")
  (cl-cc/javascript:js-exception (c)
    (cl-cc/javascript:js-exception-value c)))
;; => "boom"
```

`%js-try-catch-finally` is the form generated code uses; it runs the try thunk, passes
the thrown value to the catch thunk on a `js-exception`, and always runs the finally
thunk.

## Everything else is a plain error

The rest of the package signals ordinary Common Lisp conditions rather than defining its
own hierarchy.

| Situation | Condition |
|---|---|
| Malformed source | `simple-error` from the lexer or parser, message prefixed `JS parse error:` |
| Nesting past `*js-max-parse-depth*` | `simple-error`, `JS parse error: nesting too deep (limit 2500)` |
| A JS `TypeError` the runtime detects, e.g. `Array.prototype.reduce` on an empty array with no initial value | `simple-error` whose message begins `JS TypeError:` |
| Arithmetic and type faults on values the code generator does not produce | standard `type-error`, `division-by-zero`, etc. |

This is a real inconsistency: a JavaScript `TypeError` raised by the *program* surfaces
as a `js-exception`, while one detected by the *runtime helper* surfaces as a
`simple-error` with a `JS TypeError:` prefix. Match on the message prefix if you need to
distinguish them, and do not rely on it being stable.

## See also

- [`js-exception`](api-reference.md#js-exception) and
  [`%js-throw`](api-reference.md#js-throw) in the API reference.
- [Compatibility](compatibility.md#resource-limits) for the parse depth limit.
