;;;; packages/javascript/src/macros.lisp — Cross-cutting definition macros
;;;;
;;;; Macros that are used by more than one layer of the compiler (lexer,
;;;; parser and runtime all build dispatch tables the same way), so they
;;;; cannot live in any one of those files.
;;;;
;;;; Load order: immediately after package.lisp, before everything else.

(in-package :cl-cc/javascript)

;;; ─── Dispatch tables ─────────────────────────────────────────────────────────
;;;
;;; A dispatch table is the "data" half of a data/logic split: a flat mapping
;;; from a token type, operator string or identifier to the thing that handles
;;; it (a builder closure, a runtime helper symbol, a precedence, a token
;;; type…).  Every such table in this system used to be written out by hand as
;;; the same `(let ((ht (make-hash-table …))) (dolist (entry '(…)) (setf
;;; (gethash (car entry) ht) (cdr entry))) ht)' boilerplate, which buries the
;;; data inside a re-typed construction loop.  DEFINE-BUILDER-TABLE keeps only
;;; the data at the call site.

(defmacro define-builder-table (name (&key (test '#'equal) key seed
                                           documentation (definer 'defparameter))
                                &body entries)
  "Define NAME as a hash table populated from ENTRIES.

Each entry is a two-element list (KEY VALUE-FORM); VALUE-FORM is evaluated at
load time, so entries may be constants, symbols or closures.

  :TEST          hash-table test (default #'EQUAL).
  :KEY           a function name applied to each literal key before it is
                 stored, for tables keyed by something derived from the
                 literal (e.g. JS-IDENT-SYM to key by interned symbol).
  :SEED          a form evaluating to an alist merged in before ENTRIES, for
                 tables that share part of their key set with another
                 definition and must not drift from it.
  :DOCUMENTATION the variable's docstring.
  :DEFINER       DEFPARAMETER (default) or DEFVAR."
  (let ((ht (gensym "HT"))
        (pair (gensym "PAIR")))
    `(,definer ,name
       (let ((,ht (make-hash-table :test ,test)))
         ,@(when seed
             `((dolist (,pair ,seed)
                 (setf (gethash (car ,pair) ,ht) (cdr ,pair)))))
         ,@(mapcar (lambda (entry)
                     (destructuring-bind (entry-key value) entry
                       `(setf (gethash ,(if key `(,key ,entry-key) entry-key) ,ht)
                              ,value)))
                   entries)
         ,ht)
       ,@(when documentation (list documentation)))))
