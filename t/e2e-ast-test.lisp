;;;; t/e2e-ast-test.lisp — JS AST structural tests
;;;;
;;;; Parse-only tests that check the AST shape produced by the JS frontend
;;;; without running the program through the VM.
;;;;
;;;; These tests use only the parser and AST APIs.

(in-package :cl-cc-javascript/test)

;;; ─── Parse helpers ───────────────────────────────────────────────────────────

(defun %js-e2e-parse (src)
  "Parse SRC and return the list of top-level AST nodes."
  (cl-cc/javascript:parse-js-source src))

(defun %js-e2e-has-defun-named (name asts)
  "Return the AST-DEFUN whose name matches NAME case-insensitively, or NIL.
JS identifiers are now interned case-preserving, so a defun named `fib' is the
symbol |fib|; compare with string-equal so these structural tests stay name-case
agnostic."
  (find-if (lambda (ast)
             (and (cl-cc/ast:ast-defun-p ast)
                  (string-equal name
                                (symbol-name (cl-cc/ast:ast-defun-name ast)))))
           asts))

(defun %js-e2e-has-defclass-named (name asts)
  "Return the AST-DEFCLASS named NAME, or NIL."
  (find-if (lambda (ast)
             (and (cl-cc/ast:ast-defclass-p ast)
                  (string-equal name
                                (symbol-name (cl-cc/ast:ast-defclass-name ast)))))
           asts))

(defun %js-e2e-defun-body-forms (fn)
  "Return FN's effective body forms, unwrapping the single (block nil ...) that
js-callable-body wraps function bodies in so JS `return' (→ return-from nil)
resolves. Lets these AST-shape tests look past the block at the real statements."
  (let ((body (cl-cc/ast:ast-defun-body fn)))
    (if (and (= (length body) 1) (cl-cc/ast:ast-block-p (first body)))
        (cl-cc/ast:ast-block-body (first body))
        body)))

;;; ─── 1. FizzBuzz ──────────────────────────────────────────────────────────────

