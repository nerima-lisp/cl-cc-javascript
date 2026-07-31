;;;; coverage-summary.lisp
;;;;
;;;; Parse the LCOV report scripts/run-coverage.lisp writes (coverage.lcov,
;;;; next to this script) and print an aggregate line-coverage percentage for
;;;; THIS repository's own src/*.lisp files only.
;;;;
;;;; Why not the HTML report cl-weave/SB-COVER already produces: its per-file
;;;; links are keyed by basename, so two sibling packages that each happen to
;;;; ship a "package.lisp" or "runtime.lisp" are indistinguishable by name
;;;; alone once every dependency in the compile is instrumented together.
;;;; LCOV's SF: line carries the full absolute source path, so filtering to
;;;; "this repo's own src/" is an unambiguous prefix match instead of a
;;;; basename guess.

(let* ((script-dir (make-pathname :directory (pathname-directory (or *load-pathname*
                                                                     *compile-file-pathname*))))
       (repo-root (merge-pathnames "../" script-dir))
       (src-dir (namestring (truename (merge-pathnames "src/" repo-root))))
       (lcov-path (merge-pathnames "coverage.lcov" script-dir)))
  (unless (probe-file lcov-path)
    (format *error-output* "~&No coverage.lcov at ~A -- run scripts/run-coverage.lisp first.~%"
            lcov-path)
    (sb-ext:exit :code 1))
  (let ((current-file nil)
        (in-scope nil)
        (file-covered 0)
        (file-total 0)
        (total-covered 0)
        (total-total 0)
        (per-file nil))
    (with-open-file (in lcov-path)
      (loop for line = (read-line in nil nil)
            while line
            do (cond
                 ((and (>= (length line) 3) (string= line "SF:" :end1 3))
                  (setf current-file (subseq line 3))
                  (setf in-scope (and (>= (length current-file) (length src-dir))
                                      (string= current-file src-dir :end1 (length src-dir))))
                  (setf file-covered 0 file-total 0))
                 ((and in-scope (>= (length line) 3) (string= line "DA:" :end1 3))
                  (let* ((rest (subseq line 3))
                         (comma (position #\, rest))
                         (hits (parse-integer rest :start (1+ comma))))
                    (incf file-total)
                    (incf total-total)
                    (when (plusp hits)
                      (incf file-covered)
                      (incf total-covered))))
                 ((and in-scope (string= line "end_of_record"))
                  (push (list current-file file-covered file-total) per-file)))))
    (format t "~&Line coverage, src/*.lisp only (this repository, excluding dependencies):~%~%")
    (dolist (entry (sort per-file #'string< :key #'first))
      (destructuring-bind (file covered total) entry
        (format t "  ~5,1F%  (~4D/~4D)  ~A~%"
                (if (plusp total) (* 100.0 (/ covered total)) 100.0)
                covered total
                (enough-namestring file src-dir))))
    (format t "~%TOTAL: ~,2F% (~D/~D lines)~%"
            (if (plusp total-total) (* 100.0 (/ total-covered total-total)) 100.0)
            total-covered total-total)))
