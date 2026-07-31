;;;; t/runtime-date-test.lisp
;;;;
;;;; Split from runtime-date-json-test.lisp: Date.prototype construction,
;;;; getters/setters, string formatting, and the *js-date-method-table*
;;;; dispatch table.
;;;;
;;;; Depends on: runtime-core-test.lisp (%jr-arr)

(in-package :cl-cc-javascript/test)

;;; ─── Date.prototype ──────────────────────────────────────────────────────────

(it-sequential "js-rt-date-now"
  (let ((t1 (cl-cc/javascript::%js-date-now))
        (t2 (cl-cc/javascript::%js-date-now)))
    (expect (integerp t1) :to-be-truthy)
    (expect (>= t2 t1) :to-be-truthy)))

(it-sequential "js-rt-date-make-date-no-args"
  (let ((d (cl-cc/javascript::%js-make-date)))
    (expect (cl-cc/javascript::js-date-p d) :to-be-truthy)
    (expect (integerp (cl-cc/javascript::js-date-ms d)) :to-be-truthy)))

(it-sequential "js-rt-date-make-date-from-ms"
  (let ((d (cl-cc/javascript::%js-make-date 1000000.0d0)))
    (expect (= 1000000 (cl-cc/javascript::js-date-ms d)) :to-be-truthy)))

(it-sequential "js-rt-date-make-date-copy"
  (let* ((orig (cl-cc/javascript::%js-make-date 42000.0d0))
         (copy (cl-cc/javascript::%js-make-date orig)))
    (expect (= 42000 (cl-cc/javascript::js-date-ms copy)) :to-be-truthy)))

(it-sequential "js-rt-date-make-date-string"
  (let ((d (cl-cc/javascript::%js-make-date "1970-01-01T01:00:00")))
    (expect (cl-cc/javascript::js-date-p d) :to-be-truthy)
    (expect (= 3600000 (cl-cc/javascript::js-date-ms d)) :to-be-truthy)))

(it-sequential "js-rt-date-make-date-null"
  (let ((d (cl-cc/javascript::%js-make-date cl-cc/javascript::+js-null+)))
    (expect (cl-cc/javascript::js-date-p d) :to-be-truthy)
    (expect (integerp (cl-cc/javascript::js-date-ms d)) :to-be-truthy)))

(it-sequential "js-rt-date-parse-string-date-only"
  (let ((ms (cl-cc/javascript::%js-date-parse-string "1970-01-01")))
    (expect (zerop ms) :to-be-truthy)))

(it-sequential "js-rt-date-parse-string-datetime"
  (let ((ms (cl-cc/javascript::%js-date-parse-string "1970-01-01T01:00:00")))
    (expect (= 3600000 ms) :to-be-truthy)))

(it-sequential "js-rt-date-parse-string-trims-spaces"
  (let ((ms (cl-cc/javascript::%js-date-parse-string " 1970-01-01T01:02:03 ")))
    (expect (= 3723000 ms) :to-be-truthy)))

(it-sequential "js-rt-date-parse-string-error"
  ;; An unparseable string is an Invalid Date (NaN), per ECMA-262 -- NOT an
  ;; integer "now" fallback, which this test used to assert (a real bug,
  ;; fixed 2026-07-31: new Date("garbage") used to silently become the
  ;; current time instead of a detectably-invalid Date; see CHANGELOG.md).
  (let ((result (cl-cc/javascript::%js-date-parse-string "not-a-date")))
    (expect (cl-cc/javascript::%js-float-nan-p result) :to-be-truthy)))

