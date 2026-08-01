# Getting Started

cl-cc-javascript is consumed as a Nix flake input and loaded through ASDF.

## Add the flake input

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cl-cc-javascript = {
      url = "github:nerima-lisp/cl-cc-javascript";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

!!! note "This input is not yet pinned to a tag"

    Consumers inside this org normally pin a release tag
    (`github:nerima-lisp/cl-cc-javascript/v0.1.0`) rather than follow the default
    branch, because an upstream push to `main` otherwise breaks downstream CI without
    warning. cl-cc-javascript has no release tag yet, so there is nothing to pin to.
    Pin one as soon as the first tag exists.

## Add the system dependency

```lisp
;; your-system.asd
:depends-on ("cl-cc" "cl-cc-javascript")
```

Loading the system is all that is required to register the JavaScript frontend: the last
two components (`runtime-bridge-provider` and `vm-integration`) self-register with
`cl-cc/bootstrap`, so `cl-cc:compile-string` accepts `:language :javascript` from then
on. There is no separate initialisation call.

Consuming the flake needs nothing else. Building or testing this repository from a
raw checkout does: cl-cc-javascript depends on systems that still live inside the
cl-cc checkout, plus several `nerima-lisp` siblings. `nix develop` wires all of them
up from the pinned flake inputs; outside it, see
[Development](project/development.md#resolving-the-source-tree-dependencies).

## Verify

```sh
nix flake check --print-build-logs
```

This runs the compile gate, the test suite, the Nix formatting gate and the docs build.
See [Development](project/development.md).

## Run a program

The rest of this page compiles and runs one JavaScript program, then looks at the two
intermediate stages it passed through.

`cl-cc:compile-string` is the entry point. Loading `cl-cc-javascript` is what makes
`:language :javascript` available.

```lisp
(asdf:load-system "cl-cc-javascript")

(let* ((result  (cl-cc:compile-string "console.log(1 + 1);"
                                      :target :vm :language :javascript))
       (program (cl-cc/compile:compilation-result-program result)))
  (cl-cc/vm:run-compiled program))
```

```text
2
```

## Seed the runtime globals

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

## Look at the tokens

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

## Look at the AST

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

## Parse with the prelude attached

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

- [Core Concepts](guide/core-concepts.md) for the vocabulary used above.
- [API Reference](reference/api.md) for every exported symbol.
