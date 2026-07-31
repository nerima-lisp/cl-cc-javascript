;;;; t/runtime-temporal-test.lisp
;;;;
;;;; Split from runtime-date-json-test.lisp: Temporal helper functions
;;;; (padding, 3-way compare, ISO field parsing) and the full Temporal.*
;;;; object surface (Instant, PlainDate, PlainTime, PlainDateTime,
;;;; ZonedDateTime, Duration, PlainYearMonth, PlainMonthDay, and their
;;;; global factories).
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr)

(in-package :cl-cc-javascript/test)

;;; ─── Temporal helper functions ───────────────────────────────────────────────

(it-sequential-each ((2025 4 "2025") (3 2 "03") (15 2 "15") (9 1 "9"))
    "js-rt-temporal-pad ~A"
    (n width expected)
  (expect (cl-cc/javascript::%temporal-pad n width) :to-equal expected))

(it-sequential-each ((1 2 -1.0d0) (5 5 0.0d0) (9 3 1.0d0))
    "js-rt-temporal-3way-compare ~A/~A"
    (a b expected)
  (expect (= expected (cl-cc/javascript::%temporal-3way-compare a b)) :to-be-truthy))

(it-sequential-each (("2025-06-13T14:30:00" 2025 6 13 14 30 0)
                     ("2025-01-01" 2025 1 1 0 0 0))
    "js-rt-temporal-parse-iso-fields ~S"
    (s exp-y exp-mo exp-d exp-h exp-mi exp-s)
  (multiple-value-bind (y mo d h mi sec) (cl-cc/javascript::%temporal-parse-iso-fields s)
    (expect (= exp-y y) :to-be-truthy)
    (expect (= exp-mo mo) :to-be-truthy)
    (expect (= exp-d d) :to-be-truthy)
    (expect (= exp-h h) :to-be-truthy)
    (expect (= exp-mi mi) :to-be-truthy)
    (expect (= exp-s sec) :to-be-truthy)))