(it-sequential "js-rt-date-make-date-fallback"
  (let ((d (cl-cc/javascript::%js-make-date (make-hash-table :test #'equal))))
    (expect (cl-cc/javascript::js-date-p d) :to-be-truthy)
    (expect (integerp (cl-cc/javascript::js-date-ms d)) :to-be-truthy)))

(it-sequential "js-rt-date-setters-with-undefined-optionals"
  (let ((d (cl-cc/javascript::%js-make-date 0)))
    (cl-cc/javascript::%js-date-set-full-year d 1970 cl-cc/javascript::+js-undefined+ cl-cc/javascript::+js-undefined+)
    (cl-cc/javascript::%js-date-set-month d 0 cl-cc/javascript::+js-undefined+)
    (cl-cc/javascript::%js-date-set-hours d 0 cl-cc/javascript::+js-undefined+ cl-cc/javascript::+js-undefined+ cl-cc/javascript::+js-undefined+)
    (cl-cc/javascript::%js-date-set-minutes d 0 cl-cc/javascript::+js-undefined+ cl-cc/javascript::+js-undefined+)
    (cl-cc/javascript::%js-date-set-seconds d 0 cl-cc/javascript::+js-undefined+)
    (expect (zerop (cl-cc/javascript::js-date-ms d)) :to-be-truthy)))

;;; 97445000 ms = 1970-01-02T03:04:05.000Z
(it-sequential "js-rt-date-getters"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))
    (expect (= 1970 (cl-cc/javascript::%js-date-get-full-year d)) :to-be-truthy)
    (expect (= 1970 (cl-cc/javascript::%js-date-get-utc-full-year d)) :to-be-truthy)
    (expect (zerop (cl-cc/javascript::%js-date-get-month d)) :to-be-truthy)      ; January = 0
    (expect (= 2 (cl-cc/javascript::%js-date-get-date d)) :to-be-truthy)
    (expect (= 3 (cl-cc/javascript::%js-date-get-hours d)) :to-be-truthy)
    (expect (= 4 (cl-cc/javascript::%js-date-get-minutes d)) :to-be-truthy)
    (expect (= 5 (cl-cc/javascript::%js-date-get-seconds d)) :to-be-truthy)
    (expect (zerop (cl-cc/javascript::%js-date-get-milliseconds d)) :to-be-truthy)))

(it-sequential "js-rt-date-get-time"
  (let ((d (cl-cc/javascript::%js-make-date 12345)))
    (expect (= 12345.0d0 (cl-cc/javascript::%js-date-get-time d)) :to-be-truthy)))

(it-sequential "js-rt-date-to-iso-string"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))
    (expect (cl-cc/javascript::%js-date-to-iso-string d) :to-equal "1970-01-02T03:04:05.000Z")))

(it-sequential "js-rt-date-to-iso-string-with-ms"
  (let ((d (cl-cc/javascript::%js-make-date 97445123)))
    (expect (cl-cc/javascript::%js-date-to-iso-string d) :to-equal "1970-01-02T03:04:05.123Z")))

(it-sequential "js-rt-date-to-local-date-string"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))
    (expect (cl-cc/javascript::%js-date-to-local-date-string d) :to-equal "1970/01/02")))

(it-sequential "js-rt-date-to-time-string"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))
    (expect (cl-cc/javascript::%js-date-to-time-string d) :to-equal "03:04:05 GMT+0000 (Coordinated Universal Time)")))

(it-sequential "js-rt-date-set-time"
  (let ((d (cl-cc/javascript::%js-make-date 0)))
    (cl-cc/javascript::%js-date-set-time d 5000)
    (expect (= 5000 (cl-cc/javascript::js-date-ms d)) :to-be-truthy)))

(it-sequential "js-rt-date-set-full-year-preserves-time"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))  ; 1970-01-02T03:04:05Z
    (cl-cc/javascript::%js-date-set-full-year d 2024.0d0)
    (expect (= 3 (cl-cc/javascript::%js-date-get-hours d)) :to-be-truthy)
    (expect (= 4 (cl-cc/javascript::%js-date-get-minutes d)) :to-be-truthy)
    (expect (= 5 (cl-cc/javascript::%js-date-get-seconds d)) :to-be-truthy)))

(it-sequential "js-rt-date-set-month"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))  ; January
    (cl-cc/javascript::%js-date-set-month d 5.0d0)       ; June (0-based)
    (expect (= 5 (cl-cc/javascript::%js-date-get-month d)) :to-be-truthy)))

(it-sequential "js-rt-date-set-date"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))  ; day 2
    (cl-cc/javascript::%js-date-set-date d 15.0d0)
    (expect (= 15 (cl-cc/javascript::%js-date-get-date d)) :to-be-truthy)))

