## syntax

- Definition: JavaScript lexical tokens, parser context and syntax registration protocols; feature grammars register callbacks here.
- Package: `cl-cc/javascript/syntax`
- Key types: None.
- Key functions: tokenize-js-source, parse-js-source, register-js-parser-handler
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## expressions

- Definition: Expression AST construction and evaluation, including operators and literal forms.
- Package: `cl-cc/javascript/expressions`
- Key types: None.
- Key functions: js-parse-expr, %js-typeof, %js-instanceof
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## statements

- Definition: Statement AST construction, parsing and control-flow evaluation.
- Package: `cl-cc/javascript/statements`
- Key types: None.
- Key functions: js-parse-stmt, js-parse-block
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## functions

- Definition: Function AST lowering, declarations, expressions, arrows, calls and closure runtime support.
- Package: `cl-cc/javascript/functions`
- Key types: None.
- Key functions: js-parse-function-decl, %js-funcall
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## classes

- Definition: Class AST lowering, declarations, fields and runtime class behavior.
- Package: `cl-cc/javascript/classes`
- Key types: None.
- Key functions: js-parse-class-decl, %js-class-private-field-get
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## objects

- Definition: Object values, properties, prototypes, collections, symbols and weak collections.
- Package: `cl-cc/javascript/objects`
- Key types: js-map, js-set, js-symbol, js-bigint, js-weak-map, js-weak-set, js-weak-ref, js-finalization-registry, js-finalization-registration
- Key functions: %js-get-prop, %js-set-prop, %js-make-object
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## proxies

- Definition: Proxy objects and Reflect behavior layered over JavaScript object operations.
- Package: `cl-cc/javascript/proxies`
- Key types: None.
- Key functions: %js-make-proxy-object, %js-proxy-get
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## iterators

- Definition: Iterator protocols and synchronous generators.
- Package: `cl-cc/javascript/iterators`
- Key types: None.
- Key functions: %js-for-of, %js-make-generator
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## async

- Definition: Promise values, await and asynchronous function execution.
- Package: `cl-cc/javascript/async`
- Key types: js-promise
- Key functions: js-promise-p, %js-await, %js-async
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## modules

- Definition: Module records, import and export declarations and module runtime behavior.
- Package: `cl-cc/javascript/modules`
- Key types: None.
- Key functions: %js-import, %js-export, js-parse-import-decl
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## regex

- Definition: Regular-expression values and literals, parsing, matching and RegExp runtime methods.
- Package: `cl-cc/javascript/regex`
- Key types: js-regexp
- Key functions: js-lex-regex, %js-regex-test
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## strings

- Definition: String values, template-literal tokenization and string runtime operations.
- Package: `cl-cc/javascript/strings`
- Key types: None.
- Key functions: js-lex-template, %js-string-trim, %js-string-replace
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## numbers

- Definition: Numeric literals, number parsing and JavaScript Math operations.
- Package: `cl-cc/javascript/numbers`
- Key types: None.
- Key functions: lex-js-number, %js-math-abs, %js-parse-int
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## arrays

- Definition: Array and typed-array values and array-iterator operations.
- Package: `cl-cc/javascript/arrays`
- Key types: js-typed-array
- Key functions: %js-make-array, %js-array-map
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## json

- Definition: JSON values through JSON.parse and JSON.stringify integration.
- Package: `cl-cc/javascript/json`
- Key types: js-raw-json
- Key functions: %js-json-parse, %js-json-stringify
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## dates

- Definition: Date values, Temporal operations and time-zone integration.
- Package: `cl-cc/javascript/dates`
- Key types: js-date
- Key functions: %js-temporal-instant, *js-temporal-global*
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## intl

- Definition: ECMAScript internationalization constructors and formatters.
- Package: `cl-cc/javascript/intl`
- Key types: None.
- Key functions: %js-make-intl-number-format
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## errors

- Definition: JavaScript exception conditions, error values and error-value detection.
- Package: `cl-cc/javascript/errors`
- Key types: js-exception
- Key functions: js-exception, %js-throw
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## disposables

- Definition: Explicit resource management syntax and using-declaration lowering.
- Package: `cl-cc/javascript/disposables`
- Key types: None.
- Key functions: js-parse-using-decl, js-parse-try-stmt
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## backend

- Definition: Backend bridge composition, runtime method resolution and builtin registration.
- Package: `cl-cc/javascript/backend`
- Key types: None.
- Key functions: %js-resolve-method, %build-js-builtin-map, %install-js-vm-integration
- Other contexts: JavaScript features register syntax callbacks through `syntax`; `syntax` does not import feature packages.

## v8-objects

- Definition: V8 object shapes, inline method tables, mark words and value type definitions used by the VM integration.
- Package: `cl-cc/javascript/v8-objects`
- Key types: object-shape, imt-entry, inline-method-table, value-type-def
- Key functions: find-or-create-shape, shape-slot-offset, imt-insert, imt-lookup, make-mark-word, mark-word-gc-color, defvalue-type
- Other contexts: The `cl-cc/javascript` facade re-exports the accepted V8 object helpers.