(it-sequential-each (("hours" 1 3600) ("minutes" 1 60) ("seconds" 1 1) ("days" 1 86400))
    "js-rt-temporal-duration-to-seconds ~A"
    (unit n expected)
  (let ((dur (cl-cc/javascript::%js-make-object unit (coerce n 'double-float))))
    (expect (= expected (cl-cc/javascript::%temporal-duration-to-seconds dur)) :to-be-truthy)))

(it-sequential "js-rt-temporal-parse-time-fields"
  (multiple-value-bind (h m s) (cl-cc/javascript::%temporal-parse-time-fields "14:30:05")
    (expect (= 14 h) :to-be-truthy)
    (expect (= 30 m) :to-be-truthy)
    (expect (= 5 s) :to-be-truthy)))

(it-sequential "js-rt-temporal-now-object"
  (let* ((now (cl-cc/javascript::%js-temporal-now))
         (instant (funcall (gethash "instant" now)))
         (plain-datetime (funcall (gethash "plainDateTimeISO" now)))
         (plain-date (funcall (gethash "plainDateISO" now)))
         (plain-time (funcall (gethash "plainTimeISO" now)))
         (zoned-datetime (funcall (gethash "zonedDateTimeISO" now)))
         (tz-id (funcall (gethash "timeZoneId" now))))
    ;; The host's real IANA zone name, not a literal "UTC": either "UTC"
    ;; itself (a legitimate answer, and what any TZ-less/localtime-less
    ;; sandbox falls back to) or a "Region/City"-shaped IANA name.
    (expect (stringp tz-id) :to-be-truthy)
    (expect (or (string= tz-id "UTC") (find #\/ tz-id)) :to-be-truthy)
    (expect (gethash "__type__" instant) :to-equal "Temporal.Instant")
    (expect (gethash "__type__" plain-datetime) :to-equal "Temporal.PlainDateTime")
    (expect (gethash "__type__" plain-date) :to-equal "Temporal.PlainDate")
    (expect (gethash "__type__" plain-time) :to-equal "Temporal.PlainTime")
    (expect (gethash "__type__" zoned-datetime) :to-equal "Temporal.ZonedDateTime")))

(it-sequential "js-rt-temporal-instant-methods"
  (let* ((instant (cl-cc/javascript::%js-temporal-instant 0))
         (duration (cl-cc/javascript::%js-temporal-duration :hours 1 :minutes 30))
         (added (funcall (gethash "add" instant) duration))
         (subtracted (funcall (gethash "subtract" added) duration))
         (zoned (funcall (gethash "toZonedDateTimeISO" instant))))
    (expect (funcall (gethash "toString" instant)) :to-equal "1970-01-01T00:00:00Z")
    (expect (= 5400.0d0 (gethash "epochSeconds" added)) :to-be-truthy)
    (expect (= 0.0d0 (gethash "epochSeconds" subtracted)) :to-be-truthy)
    (expect (funcall (gethash "equals" instant) subtracted) :to-be-truthy)
    (expect (= -1.0d0 (funcall (gethash "compare" instant) added)) :to-be-truthy)
    (let ((tz-id (gethash "timeZoneId" zoned)))
      (expect (stringp tz-id) :to-be-truthy)
      (expect (or (string= tz-id "UTC") (find #\/ tz-id)) :to-be-truthy))))

(it-sequential "js-rt-temporal-plain-date-methods"
  (let* ((date (cl-cc/javascript::%js-temporal-plain-date 2025 6 18))
         (datetime (funcall (gethash "toPlainDateTime" date))))
    (expect (funcall (gethash "toString" date)) :to-equal "2025-06-18")
    (expect (= 3.0d0 (gethash "dayOfWeek" date)) :to-be-truthy)
    (expect (funcall (gethash "toString" datetime)) :to-equal "2025-06-18T00:00:00")))

(it-sequential "js-rt-temporal-plain-date-extended"
  (let* ((date (cl-cc/javascript::%js-temporal-plain-date 2025 6 18))
         (time (cl-cc/javascript::%js-temporal-plain-time 7 8 9))
         (duration (cl-cc/javascript::%js-temporal-duration :days 1))
         (datetime (funcall (gethash "toPlainDateTime" date) time))
         (added (funcall (gethash "add" date) duration))
         (subtracted (funcall (gethash "subtract" added) duration)))
    (expect (gethash "__type__" datetime) :to-equal "Temporal.PlainDateTime")
    (expect (= 2025.0d0 (gethash "year" datetime)) :to-be-truthy)
    (expect (= 6.0d0 (gethash "month" datetime)) :to-be-truthy)
    (expect (= 18.0d0 (gethash "day" datetime)) :to-be-truthy)
    (expect (= 7.0d0 (gethash "hour" datetime)) :to-be-truthy)
    (expect (= 8.0d0 (gethash "minute" datetime)) :to-be-truthy)
    (expect (= 9.0d0 (gethash "second" datetime)) :to-be-truthy)
    (expect (funcall (gethash "toString" added)) :to-equal "2025-06-19")
    (expect (funcall (gethash "toString" subtracted)) :to-equal "2025-06-18")
    (expect (= -1.0d0 (funcall (gethash "compare" date) added)) :to-be-truthy)
    (expect (funcall (gethash "equals" date)
                          (cl-cc/javascript::%js-temporal-plain-date 2025 6 18)) :to-be-truthy)))

(it-sequential "js-rt-temporal-plain-time-methods"
  (let* ((time (cl-cc/javascript::%js-temporal-plain-time 23 59 30))
         (duration (cl-cc/javascript::%js-temporal-duration :seconds 90))
         (added (funcall (gethash "add" time) duration)))
    (expect (funcall (gethash "toString" time)) :to-equal "23:59:30")
    (expect (funcall (gethash "toString" added)) :to-equal "00:01:00")
    (expect (funcall (gethash "equals" added)
                          (cl-cc/javascript::%js-temporal-plain-time 0 1 0)) :to-be-truthy)))

(it-sequential "js-rt-temporal-plain-datetime-methods"
  (let* ((datetime (cl-cc/javascript::%js-temporal-plain-datetime 2025 6 18 12 34 56))
         (plain-date (funcall (gethash "toPlainDate" datetime)))
         (plain-time (funcall (gethash "toPlainTime" datetime))))
    (expect (funcall (gethash "toString" datetime)) :to-equal "2025-06-18T12:34:56")
    (expect (funcall (gethash "toString" plain-date)) :to-equal "2025-06-18")
    (expect (funcall (gethash "toString" plain-time)) :to-equal "12:34:56")))

(it-sequential "js-rt-temporal-plain-datetime-extended"
  (let* ((datetime (cl-cc/javascript::%js-temporal-plain-datetime 2025 6 18 12 34 56))
         (duration (cl-cc/javascript::%js-temporal-duration :seconds 4))
         (added (funcall (gethash "add" datetime) duration))
         (subtracted (funcall (gethash "subtract" added) duration))
         (instant (funcall (gethash "toInstant" datetime))))
    (expect (funcall (gethash "toString" datetime)) :to-equal "2025-06-18T12:34:56")
    (expect (funcall (gethash "toString" added)) :to-equal "2025-06-18T12:35:00")
    (expect (funcall (gethash "toString" subtracted)) :to-equal "2025-06-18T12:34:56")
    (expect (gethash "__type__" instant) :to-equal "Temporal.Instant")
    (expect (funcall (gethash "equals" datetime)
                          (cl-cc/javascript::%js-temporal-plain-datetime 2025 6 18 12 34 56)) :to-be-truthy)))

(it-sequential "js-rt-temporal-zoned-datetime-methods"
  (let* ((zoned (cl-cc/javascript::%js-temporal-zoned-datetime 2025 6 18 12 34 56 "UTC"))
         (plain-datetime (funcall (gethash "toPlainDateTime" zoned)))
         (plain-date (funcall (gethash "toPlainDate" zoned)))
         (plain-time (funcall (gethash "toPlainTime" zoned)))
         (instant (funcall (gethash "toInstant" zoned))))
    (expect (funcall (gethash "toString" zoned)) :to-equal "2025-06-18T12:34:56+00:00[UTC]")
    (expect (funcall (gethash "toString" plain-datetime)) :to-equal "2025-06-18T12:34:56")
    (expect (funcall (gethash "toString" plain-date)) :to-equal "2025-06-18")
    (expect (funcall (gethash "toString" plain-time)) :to-equal "12:34:56")
    (expect (gethash "__type__" instant) :to-equal "Temporal.Instant")))

;;; ─── IANA time zone support (cl-date-kit) ────────────────────────────────────

(it-sequential "js-rt-temporal-valid-iana-zone-p"
  (expect (cl-cc/javascript::%temporal-valid-iana-zone-p "UTC") :to-be-truthy)
  (expect (not (cl-cc/javascript::%temporal-valid-iana-zone-p "Not/AZone")) :to-be-truthy)
  (expect (not (cl-cc/javascript::%temporal-valid-iana-zone-p nil)) :to-be-truthy)
  (expect (not (cl-cc/javascript::%temporal-valid-iana-zone-p "")) :to-be-truthy))

(it-sequential "js-rt-temporal-host-time-zone-id"
  (let ((tz-id (cl-cc/javascript::%temporal-host-time-zone-id)))
    ;; "UTC" is a legitimate answer (and what any TZ-less, /etc/localtime-less
    ;; environment -- including a Nix build sandbox -- falls back to); a
    ;; "Region/City"-shaped IANA name is the other legitimate shape.
    (expect (stringp tz-id) :to-be-truthy)
    (expect (or (string= tz-id "UTC") (find #\/ tz-id)) :to-be-truthy)
    ;; Discovered once and cached: a second call returns the same object.
    (expect (eq tz-id (cl-cc/javascript::%temporal-host-time-zone-id)) :to-be-truthy)))

(it-sequential "js-rt-temporal-zone-project-epoch-unknown-zone"
  (expect (not (cl-cc/javascript::%temporal-zone-project-epoch 0 "Not/AZone")) :to-be-truthy)
  (expect (not (cl-cc/javascript::%temporal-zone-project-epoch 0 "")) :to-be-truthy)
  (expect (not (cl-cc/javascript::%temporal-zone-project-epoch 0 nil)) :to-be-truthy))

(it-sequential "js-rt-temporal-zone-project-epoch-fixed-offset-zone"
  ;; Asia/Tokyo has held a fixed +09:00 offset with no DST for the entire
  ;; Unix epoch, so projecting epoch 0 into it is not date-sensitive the way
  ;; most IANA zones (with historical or seasonal transitions) would be.
  ;; Guarded by %temporal-valid-iana-zone-p rather than asserted
  ;; unconditionally: this primitive depends on a real IANA tzdata copy
  ;; being reachable (via TZDIR or /usr/share/zoneinfo), which `nix build`
  ;; guarantees (see flake.nix's `checks.default`) but a bare `sbcl --script`
  ;; invocation on a host with no zoneinfo tree would not.
  (when (cl-cc/javascript::%temporal-valid-iana-zone-p "Asia/Tokyo")
    (let ((projected (cl-cc/javascript::%temporal-zone-project-epoch 0 "Asia/Tokyo")))
      (expect projected :to-be-truthy)
      (destructuring-bind (y m d h mn s offset) projected
        (expect (= y 1970) :to-be-truthy)
        (expect (= m 1) :to-be-truthy)
        (expect (= d 1) :to-be-truthy)
        (expect (= h 9) :to-be-truthy)
        (expect (zerop mn) :to-be-truthy)
        (expect (zerop s) :to-be-truthy)
        (expect (string= offset "+09:00") :to-be-truthy)))))

(it-sequential "js-rt-temporal-offset-string-to-minutes"
  ;; Same sign as the string itself (east-of-UTC positive) -- callers wanting
  ;; JS's getTimezoneOffset() convention (west-of-UTC positive) negate this;
  ;; see %js-date-get-timezone-offset in runtime-date.lisp.
  (expect (= 540 (cl-cc/javascript::%temporal-offset-string-to-minutes "+09:00")) :to-be-truthy)
  (expect (= -300 (cl-cc/javascript::%temporal-offset-string-to-minutes "-05:00")) :to-be-truthy)
  (expect (zerop (cl-cc/javascript::%temporal-offset-string-to-minutes "+00:00")) :to-be-truthy)
  (expect (= 30 (cl-cc/javascript::%temporal-offset-string-to-minutes "+00:30")) :to-be-truthy))

(it-sequential "js-rt-temporal-zoned-datetime-non-utc-zone"
  (let* ((zoned (cl-cc/javascript::%js-temporal-zoned-datetime 1970 1 1 0 0 0 "Asia/Tokyo"))
         (instant (funcall (gethash "toInstant" zoned))))
    ;; epochSeconds is always the true absolute instant (0 here, from
    ;; 1970-01-01T00:00:00 treated as UTC calendar fields per
    ;; %JS-TEMPORAL-ZONED-DATETIME's contract) regardless of whether IANA
    ;; zone projection for display succeeds.
    (expect (= 0.0d0 (gethash "epochSeconds" zoned)) :to-be-truthy)
    (expect (gethash "__type__" instant) :to-equal "Temporal.Instant")
    (expect (= 0.0d0 (gethash "epochSeconds" instant)) :to-be-truthy)
    (when (cl-cc/javascript::%temporal-valid-iana-zone-p "Asia/Tokyo")
      (expect (= 9.0d0 (gethash "hour" zoned)) :to-be-truthy)
      (expect (funcall (gethash "toString" zoned))
              :to-equal "1970-01-01T09:00:00+09:00[Asia/Tokyo]"))))

(it-sequential "js-rt-temporal-zoned-datetime-unrecognized-zone-falls-back"
  ;; An unrecognized zone name degrades to the pre-existing UTC-offset
  ;; display under that (mislabeled) zone name rather than erroring.
  (let ((zoned (cl-cc/javascript::%js-temporal-zoned-datetime 2025 6 18 12 34 56 "Not/AZone")))
    (expect (funcall (gethash "toString" zoned)) :to-equal "2025-06-18T12:34:56+00:00[Not/AZone]")
    (expect (= (cl-cc/javascript::%temporal-encode 2025 6 18 12 34 56)
               (gethash "epochSeconds" zoned))
            :to-be-truthy)))

(it-sequential "js-rt-temporal-duration-methods"
  (let* ((duration (cl-cc/javascript::%js-temporal-duration :years 1 :months 2 :weeks 3 :days 4 :hours 5 :minutes 6 :seconds 7))
         (negative (cl-cc/javascript::%js-temporal-duration :hours -2 :minutes -30))
         (abs-duration (funcall (gethash "abs" negative)))
         (negated (funcall (gethash "negated" duration))))
    (expect (funcall (gethash "toString" duration)) :to-equal "P1Y2M3W4DT5H6M7S")
    (expect (= 1.0d0 (gethash "sign" duration)) :to-be-truthy)
    (expect (= -1.0d0 (gethash "sign" negative)) :to-be-truthy)
    (expect (funcall (gethash "toString" abs-duration)) :to-equal "P0Y0M0W0DT2H30M0S")
    (expect (funcall (gethash "toString" negated)) :to-equal "P-1Y-2M-3W-4DT-5H-6M-7S")
    (expect (= 38995567.0d0 (funcall (gethash "total" duration))) :to-be-truthy)))

(it-sequential "js-rt-temporal-normalization-numbers"
  (expect (= 3 (cl-cc/javascript::%temporal-normalize-number 3.9)) :to-be-truthy)
  (expect (= 7 (cl-cc/javascript::%temporal-normalize-number nil 7)) :to-be-truthy))

(it-sequential "js-rt-temporal-normalization-encode-decode"
  (multiple-value-bind (s mn h d m y dow)
      (cl-cc/javascript::%temporal-decode
       (cl-cc/javascript::%temporal-encode 2025 6 18 12 34 56))
    (expect (= 56 s) :to-be-truthy)
    (expect (= 34 mn) :to-be-truthy)
    (expect (= 12 h) :to-be-truthy)
    (expect (= 18 d) :to-be-truthy)
    (expect (= 6 m) :to-be-truthy)
    (expect (= 2025 y) :to-be-truthy)
    (expect (numberp dow) :to-be-truthy)))

(it-sequential "js-rt-temporal-normalization-duration"
  (let ((duration (cl-cc/javascript::%js-temporal-duration :hours -2.7 :minutes nil)))
    (expect (funcall (gethash "toString" duration)) :to-equal "P0Y0M0W0DT-2H0M0S")
    (expect (= -1.0d0 (gethash "sign" duration)) :to-be-truthy)
    (expect (= -7200.0d0 (funcall (gethash "total" duration))) :to-be-truthy)))

(it-sequential "js-rt-temporal-normalization-parse-instant-fallback"
  (let ((instant (cl-cc/javascript::%js-temporal-parse-instant "(")))
    (expect (gethash "__type__" instant) :to-equal "Temporal.Instant")))

(it-sequential "js-rt-temporal-normalization-parse-plain-date-fallback"
  (let ((plain-date (cl-cc/javascript::%js-temporal-parse-plain-date "(")))
    (expect (gethash "__type__" plain-date) :to-equal "Temporal.PlainDate")))

(it-sequential "js-rt-temporal-year-month-and-month-day"
  (let ((year-month (cl-cc/javascript::%js-temporal-plain-year-month 2025 6))
        (month-day (cl-cc/javascript::%js-temporal-plain-month-day 6 18)))
    (expect (funcall (gethash "toString" year-month)) :to-equal "2025-06")
    (expect (funcall (gethash "toString" month-day)) :to-equal "--06-18")))

(it-sequential "js-rt-temporal-global-factories"
  (let* ((temporal cl-cc/javascript::*js-temporal-global*)
         (instant-global (gethash "Instant" temporal))
         (plain-date-global (gethash "PlainDate" temporal))
         (plain-time-global (gethash "PlainTime" temporal))
         (plain-datetime-global (gethash "PlainDateTime" temporal))
         (zoned-global (gethash "ZonedDateTime" temporal))
         (duration-global (gethash "Duration" temporal))
         (plain-year-month-global (gethash "PlainYearMonth" temporal))
         (plain-month-day-global (gethash "PlainMonthDay" temporal))
         (instant-now (funcall (gethash "__call__" instant-global)))
         (instant-from-string (funcall (gethash "from" instant-global) "1970-01-01T00:00:01"))
         (instant-from-ms (funcall (gethash "fromEpochMilliseconds" instant-global) 2000))
         (instant-from-us (funcall (gethash "fromEpochMicroseconds" instant-global) 3000000))
         (instant-from-ns (funcall (gethash "fromEpochNanoseconds" instant-global) 4000000000))
         (plain-date-from-object (funcall (gethash "from" plain-date-global)
                                          (cl-cc/javascript::%js-make-object "year" 2025 "month" 6 "day" 18)))
         (plain-date-from-string (funcall (gethash "from" plain-date-global) "2025-06-19"))
         (plain-time-from-object (funcall (gethash "from" plain-time-global)
                                          (cl-cc/javascript::%js-make-object "hour" 7 "minute" 8 "second" 9)))
         (plain-time-from-string (funcall (gethash "from" plain-time-global) "10:11:12"))
         (plain-datetime-from-object (funcall (gethash "from" plain-datetime-global)
                                              (cl-cc/javascript::%js-make-object
                                               "year" 2025 "month" 6 "day" 18
                                               "hour" 12 "minute" 34 "second" 56)))
         (plain-datetime-from-string (funcall (gethash "from" plain-datetime-global) "2025-06-18T12:34:56"))
         (zoned-from-call (funcall (gethash "__call__" zoned-global) 0 "UTC"))
         (zoned-from-string (funcall (gethash "from" zoned-global) "2025-06-18T12:34:56"))
         (zoned-from-object (funcall (gethash "from" zoned-global)
                                     (cl-cc/javascript::%js-make-object "toString" "2025-06-18T12:34:56")))
         (duration-from-call (funcall (gethash "__call__" duration-global) 1 2 0 3 4 5 6))
         (duration-from-object (funcall (gethash "from" duration-global)
                                        (cl-cc/javascript::%js-make-object
                                         "years" 1.0d0 "months" 2.0d0 "days" 3.0d0
                                         "hours" 4.0d0 "minutes" 5.0d0 "seconds" 6.0d0)))
         (duration-from-fallback (funcall (gethash "from" duration-global) "ignored"))
         (plain-year-month-from-object (funcall (gethash "from" plain-year-month-global)
                                                (cl-cc/javascript::%js-make-object "year" 2025 "month" 6)))
         (plain-year-month-from-fallback (funcall (gethash "from" plain-year-month-global) "ignored"))
         (plain-month-day-from-object (funcall (gethash "from" plain-month-day-global)
                                               (cl-cc/javascript::%js-make-object "month" 6 "day" 18)))
         (plain-month-day-from-fallback (funcall (gethash "from" plain-month-day-global) "ignored")))
    (expect (gethash "__type__" instant-now) :to-equal "Temporal.Instant")
    (expect (= 1.0d0 (gethash "epochSeconds" instant-from-string)) :to-be-truthy)
    (expect (= 2.0d0 (gethash "epochSeconds" instant-from-ms)) :to-be-truthy)
    (expect (= 3.0d0 (gethash "epochSeconds" instant-from-us)) :to-be-truthy)
    (expect (= 4.0d0 (gethash "epochSeconds" instant-from-ns)) :to-be-truthy)
    (expect (= -1.0d0 (funcall (gethash "compare" instant-global) instant-from-string instant-from-ms)) :to-be-truthy)
    (expect (funcall (gethash "toString" plain-date-from-object)) :to-equal "2025-06-18")
    (expect (funcall (gethash "toString" plain-date-from-string)) :to-equal "2025-06-19")
    (expect (funcall (gethash "toString" plain-time-from-object)) :to-equal "07:08:09")
    (expect (funcall (gethash "toString" plain-time-from-string)) :to-equal "10:11:12")
    (expect (funcall (gethash "toString" plain-datetime-from-object)) :to-equal "2025-06-18T12:34:56")
    (expect (funcall (gethash "toString" plain-datetime-from-string)) :to-equal "2025-06-18T12:34:56")
    (expect (funcall (gethash "toString" zoned-from-call)) :to-equal "1970-01-01T00:00:00+00:00[UTC]")
    (expect (funcall (gethash "toString" zoned-from-string)) :to-equal "2025-06-18T12:34:56+00:00[UTC]")
    (expect (funcall (gethash "toString" zoned-from-object)) :to-equal "2025-06-18T12:34:56+00:00[UTC]")
    (expect (funcall (gethash "toString" duration-from-call)) :to-equal "P1Y2M0W3DT4H5M6S")
    (expect (funcall (gethash "toString" duration-from-object)) :to-equal "P1Y2M0W3DT4H5M6S")
    (expect (funcall (gethash "toString" duration-from-fallback)) :to-equal "P0Y0M0W0DT0H0M0S")
    (expect (= -1.0d0 (funcall (gethash "compare" duration-global) duration-from-fallback duration-from-object)) :to-be-truthy)
    (expect (funcall (gethash "toString" plain-year-month-from-object)) :to-equal "2025-06")
    (expect (funcall (gethash "toString" plain-year-month-from-fallback)) :to-equal "2000-01")
    (expect (funcall (gethash "toString" plain-month-day-from-object)) :to-equal "--06-18")
    (expect (funcall (gethash "toString" plain-month-day-from-fallback)) :to-equal "--01-01")))
