# Quick Start

Compiling and running one JavaScript program, then looking at the two intermediate
stages it passed through.

## 1. Run a program

`cl-cc:compile-string` is the entry point. Loading `cl-cc-javascript` is what makes
`:language :javascript` available.

```lisp
(asdf:load-system "cl-cc-javascript")

(let* ((result  (cl-cc:compile-string "console.log(1 + 1);"
                                      :target :vm :language :javascript))
       (program (cl-cc/compile:compilation-result-program result)))
  (cl-cc/vm:run-compiled program))
```

```
2
```

## 2. Seed the runtime globals

The program above only needed `console`. Anything that touches `Math`, `JSON`, `Map`,
`Promise` and the rest of the standard globals needs those seeded into the VM state
first, which is what `cl-cc/pipeline:seed-js-runtime-globals` does.

```lisp
(let* ((result  (cl-cc:compile-string "console.log(Math.max(2, 3, 1));"
                                      :target :vm :language :javascript))
       (program (cl-cc/compile:compilation-result-program result))
       (out     (make-string-output-stream))
       (state   (cl-cc/vm:make-vm-state :output-stream out)))
  (cl-cc/pipeline:seed-js-runtime-globals state)
  (cl-cc/vm:run-compiled program :output-stream out :state state)
  (get-output-stream-string out))
;; => "3
;;    "
```

This is exactly the shape of `%js-run-capture`, the helper the end-to-end test suite
uses, so it is the path to copy.

## 3. Look at the tokens

`tokenize-js-source` returns a flat list of token plists, ending with `:T-EOF`.

```lisp
(cl-cc/javascript:tokenize-js-source "const x = 42;")
;; => ((:TYPE :T-CONST  :VALUE "const")
;;     (:TYPE :T-IDENT  :VALUE "x")
;;     (:TYPE :T-OP     :VALUE "=")
;;     (:TYPE :T-NUMBER :VALUE 42)
;;     (:TYPE :T-SEMI   :VALUE ";")
;;     (:TYPE :T-EOF    :VALUE NIL))
```

Keywords and punctuators carry their source text as `:value`; `=` is a generic `:T-OP`
rather than a token type of its own.

Numeric values are already decoded: `0xFF` lexes to `255`, `1_000_000` to `1000000`,
`3.14` to a `double-float`, and `42n` to a `:T-BIGINT` token.

## 4. Look at the AST

`parse-js-source` returns a list of top-level cl-cc AST nodes — not a JavaScript-shaped
tree. `const x = 42` becomes an `ast-let`:

```lisp
(let ((node (first (cl-cc/javascript:parse-js-source "const x = 42;"))))
  (list (cl-cc:ast-let-p node)
        (length (cl-cc:ast-let-bindings node))
        (cl-cc:ast-int-p (cdr (first (cl-cc:ast-let-bindings node))))))
;; => (T 1 T)
```

`import`/`export` syntax parses unconditionally regardless of which entry point you
call — `parse-js-module` is `parse-js-source` under a name that says what the source
is, not a different parser:

```lisp
(cl-cc/javascript:parse-js-module source)
```

## 5. Parse with the prelude attached

`js-program-forms` is `parse-js-source` with the standard-globals prelude prepended. It
returns forms ready to hand to the compiler backend, and is what the pipeline calls.

```lisp
(length (cl-cc/javascript:js-program-forms "console.log('hi');"))
;; => one form per prelude global, plus the parsed program
```

## Complete example

```lisp
(asdf:load-system "cl-cc-javascript")

(defun run-js (source)
  "Compile and run JavaScript SOURCE, returning everything it printed."
  (let* ((result  (cl-cc:compile-string source :target :vm :language :javascript))
         (program (cl-cc/compile:compilation-result-program result))
         (out     (make-string-output-stream))
         (state   (cl-cc/vm:make-vm-state :output-stream out)))
    (cl-cc/pipeline:seed-js-runtime-globals state)
    (cl-cc/vm:run-compiled program :output-stream out :state state)
    (string-right-trim '(#\Newline) (get-output-stream-string out))))

(run-js "
  class Greeter {
    constructor(name) { this.name = name; }
    greet() { return `hello, ${this.name}`; }
  }
  console.log(new Greeter('world').greet());
")
;; => "hello, world"
```

## Next

- [Core Concepts](core-concepts.md) for the vocabulary used above.
- [API Reference](api-reference.md) for every exported symbol.
