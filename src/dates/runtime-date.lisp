;;;; packages/javascript/src/runtime-date.lisp — JS Date object (ES2026)
;;;;
;;;; Date is represented as a struct wrapping a CL universal-time (seconds
;;;; since 1900-01-01 00:00:00 UTC). JS timestamps are milliseconds since the
;;;; Unix epoch (1970-01-01 00:00:00 UTC).
;;;;
;;;; CL universal-time epoch: 1900-01-01T00:00:00Z
;;;; JS epoch:                1970-01-01T00:00:00Z
;;;; Offset: 2208988800 seconds (70 years including leap years)
(in-package #:cl-cc/javascript/dates)

(defconstant +js-epoch-offset+ 2208988800
  "Seconds from CL universal-time epoch (1900) to Unix epoch (1970).")

;;; -----------------------------------------------------------------------
;;;  js-date struct
;;; -----------------------------------------------------------------------
(defstruct (js-date (:conc-name js-date-)) (ms 0 :type real)) ; milliseconds since Unix epoch (may be negative, or NaN for an Invalid Date)

(defun %js-date-p (x)
  (js-date-p x))

(defun %js-date-invalid-p (date)
  "True when DATE's underlying time value is NaN -- an \"Invalid Date\",
per ECMA-262 (e.g. `new Date(\"garbage\")`, `new Date(NaN)`,
`d.setFullYear(NaN)`)."
  (%js-float-nan-p (js-date-ms date)))

(defun %js-date-truncate-or-nan (x)
  "ToNumber X then TRUNCATE it, except return NaN as-is when the coerced
value is NaN -- TRUNCATE itself signals FLOATING-POINT-INVALID-OPERATION on
a NaN double-float argument (a real process-level crash, not a graceful JS
NaN result), so every Date component setter/constructor argument that
could be NaN must go through here instead of a bare (TRUNCATE ...)."
  (let ((n (%js-to-number x)))
    (if (%js-nan-p n) *js-nan-float* (truncate n))))

;;; -----------------------------------------------------------------------
;;;  Constructors
;;; -----------------------------------------------------------------------
(defun %js-date-now ()
  "Return current time as milliseconds since the Unix epoch (Date.now())."
  (* 1000 (- (get-universal-time) +js-epoch-offset+)))

(defun %js-date-components-to-ms (year month day hour min sec ms)
  "JS Date components (0-based MONTH, UTC) to Unix-epoch milliseconds.
Out-of-range months/days/times roll over as in JS (new Date(2020,12,1) =
Jan 2021, day 32 = next month). Only year+month are passed to
encode-universal-time — day and time are added as millisecond offsets from
the 1st, both for rollover semantics and because encode-universal-time
raises range errors via a hardware trap that hangs on macOS 26.5 ARM64.
Any NaN component makes the whole result NaN (an Invalid Date) --
FLOOR/ENCODE-UNIVERSAL-TIME/+ all crash outright on a NaN argument, so this
must short-circuit before any of them run, not rely on NaN propagating
through the arithmetic below the way IEEE float ops normally would."
  (if (some #'%js-nan-p (list year month day hour min sec ms))
      *js-nan-float*
      (multiple-value-bind (extra-years m) (floor month 12)
        (let ((y (+ year extra-years)))
          (when (< y 1900)
            (error "JS Date year ~A is below the supported range" y))
          (+
            (* 1000 (- (encode-universal-time 0 0 0 1 (1+ m) y 0) +js-epoch-offset+))
            (* (1- day) 86400000)
            (* hour 3600000)
            (* min 60000)
            (* sec 1000)
            ms)))))

(defun %js-date-utc (year &optional (month 0) (day 1) (hour 0) (min 0) (sec 0) (ms 0))
  "Date.UTC(year, month, ...) — epoch milliseconds as a JS number (NaN for
any NaN component)."
  (coerce
    (%js-date-components-to-ms
      (%js-date-truncate-or-nan year)
      (%js-date-truncate-or-nan month)
      (%js-date-truncate-or-nan day)
      (%js-date-truncate-or-nan hour)
      (%js-date-truncate-or-nan min)
      (%js-date-truncate-or-nan sec)
      (%js-date-truncate-or-nan ms))
    'double-float))

(defun %js-make-date (&optional (arg +js-undefined+) &rest more)
  "Construct a JS Date object.
  - No args or undefined → current time
  - Number → Unix epoch milliseconds (NaN → an Invalid Date)
  - Two or more numbers → year, month (0-based), day, hours, minutes, seconds, ms
  - String → parsed ISO-8601 date (simplified)
  - Another Date → copy"
  (cond
    ((or (eq arg +js-undefined+) (eq arg +js-null+))
      (make-js-date :ms (%js-date-now)))
    ((js-date-p arg) (make-js-date :ms (js-date-ms arg)))
    ((and more (numberp arg))
      (destructuring-bind (month &optional (day 1) (hour 0) (min 0) (sec 0) (ms 0)) more
        (make-js-date
          :ms
          (%js-date-components-to-ms
            (%js-date-truncate-or-nan arg)
            (%js-date-truncate-or-nan month)
            (%js-date-truncate-or-nan day)
            (%js-date-truncate-or-nan hour)
            (%js-date-truncate-or-nan min)
            (%js-date-truncate-or-nan sec)
            (%js-date-truncate-or-nan ms)))))
    ((numberp arg) (make-js-date :ms (%js-date-truncate-or-nan arg)))
    ((stringp arg) (make-js-date :ms (%js-date-parse-string arg)))
    (t (make-js-date :ms (%js-date-now)))))

(defun %js-date-parse-string (s)
  "Parse a date string to milliseconds. Supports 'YYYY-MM-DD' and 'YYYY-MM-DDTHH:MM:SS'.
An unparseable string is an Invalid Date (NaN), per ECMA-262 -- NOT the
current time, which would silently substitute a plausible-looking wrong
date for one JS guarantees is detectably invalid."
  (handler-case
      (let* ((trimmed (string-trim '(#\Space) s))
             ;; Extract year, month, day from YYYY-MM-DD prefix
             (year  (parse-integer (subseq trimmed 0 4)))
             (month (parse-integer (subseq trimmed 5 7)))
             (day   (parse-integer (subseq trimmed 8 10)))
             (hour  (if (>= (length trimmed) 13) (parse-integer (subseq trimmed 11 13)) 0))
             (min   (if (>= (length trimmed) 16) (parse-integer (subseq trimmed 14 16)) 0))
             (sec   (if (>= (length trimmed) 19) (parse-integer (subseq trimmed 17 19)) 0)))
        ;; Validate BEFORE encoding: encode-universal-time raises range
        ;; errors via a hardware trap that hangs on macOS 26.5 ARM64; a
        ;; normal error here lands in this handler-case's fallback instead.
        (unless (and (<= 1900 year) (<= 1 month 12) (<= 1 day 31)
                     (<= 0 hour 23) (<= 0 min 59) (<= 0 sec 59))
          (error "invalid date string: ~S" s))
        (* 1000 (- (encode-universal-time sec min hour day month year 0)
                   +js-epoch-offset+)))
    (error () *js-nan-float*)))

;;; -----------------------------------------------------------------------
;;;  Date.prototype accessors — all operate on the local time
;;; -----------------------------------------------------------------------
(defun %js-date-to-decoded (date)
  "Decode a js-date to (sec min hour day month year day-of-week daylight-p
zone). Precondition: DATE must not be invalid (%JS-DATE-INVALID-P) --
FLOOR/DECODE-UNIVERSAL-TIME have no NaN to decode into and would crash;
every caller (the DEFINE-JS-DATE-GETTER macro, %WITH-DATE-FIELDS's own call
sites) checks validity first instead."
  (let ((ut (+ (floor (js-date-ms date) 1000) +js-epoch-offset+)))
    (multiple-value-list (decode-universal-time ut 0)))) ; UTC

(defmacro define-js-date-getter (name index &optional (scale 1) (offset 0))
  `(defun ,name (date)
    (if (%js-date-invalid-p date)
        *js-nan-float*
        (* ,scale (+ ,offset (nth ,index (%js-date-to-decoded date)))))))

(defmacro %with-date-fields ((date
      &key
      (sec (gensym))
      (min (gensym))
      (hour (gensym))
      (day (gensym))
      (month (gensym))
      (year (gensym))
      (dow (gensym)))
    &body
    body)
  "Destructure a decoded js-date into named variables (only name what you need)."
  `(destructuring-bind (,sec ,min ,hour ,day ,month ,year ,dow &rest ,(gensym)) (%js-date-to-decoded ,date)
    (declare (ignorable ,sec ,min ,hour ,day ,month ,year ,dow))
    ,@body))

;;; Date.prototype.getFullYear / getUTCFullYear
(define-js-date-getter %js-date-get-full-year 5)

(define-js-date-getter %js-date-get-utc-full-year 5)

;;; Date.prototype.getMonth (0-based)
(define-js-date-getter %js-date-get-month 4 1 -1) ; CL months 1-12 → JS 0-11

(define-js-date-getter %js-date-get-utc-month 4 1 -1)

;;; Date.prototype.getDate (day of month, 1-based)
(define-js-date-getter %js-date-get-date 3)

(define-js-date-getter %js-date-get-utc-date 3)

;;; Date.prototype.getDay (day of week, 0=Sun)
(define-js-date-getter %js-date-get-day 6)

(define-js-date-getter %js-date-get-utc-day 6)

;;; Date.prototype.getHours / getMinutes / getSeconds
(define-js-date-getter %js-date-get-hours 2)

(define-js-date-getter %js-date-get-utc-hours 2)

(define-js-date-getter %js-date-get-minutes 1)

(define-js-date-getter %js-date-get-utc-minutes 1)

(define-js-date-getter %js-date-get-seconds 0)

(define-js-date-getter %js-date-get-utc-seconds 0)

(defun %js-date-get-milliseconds (date)
  (if (%js-date-invalid-p date) *js-nan-float* (mod (js-date-ms date) 1000)))

(defun %js-date-get-time (date)
  "Date.prototype.getTime() → milliseconds since Unix epoch."
  (coerce (js-date-ms date) 'double-float))

(defun %js-date-get-timezone-offset (date)
  "Date.prototype.getTimezoneOffset() → minutes UTC is AHEAD of the host's
local time (JS's sign convention: positive west of UTC, negative east —
the opposite of a \"+09:00\"-style offset string), via the same cl-date-kit
IANA projection Temporal uses (runtime-temporal.lisp). Falls back to 0 (UTC)
when the host zone is UTC, unknown, or unresolvable — forward-referenced,
not yet defined when this file loads (runtime-temporal.lisp loads later),
but never called before the whole system finishes loading."
  (if (%js-date-invalid-p date)
      *js-nan-float*
      (let ((tz (%temporal-host-time-zone-id)))
        (if (string= tz "UTC") 0.0d0
          (let ((projected (%temporal-zone-project-epoch (floor (js-date-ms date) 1000) tz)))
            (if projected (coerce
                (- (%temporal-offset-string-to-minutes (seventh projected)))
                'double-float)
              0.0d0))))))