(it-sequential "js-e2e-fizzbuzz"
  (let ((asts (%js-e2e-parse "
function fizzBuzz(n) {
  for (let i = 1; i <= n; i++) {
    if (i % 15 === 0) {
      console.log('FizzBuzz');
    } else if (i % 3 === 0) {
      console.log('Fizz');
    } else if (i % 5 === 0) {
      console.log('Buzz');
    } else {
      console.log(i);
    }
  }
}
fizzBuzz(20);
")))
    (expect (>= (length asts) 2) :to-be-truthy)
    (expect (not (null (%js-e2e-has-defun-named "FIZZBUZZ" asts))) :to-be-truthy)))

;;; ─── 2. Fibonacci recursive ───────────────────────────────────────────────────

(it-sequential "js-e2e-fibonacci-recursive"
  (let* ((asts (%js-e2e-parse "
function fib(n) {
  if (n <= 1) return n;
  return fib(n - 1) + fib(n - 2);
}
"))
         (fn (%js-e2e-has-defun-named "FIB" asts)))
    (expect (not (null fn)) :to-be-truthy)
    (expect (some #'cl-cc/ast:ast-if-p (%js-e2e-defun-body-forms fn)) :to-be-truthy)))

;;; ─── 3. Array map / filter / reduce ──────────────────────────────────────────

(it-sequential "js-e2e-array-higher-order"
  (let ((asts (%js-e2e-parse "
const nums = [1, 2, 3, 4, 5];
const doubled = nums.map(x => x * 2);
const evens = nums.filter(x => x % 2 === 0);
const sum = nums.reduce((acc, x) => acc + x, 0);
")))
    (labels ((binding-named (name nodes)
               (loop for node in nodes
                     when (cl-cc/ast:ast-let-p node)
                       thereis
                         (or (find name (cl-cc/ast:ast-let-bindings node)
                                   :key (lambda (binding) (symbol-name (car binding)))
                                   :test #'string-equal)
                             (binding-named name (cl-cc/ast:ast-let-body node)))))
             (higher-order-call-p (method arity binding)
               (let* ((call (cdr binding))
                      (callee (and (cl-cc/ast:ast-call-p call)
                                   (cl-cc/ast:ast-call-func call)))
                      (property-args (and (cl-cc/ast:ast-call-p callee)
                                          (cl-cc/ast:ast-call-args callee)))
                      (args (and (cl-cc/ast:ast-call-p call)
                                 (cl-cc/ast:ast-call-args call)))
                      (callback (first args)))
                 (and (cl-cc/ast:ast-call-p call)
                      (cl-cc/ast:ast-call-p callee)
                      (equal "%JS-GET-PROP" (%js-call-name callee))
                      (= 2 (length property-args))
                      (cl-cc/ast:ast-quote-p (second property-args))
                      (stringp (cl-cc/ast:ast-quote-value (second property-args)))
                      (string-equal method (cl-cc/ast:ast-quote-value (second property-args)))
                      (= arity (length args))
                      (cl-cc/ast:ast-lambda-p callback)
                      (= arity (length (cl-cc/ast:ast-lambda-params callback)))))))
      (let ((nums (binding-named "nums" asts))
            (doubled (binding-named "doubled" asts))
            (evens (binding-named "evens" asts))
            (sum (binding-named "sum" asts)))
        (expect (and nums
                     (cl-cc/ast:ast-call-p (cdr nums))
                     (equal "%JS-MAKE-ARRAY" (%js-call-name (cdr nums)))
                     (= 5 (length (cl-cc/ast:ast-call-args (cdr nums))))) :to-be-truthy)
        (expect (higher-order-call-p "map" 1 doubled) :to-be-truthy)
        (expect (higher-order-call-p "filter" 1 evens) :to-be-truthy)
        (expect (higher-order-call-p "reduce" 2 sum) :to-be-truthy)))))

;;; ─── 4. Class with inheritance ────────────────────────────────────────────────

(it-sequential "js-e2e-class-inheritance"
  (let ((asts (%js-e2e-parse "
class Animal {
  constructor(name) {
    this.name = name;
  }
  speak() {
    return this.name + ' makes a noise.';
  }
}

class Dog extends Animal {
  speak() {
    return this.name + ' barks.';
  }
}
")))
    (expect (not (null (%js-e2e-has-defclass-named "ANIMAL" asts))) :to-be-truthy)
    (expect (not (null (%js-e2e-has-defclass-named "DOG" asts))) :to-be-truthy)
    (let ((dog (%js-e2e-has-defclass-named "DOG" asts)))
      (expect (some (lambda (s) (string-equal "Animal" (symbol-name s)))
                (cl-cc/ast:ast-defclass-superclasses dog)) :to-be-truthy))))

;;; ─── 5. Object destructuring ──────────────────────────────────────────────────

(it-sequential "js-e2e-object-destructuring"
  (let ((asts (%js-e2e-parse "
const person = { name: 'Alice', age: 30, city: 'NY' };
const { name, age } = person;
const { city: location } = person;
")))
    (expect (>= (length asts) 1) :to-be-truthy)
    (labels ((getprop-binding-p (b)
               (let ((v (cdr b)))
                 (and (cl-cc/ast:ast-call-p v)
                      (cl-cc/ast:ast-var-p (cl-cc/ast:ast-call-func v))
                      (search "GET-PROP"
                              (symbol-name (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func v)))))))
             (chain-has-getprop (node)
               (when (cl-cc/ast:ast-let-p node)
                 (or (some #'getprop-binding-p (cl-cc/ast:ast-let-bindings node))
                     (some #'chain-has-getprop (cl-cc/ast:ast-let-body node))))))
      (expect (some #'chain-has-getprop asts) :to-be-truthy))))

;;; ─── 6. Generator sequence ────────────────────────────────────────────────────

(it-sequential "js-e2e-generator-sequence"
  (let* ((asts (%js-e2e-parse "
function* range(start, end, step = 1) {
  for (let i = start; i < end; i += step) {
    yield i;
  }
}
const it = range(0, 10, 2);
"))
         (gen (%js-e2e-has-defun-named "RANGE" asts)))
    (expect (not (null gen)) :to-be-truthy)
    (expect (member :js-generator (cl-cc/ast:ast-defun-declarations gen)) :to-be-truthy)))

;;; ─── 7. Error handling try / catch ───────────────────────────────────────────

(it-sequential "js-e2e-error-handling"
  (let ((asts (%js-e2e-parse "
function safeDiv(a, b) {
  try {
    if (b === 0) throw new Error('Division by zero');
    return a / b;
  } catch (e) {
    console.error('Error:', e.message);
    return null;
  } finally {
    console.log('safeDiv done');
  }
}
")))
    (let* ((fn (%js-e2e-has-defun-named "SAFEDIV" asts))
           (body (when fn (%js-e2e-defun-body-forms fn))))
      (expect (not (null fn)) :to-be-truthy)
      (expect (some (lambda (node)
                  (and (cl-cc/ast:ast-call-p node)
                       (string= "%JS-TRY-CATCH-FINALLY"
                                 (symbol-name
                                  (cl-cc/ast:ast-var-name
                                   (cl-cc/ast:ast-call-func node))))))
                body) :to-be-truthy))))

;;; ─── 8. Module-style exports ──────────────────────────────────────────────────

(it-sequential "js-e2e-module-exports"
  (let ((asts (cl-cc/javascript:parse-js-module "
export function add(a, b) { return a + b; }
export function subtract(a, b) { return a - b; }
export const PI = 3.14159;
")))
    (labels ((export-info (node)
               (let ((args (and (cl-cc/ast:ast-call-p node)
                                (equal "%JS-EXPORT" (%js-call-name node))
                                (cl-cc/ast:ast-call-args node))))
                 (when (and (= 4 (length args))
                            (cl-cc/ast:ast-quote-p (first args))
                            (cl-cc/ast:ast-quote-p (fourth args)))
                   (list (cl-cc/ast:ast-quote-value (first args))
                         (cl-cc/ast:ast-quote-value (fourth args))
                         (second args))))))
      (let* ((infos (mapcar #'export-info asts))
             (declarations (mapcar #'third infos)))
        (expect (= 3 (length asts)) :to-be-truthy)
        (expect (every #'identity infos) :to-be-truthy)
        (expect (mapcar #'first infos) :to-equal
                '(:declaration :declaration :declaration))
        (expect (mapcar #'second infos) :to-equal
                '(("add") ("subtract") ("PI")))
        (expect (and (= 3 (length declarations))
                     (every #'cl-cc/ast:ast-defun-p (subseq declarations 0 2)))
                :to-be-truthy)
        (expect (and (= 3 (length declarations))
                     (string-equal "add"
                                   (symbol-name (cl-cc/ast:ast-defun-name (first declarations))))
                     (string-equal "subtract"
                                   (symbol-name (cl-cc/ast:ast-defun-name (second declarations)))))
                :to-be-truthy)
        (expect (and (= 3 (length declarations))
                     (equal (mapcar (lambda (fn)
                                      (mapcar #'symbol-name
                                              (cl-cc/ast:ast-defun-params fn)))
                                    (subseq declarations 0 2))
                            '(("a" "b") ("a" "b"))))
                :to-be-truthy)
        (let* ((pi-decl (third declarations))
               (bindings (when (cl-cc/ast:ast-let-p pi-decl)
                           (cl-cc/ast:ast-let-bindings pi-decl))))
          (expect (and bindings
                       (string-equal "PI" (symbol-name (caar bindings))))
                  :to-be-truthy))))))

;;; ─── 9. Async / await simulation ─────────────────────────────────────────────

(it-sequential "js-e2e-async-await"
  (let* ((asts (%js-e2e-parse "
async function fetchData(url) {
  try {
    const response = await fetch(url);
    const data = await response.json();
    return data;
  } catch (err) {
    throw new Error('Fetch failed: ' + err.message);
  }
}
"))
         (fn (%js-e2e-has-defun-named "FETCHDATA" asts)))
    (expect (not (null fn)) :to-be-truthy)
    (expect (member :js-async (cl-cc/ast:ast-defun-declarations fn)) :to-be-truthy)))

;;; ─── 10. Optional chaining chain ─────────────────────────────────────────────

(it-sequential "js-e2e-optional-chaining-chain"
  (let ((asts (%js-e2e-parse "
const user = { profile: { address: { city: 'NYC' } } };
const city = user?.profile?.address?.city;
const zip = user?.profile?.address?.zip ?? 'N/A';
const upper = user?.profile?.address?.city?.toUpperCase();
")))
    (labels ((binding-named (name nodes)
               (loop for node in nodes
                     when (cl-cc/ast:ast-let-p node)
                       thereis
                         (or (find name (cl-cc/ast:ast-let-bindings node)
                                   :key (lambda (binding) (symbol-name (car binding)))
                                   :test #'string-equal)
                             (binding-named name (cl-cc/ast:ast-let-body node)))))
             (optional-chain-keys (node)
               (when (and (cl-cc/ast:ast-call-p node)
                          (equal "%JS-OPTIONAL-CHAIN" (%js-call-name node)))
                 (let ((args (cl-cc/ast:ast-call-args node)))
                   (when (and (= 2 (length args))
                              (cl-cc/ast:ast-quote-p (second args)))
                     (append (optional-chain-keys (first args))
                             (list (cl-cc/ast:ast-quote-value (second args))))))))
             (call-args-named (name node)
               (when (and (cl-cc/ast:ast-call-p node)
                          (equal name (%js-call-name node)))
                 (cl-cc/ast:ast-call-args node))))
      (let* ((city (binding-named "city" asts))
             (zip (binding-named "zip" asts))
             (upper (binding-named "upper" asts))
             (city-init (cdr city))
             (zip-init (cdr zip))
             (zip-bindings (when (cl-cc/ast:ast-let-p zip-init)
                             (cl-cc/ast:ast-let-bindings zip-init)))
             (zip-body (when (cl-cc/ast:ast-let-p zip-init)
                         (cl-cc/ast:ast-let-body zip-init)))
             (upper-call (cdr upper))
             (upper-args (call-args-named "%JS-OPTIONAL-METHOD-CALL" upper-call)))
        (expect city :to-be-truthy)
        (expect zip :to-be-truthy)
        (expect upper :to-be-truthy)
        (expect (optional-chain-keys city-init) :to-equal
                '("profile" "address" "city"))
        (expect (and zip-bindings
                     (equal (optional-chain-keys (cdar zip-bindings))
                            '("profile" "address" "zip")))
                :to-be-truthy)
        (expect (and zip-body
                     (= 1 (length zip-body))
                     (cl-cc/ast:ast-if-p (first zip-body)))
                :to-be-truthy)
        (expect (and upper-args
                     (= 2 (length upper-args))
                     (cl-cc/ast:ast-quote-p (second upper-args))
                     (string-equal "toUpperCase"
                                   (cl-cc/ast:ast-quote-value (second upper-args)))
                     (equal (optional-chain-keys (first upper-args))
                            '("profile" "address" "city")))
                :to-be-truthy)))))
;;; W2-23 control: verify that one registered failure makes ASDF fail.

(it-sequential "js-e2e-control-intentional-failure" (expect nil :to-be-truthy))