(it-sequential "js-rt-date-rebuild-preserves-ms"
  (let ((d (cl-cc/javascript::%js-make-date 97445999)))  ; .999 ms
    (cl-cc/javascript::%js-date-rebuild d :sec 10)
    (expect (= 999 (cl-cc/javascript::%js-date-get-milliseconds d)) :to-be-truthy)))

(it-sequential "js-rt-date-timezone-offset-utc"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))
    (expect (= 0.0d0 (cl-cc/javascript::%js-date-get-timezone-offset d)) :to-be-truthy)))

(it-sequential "js-rt-date-timezone-offset-matches-host-zone-projection"
  ;; Host-zone-independent: recomputes the expected offset from whatever
  ;; %temporal-host-time-zone-id actually resolves to (see runtime-temporal.lisp)
  ;; instead of assuming UTC, so this passes both inside the Nix sandbox (which
  ;; falls back to "UTC") and on a host with a real TZ configured.
  (let* ((d (cl-cc/javascript::%js-make-date 0.0d0))
         (tz (cl-cc/javascript::%temporal-host-time-zone-id))
         (offset (cl-cc/javascript::%js-date-get-timezone-offset d)))
    (expect (typep offset 'double-float) :to-be-truthy)
    (if (string= tz "UTC")
        (expect (= 0.0d0 offset) :to-be-truthy)
        (let ((projected (cl-cc/javascript::%temporal-zone-project-epoch 0 tz)))
          (expect (= offset (coerce (- (cl-cc/javascript::%temporal-offset-string-to-minutes
                                         (seventh projected)))
                                     'double-float))
                  :to-be-truthy)))))

(it-sequential "js-rt-date-to-utc-string"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))
    (expect (cl-cc/javascript::%js-date-to-utc-string d) :to-equal "1970-01-02T03:04:05.000Z")))

(it-sequential "js-rt-date-to-date-string"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))
    (expect (cl-cc/javascript::%js-date-to-date-string d) :to-equal "Fri Jan 02 1970")))

(it-sequential "js-rt-date-to-json"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))
    (expect (cl-cc/javascript::%js-date-to-json d) :to-equal "1970-01-02T03:04:05.000Z")))

(it-sequential "js-rt-date-value-of"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))
    (expect (= (cl-cc/javascript::%js-date-get-time d) (cl-cc/javascript::%js-date-value-of d)) :to-be-truthy)))

(it-sequential "js-rt-date-set-hours-preserves-ms"
  (let ((d (cl-cc/javascript::%js-make-date 97445999)))
    (cl-cc/javascript::%js-date-set-hours d 6 7 8 1)
    (expect (cl-cc/javascript::%js-date-to-iso-string d) :to-equal "1970-01-02T06:07:08.999Z")))

(it-sequential "js-rt-date-set-minutes-preserves-ms"
  (let ((d (cl-cc/javascript::%js-make-date 97445999)))
    (cl-cc/javascript::%js-date-set-minutes d 9 10 1)
    (expect (cl-cc/javascript::%js-date-to-iso-string d) :to-equal "1970-01-02T03:09:10.999Z")))

(it-sequential "js-rt-date-set-seconds-preserves-ms"
  (let ((d (cl-cc/javascript::%js-make-date 97445999)))
    (cl-cc/javascript::%js-date-set-seconds d 11 1)
    (expect (cl-cc/javascript::%js-date-to-iso-string d) :to-equal "1970-01-02T03:04:11.999Z")))

(it-sequential "js-rt-date-to-string"
  (let ((d (cl-cc/javascript::%js-make-date 97445000)))
    (expect (cl-cc/javascript::%js-date-to-string d) :to-equal "1970-01-02T03:04:05.000Z")))

