;;;; packages/javascript/src/runtime-temporal-datetime.lisp — Temporal wall-clock types (ES2026 Stage 4)
;;;;
;;;; Temporal.PlainTime, Temporal.PlainDateTime, and Temporal.ZonedDateTime —
;;;; the three core Temporal types that carry a time-of-day component, split
;;;; out of runtime-temporal.lisp (which keeps Instant/PlainDate/
;;;; PlainYearMonth/PlainMonthDay, the types that don't) to stay near the
;;;; org's 300-line file guideline. Shared helpers (%temporal-decode,
;;;; %temporal-encode, %temporal-shift-encoded, %temporal-pad,
;;;; %temporal-3way-compare, ...) and the IANA time-zone support these types
;;;; call still live in runtime-temporal.lisp, loaded first.
;;;;
;;;; Load order: after runtime-temporal.lisp.

(in-package :cl-cc/javascript)

;;; -----------------------------------------------------------------------
;;;  Temporal.PlainTime
;;; -----------------------------------------------------------------------

(defun %js-temporal-plain-time (hour minute second &optional (ms 0) (us 0) (ns 0))
  (let ((h hour) (mn minute) (s second))
    (declare (ignore ms us ns))
    (%js-make-object
     "__type__"   "Temporal.PlainTime"
     "hour"       (coerce h 'double-float)
     "minute"     (coerce mn 'double-float)
     "second"     (coerce s 'double-float)
     "millisecond" 0.0d0
     "microsecond" 0.0d0
     "nanosecond"  0.0d0
     "toString"   (lambda () (format nil "~A:~A:~A"
                                     (%temporal-pad h 2) (%temporal-pad mn 2) (%temporal-pad s 2)))
     "add"        (lambda (duration)
                    (let* ((total (+ (* h 3600) (* mn 60) s
                                     (%temporal-duration-to-seconds duration)))
                           (new-h (mod (floor total 3600) 24))
                           (new-mn (mod (floor (mod total 3600) 60) 60))
                           (new-s (mod total 60)))
                      (%js-temporal-plain-time new-h new-mn (floor new-s))))
     "equals"     (lambda (other)
                    (and (= h (gethash "hour" other))
                         (= mn (gethash "minute" other))
                         (= s (gethash "second" other)))))))

;;; -----------------------------------------------------------------------
;;;  Temporal.PlainDateTime
;;; -----------------------------------------------------------------------

(defun %js-temporal-plain-datetime (year month day hour minute second)
  (let ((y year) (m month) (d day) (h hour) (mn minute) (s second))
    (%js-make-object
     "__type__"   "Temporal.PlainDateTime"
     "year"       (coerce y 'double-float)
     "month"      (coerce m 'double-float)
     "day"        (coerce d 'double-float)
     "hour"       (coerce h 'double-float)
     "minute"     (coerce mn 'double-float)
     "second"     (coerce s 'double-float)
     "millisecond" 0.0d0
     "microsecond" 0.0d0
     "nanosecond"  0.0d0
     "calendarId" "iso8601"
     "toString"   (lambda (&optional _opts) (declare (ignore _opts))
                   (format nil "~A-~A-~AT~A:~A:~A"
                           (%temporal-pad y 4) (%temporal-pad m 2) (%temporal-pad d 2)
                           (%temporal-pad h 2) (%temporal-pad mn 2) (%temporal-pad s 2)))
     "toPlainDate" (lambda () (%js-temporal-plain-date y m d))
     "toPlainTime" (lambda () (%js-temporal-plain-time h mn s))
     "toInstant"   (lambda (&optional _tz) (declare (ignore _tz))
                    (%js-temporal-instant (%temporal-encode y m d h mn s)))
     "add"         (lambda (duration)
                     (%temporal-shift-encoded
                      (%temporal-encode y m d h mn s) (%temporal-duration-to-seconds duration)
                      (lambda (ns nmn nh nd nm ny)
                        (%js-temporal-plain-datetime ny nm nd nh nmn ns))))
     "subtract"    (lambda (duration)
                     (%temporal-shift-encoded
                      (%temporal-encode y m d h mn s) (- (%temporal-duration-to-seconds duration))
                      (lambda (ns nmn nh nd nm ny)
                        (%js-temporal-plain-datetime ny nm nd nh nmn ns))))
     "equals"      (lambda (other)
                     (= (%temporal-encode y m d h mn s)
                        (%temporal-encode (gethash "year" other)
                                          (gethash "month" other)
                                          (gethash "day" other)
                                          (gethash "hour" other)
                                          (gethash "minute" other)
                                          (gethash "second" other)))))))

;;; -----------------------------------------------------------------------
;;;  Temporal.ZonedDateTime
;;; -----------------------------------------------------------------------

(defun %js-temporal-zoned-datetime (year month day hour minute second tz)
  "YEAR/MONTH/DAY/HOUR/MINUTE/SECOND are always treated as the UTC calendar
fields of an absolute instant (every call site derives them via
%TEMPORAL-DECODE of some epoch value, directly or by round-trip), which
%TEMPORAL-ENCODE below turns back into that same epoch exactly. When TZ
names a zone cl-date-kit can resolve, that epoch is then projected into TZ
for the local display fields and offset -- an unambiguous instant -> local
projection, never the reverse, so there is no daylight-saving gap/overlap
policy involved. EPOCH-SECONDS itself is always the reconstructed absolute
instant, never recomputed from the (possibly zone-projected) display
fields, so it is stable regardless of whether projection happens to
succeed."
  (let* ((epoch-seconds (%temporal-encode year month day hour minute second))
         (projected (and tz (stringp tz) (not (string-equal tz "UTC"))
                          (%temporal-zone-project-epoch epoch-seconds tz))))
    (destructuring-bind (y m d h mn s offset)
        (or projected (list year month day hour minute second "+00:00"))
      (%js-make-object
       "__type__"     "Temporal.ZonedDateTime"
       "year"         (coerce y 'double-float)
       "month"        (coerce m 'double-float)
       "day"          (coerce d 'double-float)
       "hour"         (coerce h 'double-float)
       "minute"       (coerce mn 'double-float)
       "second"       (coerce s 'double-float)
       "millisecond"  0.0d0
       "microsecond"  0.0d0
       "nanosecond"   0.0d0
       "timeZoneId"   tz
       "calendarId"   "iso8601"
       "epochSeconds" (coerce epoch-seconds 'double-float)
       "toString"     (lambda (&optional _opts) (declare (ignore _opts))
                       (format nil "~A-~A-~AT~A:~A:~A~A[~A]"
                               (%temporal-pad y 4) (%temporal-pad m 2) (%temporal-pad d 2)
                               (%temporal-pad h 2) (%temporal-pad mn 2) (%temporal-pad s 2)
                               offset tz))
       "toPlainDate"  (lambda () (%js-temporal-plain-date y m d))
       "toPlainTime"  (lambda () (%js-temporal-plain-time h mn s))
       "toPlainDateTime" (lambda () (%js-temporal-plain-datetime y m d h mn s))
       "toInstant"    (lambda () (%js-temporal-instant epoch-seconds))))))
