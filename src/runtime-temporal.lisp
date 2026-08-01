;;;; packages/javascript/src/runtime-temporal.lisp — Temporal API (ES2026 Stage 4)
;;;;
;;;; Temporal replaces the Date API with a comprehensive, immutable datetime library.
;;;; We implement the 8 core types as hash-table objects with the standard methods.
;;;; Arithmetic operations use CL's arithmetic on universal-time seconds.
;;;;
;;;; This file: shared helpers, IANA time-zone support, Temporal.Now,
;;;; Temporal.Instant, Temporal.PlainDate, Temporal.PlainYearMonth,
;;;; Temporal.PlainMonthDay — every type with no time-of-day component.
;;;; Temporal.PlainTime/PlainDateTime/ZonedDateTime (the types that do carry
;;;; one) live in the sibling runtime-temporal-datetime.lisp, loaded right
;;;; after this file.

(in-package :cl-cc/javascript)

;;; -----------------------------------------------------------------------
;;;  Shared helpers
;;; -----------------------------------------------------------------------

(defun %temporal-epoch-offset () 2208988800)  ; CL epoch → Unix epoch

(defun %temporal-now-unix-seconds ()
  (- (get-universal-time) (%temporal-epoch-offset)))

(defun %temporal-normalize-number (n &optional (default 0))
  "Normalize Temporal numeric fields before passing them to CL time primitives."
  (if (numberp n)
      (truncate n)
      default))

(defun %temporal-decode (unix-seconds)
  "Decode Unix seconds to (values sec min hour day month year dow)."
  (let ((ut (+ (%temporal-normalize-number unix-seconds) (%temporal-epoch-offset))))
    (multiple-value-bind (s mn h d m y dow) (decode-universal-time ut 0)
      (values s mn h d m y dow))))

(defun %temporal-encode (year month day &optional (hour 0) (min 0) (sec 0))
  (let ((y (%temporal-normalize-number year))
        (mo (%temporal-normalize-number month))
        (d (%temporal-normalize-number day))
        (h (%temporal-normalize-number hour))
        (mi (%temporal-normalize-number min))
        (s (%temporal-normalize-number sec)))
    ;; encode-universal-time raises out-of-range field errors via a hardware
    ;; trap; on macOS 26.5 ARM64 trap delivery hangs the thread (SBCL
    ;; runtime/OS regression), so reject invalid fields with a normal error
    ;; that the parse-fallback handler-cases can catch.
    (unless (and (<= 1900 y) (<= 1 mo 12) (<= 1 d 31)
                 (<= 0 h 23) (<= 0 mi 59) (<= 0 s 59))
      (error "invalid date-time fields: ~4,'0D-~2,'0D-~2,'0D ~2,'0D:~2,'0D:~2,'0D"
             y mo d h mi s))
    (- (encode-universal-time s mi h d mo y 0)
       (%temporal-epoch-offset))))

(defun %temporal-pad (n width)
  (format nil "~v,'0D" width n))

(defun %temporal-3way-compare (a b)
  "Return -1.0d0, 0.0d0, or 1.0d0 for ordered comparison of numeric A and B."
  (cond ((< a b) -1.0d0) ((> a b) 1.0d0) (t 0.0d0)))

(defun %temporal-parse-time-fields (s)
  "Parse a time string \"HH:MM:SS\" into (values hour minute second)."
  (flet ((field (start end) (if (>= (length s) end) (parse-integer s :start start :end end) 0)))
    (values (field 0 2) (field 3 5) (field 6 8))))

(defun %temporal-shift-encoded (encoded-seconds delta-seconds rebuild-fn)
  "Add DELTA-SECONDS to ENCODED-SECONDS, decode the result, and pass its
\(second minute hour day month year) fields to REBUILD-FN. Shared by every
PlainDate/PlainDateTime add/subtract pair: subtract calls this with a
negated DELTA-SECONDS."
  (multiple-value-bind (s mn h d m y) (%temporal-decode (+ encoded-seconds delta-seconds))
    (funcall rebuild-fn s mn h d m y)))

