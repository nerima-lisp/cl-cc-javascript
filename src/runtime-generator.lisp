;;;; packages/javascript/src/runtime-generator.lisp — JS async functions and
;;;; generators (function* / async function)
;;;;
;;;; Load order: after runtime-promise.lisp (%js-make-async calls
;;;; %js-promise-resolve/-reject).

(in-package :cl-cc/javascript)

;;; -----------------------------------------------------------------------
;;;  Async / generator wrappers
;;; -----------------------------------------------------------------------

(defun %js-make-async (fn)
  "Wrap FN as an async function: invoking it returns a resolved/rejected promise."
  (lambda (&rest args)
    (handler-case
        (%js-promise-resolve (funcall *js-apply-fn* fn args))
      (js-exception (c)
        (%js-promise-reject (js-exception-value c))))))

(defun %js-make-async-generator (fn)
  "Simplified async generator: delegates to %js-make-async."
  (%js-make-async fn))

;;; -----------------------------------------------------------------------
;;;  Generator — suspend/resume coroutine model with full iterator protocol
;;;
;;; function* bodies compile as ordinary functions; yield calls %js-yield.
;;; Portable Common Lisp has no first-class continuations, so %js-yield's
;;; suspension is built from a genuine coroutine: BODY-FN runs on its own
;;; thread, and control is handed back and forth across a one-at-a-time
;;; baton (%JS-GENERATOR-CHANNEL) so exactly one of {driver, body} thread
;;; ever runs at a time — the pair behaves as a single logical thread of
;;; control, just like a syntactically CPS-transformed generator would.
;;; This lets .next(value) actually resume at the suspended yield with
;;; VALUE as that yield expression's result, .throw(err) inject ERR at the
;;; same point, and an infinite generator body only ever run one step
;;; ahead of its consumer.
;;;
;;; Caveat: a generator abandoned before it's drained to completion (no
;;; final .next()/.return()/.throw() call) leaves its body thread blocked
;;; forever waiting for the next hand-off. That thread is reclaimed when
;;; the process exits; nothing in this simplified runtime calls .return()
;;; on early loop exit (e.g. `break` inside for-of) to collect it sooner.
;;; -----------------------------------------------------------------------

(defstruct (%js-generator-channel (:conc-name %js-gen-chan-))
  (lock (sb-thread:make-mutex :name "js-generator"))
  (cv (sb-thread:make-waitqueue :name "js-generator"))
  ;; Whose turn it is to run: :body or :driver. The generator's body thread
  ;; only ever executes while this is :body; the driver (whoever called
  ;; next/return/throw) only ever reads results while it's :driver.
  (turn :driver)
  ;; The body thread, spun up lazily on the first driver call so a
  ;; generator that's constructed but never iterated costs no thread at all.
  thread
  (done-p nil)
  ;; Driver → body: (:resume value) | (:throw js-value) | (:return js-value)
  request
  ;; Body → driver: (:yield value) | (:done value) | (:error condition)
  response)

(defun %js-gen-chan-wait-for (chan who)
  "Block until it is WHO's (:body or :driver) turn on CHAN."
  (sb-thread:with-mutex ((%js-gen-chan-lock chan))
    (loop until (eq (%js-gen-chan-turn chan) who)
          do (sb-thread:condition-wait (%js-gen-chan-cv chan) (%js-gen-chan-lock chan)))))

(defun %js-gen-chan-hand-off (chan to)
  "Give control of CHAN to TO (:body or :driver) and wake its waiter."
  (sb-thread:with-mutex ((%js-gen-chan-lock chan))
    (setf (%js-gen-chan-turn chan) to)
    (sb-thread:condition-broadcast (%js-gen-chan-cv chan))))

(defvar *%js-generator-channel* nil
  "Bound to the active generator's coroutine channel while its BODY-FN runs.")

