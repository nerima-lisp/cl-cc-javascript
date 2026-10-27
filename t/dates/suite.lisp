(in-package #:cl-cc/javascript/dates/test)

(describe-concurrent "JavaScript Dates"
  (%register-dates-runtime-date-tests)
  (%register-dates-runtime-temporal-tests)
)
