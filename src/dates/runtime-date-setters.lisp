(in-package #:cl-cc/javascript/dates)

;;; -----------------------------------------------------------------------
;;;  Date.prototype setters
;;; -----------------------------------------------------------------------
(defun %js-date-set-time (date ms)
  (setf (js-date-ms date) (%js-date-truncate-or-nan ms))
  ms)

(defun %js-date-set-full-year (date year &optional month day)
  "Date.prototype.setFullYear — sets year (and optionally month/day), preserving time."
  (%js-date-rebuild
    date
    :year
    (%js-date-truncate-or-nan year)
    :month
    (and month (not (eq month +js-undefined+)) (%js-date-truncate-or-nan month))
    :day
    (and day (not (eq day +js-undefined+)) (%js-date-truncate-or-nan day))))

(defun %js-date-rebuild (date &key sec min hour day month year)
  "Re-encode DATE's ms with overridden decoded components (sub-second ms preserved).
MONTH is JS 0-based (converted to CL 1-based internally). Routed through
%js-date-components-to-ms so out-of-range components roll over (JS setDate(40)
semantics) instead of trapping in encode-universal-time. If DATE is already
invalid, or any override argument is NaN, the result stays/becomes an
Invalid Date -- decoding an already-invalid DATE's current fields is
impossible (%JS-DATE-TO-DECODED's precondition), so this checks first
instead of calling it."
  (if (or (%js-date-invalid-p date)
          (some #'%js-nan-p (remove nil (list sec min hour day month year))))
      (progn (setf (js-date-ms date) *js-nan-float*) *js-nan-float*)
      (%with-date-fields
        (date :sec ds :min dmn :hour dh :day dd :month dm :year dy)
        (let* ((frac-ms (mod (js-date-ms date) 1000))
               (base-ms
              (%js-date-components-to-ms
                (or year dy)
                (or month (1- dm))
                (or day dd)
                (or hour dh)
                (or min dmn)
                (or sec ds)
                0)))
          (setf (js-date-ms date) (+ base-ms frac-ms))
          (coerce (js-date-ms date) 'double-float)))))

(defun %js-date-set-month (date month &optional day)
  "Date.prototype.setMonth(month[, day]) — MONTH is 0-based."
  (%js-date-rebuild
    date
    :month
    (%js-date-truncate-or-nan month)
    :day
    (and day (not (eq day +js-undefined+)) (%js-date-truncate-or-nan day))))

(defun %js-date-set-date (date day)
  "Date.prototype.setDate(day) — day of month, 1-based."
  (%js-date-rebuild date :day (%js-date-truncate-or-nan day)))

(defmacro define-js-date-cascading-setter (name docstring (primary-var primary-key) &rest secondary-specs)
  "Define a Date.prototype cascading setter (setHours/setMinutes/setSeconds):
PRIMARY-VAR is required and stored under PRIMARY-KEY; each (VAR KEY) in
SECONDARY-SPECS is an optional trailing component, defaulting to \"leave
unchanged\" when omitted or undefined. A trailing MS parameter is always
accepted and ignored (sub-second ms are preserved separately by
%js-date-rebuild)."
  (let ((params
        (list*
          'date
          primary-var
          '&optional
          (append (mapcar #'first secondary-specs) '(ms)))))
    `(defun ,name ,params
      ,docstring
      (declare (ignore ms))
      (%js-date-rebuild
        date
        ,primary-key
        (%js-date-truncate-or-nan ,primary-var)
        ,@(mapcan
          (lambda (spec)
            (destructuring-bind (var key) spec
              (list
                key
                `(and ,var (not (eq ,var +js-undefined+)) (%js-date-truncate-or-nan ,var)))))
          secondary-specs)))))

(define-js-date-cascading-setter
  %js-date-set-hours
  "Date.prototype.setHours(hours[, min, sec, ms])."
  (hours :hour)
  (min :min)
  (sec :sec))

(define-js-date-cascading-setter
  %js-date-set-minutes
  "Date.prototype.setMinutes(minutes[, sec, ms])."
  (minutes :min)
  (sec :sec))

(define-js-date-cascading-setter
  %js-date-set-seconds
  "Date.prototype.setSeconds(seconds[, ms])."
  (seconds :sec))