(defun %js-yield (&optional (value +js-undefined+))
  "Suspend the active generator body, handing VALUE to its consumer, and
resume with whatever the next .next(v)/.throw(e)/.return(v) call sends —
returning V, raising E at this point, or unwinding out to end the body."
  (let ((chan *%js-generator-channel*))
    (if (null chan)
        value ; %js-yield outside any generator body: no one to suspend to.
        (progn
          (setf (%js-gen-chan-response chan) (list :yield value))
          (%js-gen-chan-hand-off chan :driver)
          (%js-gen-chan-wait-for chan :body)
          (destructuring-bind (kind payload) (%js-gen-chan-request chan)
            (ecase kind
              (:resume payload)
              (:throw (%js-throw payload))
              (:return (throw '%js-generator-return (list :done payload)))))))))

(defun %js-yield-from (iterable)
  "yield* — drain ITERABLE into the active generator by reusing %js-for-of,
so each drained element suspends/resumes exactly like a direct yield."
  (if *%js-generator-channel*
      (%js-for-of iterable #'%js-yield)
      +js-undefined+)
  +js-undefined+)

(defun %%js-run-generator-body (chan body-fn vm-state this)
  "Coroutine entry point for a generator's body thread: wait for the first
.next(), then run BODY-FN to completion, reporting its outcome to CHAN.
VM-STATE and THIS are the driver thread's dynamic bindings at the moment
this thread was spawned — a new SBCL thread does not inherit another
thread's dynamic bindings, so without rebinding them here, %js-funcall's
VM re-entry would see cl-cc/vm:*vm-state* as unbound and silently no-op."
  (%js-gen-chan-wait-for chan :body)
  (let* ((*%js-generator-channel* chan)
         (cl-cc/vm:*vm-state* vm-state)
         (%js-this this)
         (outcome (catch '%js-generator-return
                    (handler-case (list :done (%js-funcall body-fn))
                      (js-exception (c) (list :error c))
                      ;; Match the prior eager model's tolerance: an
                      ;; unexpected non-JS condition ends the generator as
                      ;; if it had returned undefined, rather than crashing
                      ;; this thread and leaving the driver waiting forever.
                      (error () (list :done +js-undefined+))))))
    (setf (%js-gen-chan-response chan) outcome)
    (%js-gen-chan-hand-off chan :driver)))

(defun %js-gen-chan-ensure-started (chan body-fn)
  "Spin up CHAN's body thread on first use, capturing the calling (driver)
thread's current VM state and `this' binding so the body thread runs in the
same dynamic context the generator function was called from."
  (unless (%js-gen-chan-thread chan)
    (let ((vm-state cl-cc/vm:*vm-state*)
          (this %js-this))
      (setf (%js-gen-chan-thread chan)
            (sb-thread:make-thread
             (lambda () (%%js-run-generator-body chan body-fn vm-state this))
             :name "js-generator-body")))))

(defun %js-make-generator (body-fn)
  "Return a JS iterator object that runs BODY-FN as a suspend/resume
coroutine: each .next()/.throw()/.return() call resumes it for exactly one
step and blocks until it yields, returns, or throws. BODY-FN's thread is
only created on the first such call, so a generator that's constructed but
never iterated never spawns one."
  (let ((chan (make-%js-generator-channel)))
    (labels ((drive (request)
               (if (%js-gen-chan-done-p chan)
                   (%js-make-object "value" +js-undefined+ "done" t)
                   (progn
                     (%js-gen-chan-ensure-started chan body-fn)
                     (setf (%js-gen-chan-request chan) request)
                     (%js-gen-chan-hand-off chan :body)
                     (%js-gen-chan-wait-for chan :driver)
                     (destructuring-bind (kind payload) (%js-gen-chan-response chan)
                       (ecase kind
                         (:yield (%js-make-object "value" payload "done" nil))
                         (:done (setf (%js-gen-chan-done-p chan) t)
                          (%js-make-object "value" payload "done" t))
                         (:error (setf (%js-gen-chan-done-p chan) t)
                          (error payload))))))))
      (let ((gen (%js-make-object
                  "next"
                  (lambda (&optional (value +js-undefined+))
                    (drive (list :resume value)))
                  "return"
                  (lambda (&optional (value +js-undefined+))
                    (if (%js-gen-chan-thread chan)
                        (drive (list :return value))
                        (progn (setf (%js-gen-chan-done-p chan) t)
                               (%js-make-object "value" value "done" t))))
                  "throw"
                  (lambda (&optional (err +js-undefined+))
                    (if (%js-gen-chan-thread chan)
                        (drive (list :throw err))
                        (progn (setf (%js-gen-chan-done-p chan) t)
                               (%js-throw err)))))))
        ;; @@iterator + ES2025 Iterator.prototype helpers (.map/.filter/.take/etc.)
        (%js-add-iterator-helpers! gen)
        gen))))

(defun %js-generator-next (gen &optional (value +js-undefined+))
  "Advance GEN by one step (delegates to its 'next' method)."
  (let ((next-fn (and (%js-ht-p gen) (gethash "next" gen))))
    (if next-fn
        (%js-funcall next-fn value)
        (%js-make-object "value" +js-undefined+ "done" t))))

(defun %js-wrap-generator-body (body-fn)
  "Return a function that, when called, produces a fresh generator from BODY-FN.
The compiler inserts this wrapper for every function* declaration."
  (lambda (&rest args)
    (%js-make-generator (lambda () (apply body-fn args)))))