;;; -----------------------------------------------------------------------
;;;  IANA time zone support (cl-date-kit)
;;;
;;;  cl-date-kit resolves a *supplied* IANA zone name against the host's
;;;  copy of the tzdata database; it does not discover which zone the host
;;;  is configured for, and every lookup depends on tzdata actually being
;;;  present on disk (it is not bundled -- see cl-date-kit's own
;;;  Compatibility doc). Every entry point below is therefore wrapped so
;;;  that an unknown zone name, a missing zoneinfo tree (routine inside a
;;;  Nix build sandbox), or any other failure degrades to the pre-existing
;;;  UTC-only behavior rather than signaling out to JS.
;;; -----------------------------------------------------------------------

(defun %temporal-valid-iana-zone-p (name)
  "True when NAME resolves to a real zone via cl-date-kit's tzdata lookup."
  (and (stringp name) (plusp (length name))
       (ignore-errors (find-time-zone name) t)))

(defparameter *%temporal-host-time-zone-id* nil
  "Cache for %TEMPORAL-HOST-TIME-ZONE-ID, computed lazily on first use.")

(defun %temporal-discover-host-time-zone-id ()
  "Best-effort discovery of the host's configured IANA time zone name.
cl-date-kit has no lookup for this -- it resolves a name you already have,
it does not tell you which one the host is set to -- so this reads the two
conventional Unix sources directly and hands the candidate to cl-date-kit
for validation:

  1. TZ, when it already names a bare IANA zone (\"America/New_York\")
     rather than a POSIX TZ rule string (\"EST5EDT,M3.2.0,M11.1.0\");
     cl-date-kit rejects the latter as an unrecognized zone, which is
     exactly the discriminator wanted here.
  2. /etc/localtime, the conventional symlink into the system zoneinfo
     tree on macOS and most Linux distributions. TRUENAME resolves it
     (through /var/db/timezone/... on macOS, directly on most Linux) and
     the IANA name is whatever follows the last \"zoneinfo/\" path
     component.

Returns \"UTC\" when neither source yields a name cl-date-kit recognizes --
including inside a build sandbox, which typically has neither TZ set nor a
readable /etc/localtime."
  (or (let ((tz (host-kit:getenv "TZ")))
        (and (%temporal-valid-iana-zone-p tz) tz))
      (let ((resolved (ignore-errors (namestring (truename "/etc/localtime")))))
        (when resolved
          (let ((pos (search "zoneinfo/" resolved :from-end t)))
            (when pos
              (let ((name (string-right-trim "/" (subseq resolved (+ pos (length "zoneinfo/"))))))
                (and (%temporal-valid-iana-zone-p name) name))))))
      "UTC"))

(defun %temporal-host-time-zone-id ()
  "The host's IANA time zone name, discovered once and cached."
  (or *%temporal-host-time-zone-id*
      (setf *%temporal-host-time-zone-id* (%temporal-discover-host-time-zone-id))))

(defun %temporal-zone-project-epoch (epoch-seconds tz)
  "Project the absolute EPOCH-SECONDS instant into IANA zone TZ, returning a
\(YEAR MONTH DAY HOUR MINUTE SECOND OFFSET-STRING\) list, or NIL when TZ is
not a zone cl-date-kit can resolve right now.

This is an instant -> local-zone projection (via ZONED-DATE-TIME-OF-EPOCH-
SECOND), never the reverse: it always has exactly one answer; unlike
resolving a wall-clock reading against a zone, it can never land in a
daylight-saving gap or overlap, so there is no disambiguation policy to get
wrong here."
  (when (%temporal-valid-iana-zone-p tz)
    (ignore-errors
     (let* ((zone (find-time-zone tz))
            (zdt (zoned-date-time-of-epoch-second (truncate epoch-seconds) 0 zone))
            (offset (format-zone-offset (zoned-date-time-offset zdt))))
       (list (zoned-date-time-year zdt) (zoned-date-time-month zdt) (zoned-date-time-day zdt)
             (zoned-date-time-hour zdt) (zoned-date-time-minute zdt) (zoned-date-time-second zdt)
             ;; Temporal.ZonedDateTime#toString always shows an explicit
             ;; offset, unlike Instant#toString; cl-date-kit's formatter
             ;; writes bare "Z" for a zero offset, so normalize it.
             (if (string= offset "Z") "+00:00" offset))))))

(defun %temporal-offset-string-to-minutes (offset)
  "Parse a cl-date-kit \"+HH:MM\"/\"-HH:MM\" offset string (as returned by
%TEMPORAL-ZONE-PROJECT-EPOCH) into signed minutes east of UTC -- the same
sign as the string itself. Callers needing JS's getTimezoneOffset()
convention (positive west, negative east) must negate this."
  (let ((sign (if (char= (char offset 0) #\-) -1 1))
        (hours (parse-integer offset :start 1 :end 3))
        (minutes (parse-integer offset :start 4 :end 6)))
    (* sign (+ (* hours 60) minutes))))

;;; -----------------------------------------------------------------------
;;;  Temporal.Now
;;; -----------------------------------------------------------------------

(defun %js-temporal-now ()
  (%js-make-object
   "instant"         (lambda () (%js-temporal-instant (%temporal-now-unix-seconds)))
   "plainDateTimeISO" (lambda (&optional _tz)
                        (declare (ignore _tz))
                        (multiple-value-bind (s mn h d m y)
                            (%temporal-decode (%temporal-now-unix-seconds))
                          (%js-temporal-plain-datetime y m d h mn s)))
   "plainDateISO"    (lambda (&optional _tz)
                        (declare (ignore _tz))
                        (multiple-value-bind (s mn h d m y)
                            (%temporal-decode (%temporal-now-unix-seconds))
                          (declare (ignore s mn h))
                          (%js-temporal-plain-date y m d)))
   "plainTimeISO"    (lambda (&optional _tz)
                        (declare (ignore _tz))
                        (multiple-value-bind (s mn h)
                            (%temporal-decode (%temporal-now-unix-seconds))
                          (%js-temporal-plain-time h mn s)))
   "zonedDateTimeISO" (lambda (&optional tz)
                        (multiple-value-bind (s mn h d m y)
                            (%temporal-decode (%temporal-now-unix-seconds))
                          (%js-temporal-zoned-datetime
                           y m d h mn s (or tz (%temporal-host-time-zone-id)))))
   "timeZoneId"      (lambda () (%temporal-host-time-zone-id))))

;;; -----------------------------------------------------------------------
;;;  Temporal.Instant
;;; -----------------------------------------------------------------------

(defun %js-temporal-instant (unix-seconds)
  (let ((ts unix-seconds))
    (%js-make-object
     "__type__"         "Temporal.Instant"
     "epochSeconds"     (coerce ts 'double-float)
     "epochMilliseconds" (coerce (* ts 1000) 'double-float)
     "epochMicroseconds" (coerce (* ts 1000000) 'double-float)
     "epochNanoseconds"  (coerce (* ts 1000000000) 'double-float)
     "toString"          (lambda (&optional _opts) (declare (ignore _opts))
                           (multiple-value-bind (s mn h d m y) (%temporal-decode ts)
                             (format nil "~A-~A-~AT~A:~A:~AZ"
                                     (%temporal-pad y 4) (%temporal-pad m 2) (%temporal-pad d 2)
                                     (%temporal-pad h 2) (%temporal-pad mn 2) (%temporal-pad s 2))))
     "toZonedDateTimeISO" (lambda (&optional tz)
                            (multiple-value-bind (s mn h d m y) (%temporal-decode ts)
                              (%js-temporal-zoned-datetime
                               y m d h mn s (or tz (%temporal-host-time-zone-id)))))
     "add"               (lambda (duration)
                           (%js-temporal-instant (+ ts (%temporal-duration-to-seconds duration))))
     "subtract"          (lambda (duration)
                           (%js-temporal-instant (- ts (%temporal-duration-to-seconds duration))))
     "equals"            (lambda (other)
                           (= ts (or (gethash "epochSeconds" other) 0)))
     "compare"           (lambda (other)
                           (%temporal-3way-compare ts (or (gethash "epochSeconds" other) 0))))))

;;; -----------------------------------------------------------------------
;;;  Temporal.PlainDate
;;; -----------------------------------------------------------------------

(defun %js-temporal-plain-date (year month day)
  (let ((y year) (m month) (d day))
    (%js-make-object
     "__type__"   "Temporal.PlainDate"
     "year"       (coerce y 'double-float)
     "month"      (coerce m 'double-float)
     "day"        (coerce d 'double-float)
     "calendarId" "iso8601"
     "dayOfWeek"  (coerce (1+ (nth-value 6 (%temporal-decode (%temporal-encode y m d))))
                          'double-float)
     "toString"   (lambda () (format nil "~A-~A-~A"
                                     (%temporal-pad y 4) (%temporal-pad m 2) (%temporal-pad d 2)))
     "toPlainDateTime" (lambda (&optional plain-time)
                         (if (and plain-time (gethash "hour" plain-time))
                             (%js-temporal-plain-datetime y m d
                                                          (gethash "hour" plain-time)
                                                          (gethash "minute" plain-time)
                                                          (gethash "second" plain-time))
                             (%js-temporal-plain-datetime y m d 0 0 0)))
     "add"        (lambda (duration)
                    (%temporal-shift-encoded
                     (%temporal-encode y m d) (%temporal-duration-to-seconds duration)
                     (lambda (s mn h nd nm ny)
                       (declare (ignore s mn h))
                       (%js-temporal-plain-date ny nm nd))))
     "subtract"   (lambda (duration)
                    (%temporal-shift-encoded
                     (%temporal-encode y m d) (- (%temporal-duration-to-seconds duration))
                     (lambda (s mn h nd nm ny)
                       (declare (ignore s mn h))
                       (%js-temporal-plain-date ny nm nd))))
     "equals"     (lambda (other)
                    (and (= y (gethash "year" other))
                         (= m (gethash "month" other))
                         (= d (gethash "day" other))))
     "compare"    (lambda (other)
                    (%temporal-3way-compare
                     (%temporal-encode y m d)
                     (%temporal-encode (gethash "year" other)
                                       (gethash "month" other)
                                       (gethash "day" other)))))))

;;; Temporal.PlainTime, Temporal.PlainDateTime, and Temporal.ZonedDateTime —
;;; the three types carrying a time-of-day component — live in
;;; runtime-temporal-datetime.lisp. Temporal.Duration and parse helpers live
;;; in runtime-temporal-duration.lisp and runtime-temporal-parse.lisp.

(defun %js-temporal-plain-year-month (year month)
  (%js-make-object
   "__type__" "Temporal.PlainYearMonth"
   "year"     (coerce year 'double-float)
   "month"    (coerce month 'double-float)
   "toString" (lambda () (format nil "~A-~A" (%temporal-pad year 4) (%temporal-pad month 2)))))

(defun %js-temporal-plain-month-day (month day)
  (%js-make-object
   "__type__" "Temporal.PlainMonthDay"
   "month"    (coerce month 'double-float)
   "day"      (coerce day 'double-float)
   "toString" (lambda () (format nil "--~A-~A" (%temporal-pad month 2) (%temporal-pad day 2)))))

;;; The Temporal global object lives in runtime-temporal-global.lisp.