;;; 97445123 ms = 1970-01-02T03:04:05.123Z, a Friday (CL dow 0=Mon..6=Sun → 4)
(it-sequential "js-rt-date-method-table-getters-dispatch"
  (let ((d (cl-cc/javascript::%js-make-date 97445123)))
    (flet ((call (name)
             (funcall (cdr (assoc name cl-cc/javascript::*js-date-method-table* :test #'string=)) d)))
      (expect (= 97445123.0d0 (call "getTime")) :to-be-truthy)
      (expect (= 1970 (call "getFullYear")) :to-be-truthy)
      (expect (= 1970 (call "getUTCFullYear")) :to-be-truthy)
      (expect (zerop (call "getMonth")) :to-be-truthy)
      (expect (zerop (call "getUTCMonth")) :to-be-truthy)
      (expect (= 2 (call "getDate")) :to-be-truthy)
      (expect (= 2 (call "getUTCDate")) :to-be-truthy)
      (expect (= 4 (call "getDay")) :to-be-truthy)
      (expect (= 4 (call "getUTCDay")) :to-be-truthy)
      (expect (= 3 (call "getHours")) :to-be-truthy)
      (expect (= 3 (call "getUTCHours")) :to-be-truthy)
      (expect (= 4 (call "getMinutes")) :to-be-truthy)
      (expect (= 4 (call "getUTCMinutes")) :to-be-truthy)
      (expect (= 5 (call "getSeconds")) :to-be-truthy)
      (expect (= 5 (call "getUTCSeconds")) :to-be-truthy)
      (expect (= 123 (call "getMilliseconds")) :to-be-truthy)
      (expect (= 0.0d0 (call "getTimezoneOffset")) :to-be-truthy)
      (expect (string= "1970-01-02T03:04:05.123Z" (call "toISOString")) :to-be-truthy)
      (expect (string= "1970/01/02" (call "toLocaleDateString")) :to-be-truthy)
      (expect (string= "03:04:05 GMT+0000 (Coordinated Universal Time)" (call "toLocaleTimeString")) :to-be-truthy)
      (expect (string= "1970-01-02T03:04:05.123Z" (call "toLocaleString")) :to-be-truthy)
      (expect (string= "1970-01-02T03:04:05.123Z" (call "toUTCString")) :to-be-truthy)
      (expect (string= "Fri Jan 02 1970" (call "toDateString")) :to-be-truthy)
      (expect (string= "03:04:05 GMT+0000 (Coordinated Universal Time)" (call "toTimeString")) :to-be-truthy)
      (expect (string= "1970-01-02T03:04:05.123Z" (call "toJSON")) :to-be-truthy)
      (expect (string= "1970-01-02T03:04:05.123Z" (call "toString")) :to-be-truthy)
      (expect (= 97445123.0d0 (call "valueOf")) :to-be-truthy))))

(it-sequential "js-rt-date-method-table-setters-dispatch"
  (let ((d (cl-cc/javascript::%js-make-date 97445999)))
    (flet ((call (name &rest args)
             (apply #'funcall (cdr (assoc name cl-cc/javascript::*js-date-method-table* :test #'string=))
                    d args)))
      (call "setTime" 5000)
      (expect (= 5000 (cl-cc/javascript::js-date-ms d)) :to-be-truthy)
      (call "setFullYear" 2024.0d0)
      (expect (= 2024 (cl-cc/javascript::%js-date-get-full-year d)) :to-be-truthy)
      (call "setMonth" 5.0d0)
      (expect (= 5 (cl-cc/javascript::%js-date-get-month d)) :to-be-truthy)
      (call "setDate" 15.0d0)
      (expect (= 15 (cl-cc/javascript::%js-date-get-date d)) :to-be-truthy)
      (call "setHours" 6.0d0 7.0d0 8.0d0)
      (expect (= 6 (cl-cc/javascript::%js-date-get-hours d)) :to-be-truthy)
      (expect (= 7 (cl-cc/javascript::%js-date-get-minutes d)) :to-be-truthy)
      (expect (= 8 (cl-cc/javascript::%js-date-get-seconds d)) :to-be-truthy)
      (call "setMinutes" 9.0d0 10.0d0)
      (expect (= 9 (cl-cc/javascript::%js-date-get-minutes d)) :to-be-truthy)
      (expect (= 10 (cl-cc/javascript::%js-date-get-seconds d)) :to-be-truthy)
      (call "setSeconds" 11.0d0)
      (expect (= 11 (cl-cc/javascript::%js-date-get-seconds d)) :to-be-truthy))))
