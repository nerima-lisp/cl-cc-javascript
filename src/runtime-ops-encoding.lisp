;;;; packages/javascript/src/runtime-ops-encoding.lisp — URI / base64 / text codecs
;;;;
;;;; Separated from runtime-ops.lisp so the core operator helpers remain focused
;;;; on arithmetic, bitwise, bigint, and control-flow-adjacent primitives.

(in-package :cl-cc/javascript)

;;; ─── URI encoding/decoding ───────────────────────────────────────────────────
;;;
;;; Both encode functions share the same percent-encoding loop — they differ
;;; only in the set of "safe" characters that are passed through unchanged.
;;; +uri-component-safe-chars+ omits the URI-structure chars that encodeURI
;;; must preserve.

(defun %js-char-set (chars)
  "Build an O(1)-membership hash-table from CHARS, for a fixed small set
tested repeatedly inside a per-character loop (percent-encoding below) —
MEMBER on the raw list would re-walk it once per input character."
  (let ((table (make-hash-table)))
    (dolist (ch chars table)
      (setf (gethash ch table) t))))

(defparameter +uri-unreserved-chars+
  '(#\- #\_ #\. #\! #\~ #\* #\' #\( #\))
  "RFC 3986 unreserved characters, shared by both safe-char sets below.")

(defparameter +uri-component-safe-chars+
  (%js-char-set +uri-unreserved-chars+)
  "Characters that encodeURIComponent leaves unencoded (RFC 3986 unreserved).")

(defparameter +uri-safe-chars+
  (%js-char-set (append +uri-unreserved-chars+
                        '(#\; #\/ #\? #\: #\@ #\& #\= #\+ #\$ #\, #\#)))
  "Characters that encodeURI leaves unencoded (unreserved + URI structure chars).")

(defun %js-percent-encode (str safe-chars)
  "Percent-encode STR, leaving alphanumerics and SAFE-CHARS (a %js-char-set
hash-table) unchanged."
  (with-output-to-string (out)
    (loop for ch across (%js-to-string str)
          do (if (or (alphanumericp ch) (gethash ch safe-chars))
                 (write-char ch out)
                 (loop for byte across (sb-ext:string-to-octets (string ch) :external-format :utf-8)
                       do (format out "%~2,'0X" byte))))))

(defun %js-encode-uri-component (str)
  "JS encodeURIComponent: percent-encode all chars except unreserved."
  (%js-percent-encode str +uri-component-safe-chars+))

(defun %js-decode-uri-component (str)
  "JS decodeURIComponent: decode percent-encoded string."
  (let ((s     (%js-to-string str))
        (bytes (make-array 0 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0)))
    (loop with i = 0 and n = (length s)
          while (< i n)
          do (let ((ch (char s i)))
               (if (and (char= ch #\%) (< (+ i 2) n))
                   (progn (vector-push-extend
                           (parse-integer s :start (1+ i) :end (+ i 3) :radix 16) bytes)
                          (incf i 3))
                   (progn (loop for b across (sb-ext:string-to-octets
                                              (string ch) :external-format :utf-8)
                                do (vector-push-extend b bytes))
                          (incf i)))))
    (sb-ext:octets-to-string bytes :external-format :utf-8)))

(defun %js-encode-uri (str)
  "JS encodeURI: encode URI, preserving scheme/path/query chars."
  (%js-percent-encode str +uri-safe-chars+))

(defun %js-decode-uri (str)
  "JS decodeURI: decode URI but leave reserved chars encoded."
  (%js-decode-uri-component str))

;;; ─── atob / btoa (base64 in browsers) ───────────────────────────────────────

;;; The RFC 4648 arithmetic lives in %js-base64-encode-bytes /
;;; %js-base64-decode-bytes (runtime-typed-arrays-encoding.lisp), shared with
;;; Uint8Array.toBase64/fromBase64.  atob/btoa differ from those only in
;;; treating each octet as a character code rather than a typed-array element.

(defun %js-btoa (str)
  "JS btoa: base64-encode a binary string."
  (let ((s (%js-to-string str)))
    (%js-base64-encode-bytes (map 'vector #'char-code s) (length s))))

(defun %js-atob (str)
  "JS atob: decode base64 string."
  (with-output-to-string (out)
    (%js-base64-decode-bytes (%js-to-string str)
                             (lambda (byte) (write-char (code-char byte) out)))))

;;; ─── TextEncoder / TextDecoder ───────────────────────────────────────────────

(defun %js-utf8-octets (value)
  (sb-ext:string-to-octets (%js-to-string value) :external-format :utf-8))

(defun %js-text-decoder-encoding (encoding)
  (let ((name (string-downcase
               (%js-to-string
                (if (or (null encoding)
                        (eq encoding +js-undefined+)
                        (eq encoding +js-null+))
                    "utf-8"
                    encoding)))))
    (cond
      ((or (string= name "utf8") (string= name "unicode-1-1-utf-8"))
       "utf-8")
      (t name))))

(defun %js-text-decode-octets (bytes)
  "Decode BYTES as UTF-8 the way JS's non-fatal TextDecoder does (this
runtime's TextDecoder always reports \"fatal\" false — see
%js-make-text-decoder): an invalid byte sequence becomes a single U+FFFD
REPLACEMENT CHARACTER, and decoding continues, rather than discarding
everything already decoded. SBCL's own :replacement external-format option
does exactly this natively; no need to hand-roll a resync loop."
  (sb-ext:octets-to-string bytes :external-format (list :utf-8 :replacement (code-char #xFFFD))))

(defun %js-text-buffer-octets (buf)
  (cond
    ((js-typed-array-p buf)
     (let* ((len (js-ta-length buf))
            (bytes (make-array len :element-type '(unsigned-byte 8))))
       (dotimes (i len bytes)
         (setf (aref bytes i) (logand #xFF (truncate (%js-ta-get buf i)))))))
    ((vectorp buf)
     (let* ((len (length buf))
            (bytes (make-array len :element-type '(unsigned-byte 8))))
       (dotimes (i len bytes)
         (setf (aref bytes i) (logand #xFF (truncate (aref buf i)))))))
    (t nil)))

(defun %js-text-encode-into (str dest)
  (let* ((s (%js-to-string str))
         (dest-len (if (js-typed-array-p dest) (js-ta-length dest) 0))
         (read 0)
         (written 0))
    (when (js-typed-array-p dest)
      (loop for ch across s
            for ch-str = (string ch)
            for bytes = (sb-ext:string-to-octets ch-str :external-format :utf-8)
            for byte-count = (length bytes)
            while (<= (+ written byte-count) dest-len)
            do (progn
                 (dotimes (i byte-count)
                   (%js-ta-set dest (+ written i) (aref bytes i)))
                 (incf written byte-count)
                 (incf read (if (> (char-code ch) #xFFFF) 2 1)))))
    (%js-make-object "read" (coerce read 'double-float)
                     "written" (coerce written 'double-float))))

(defun %js-make-text-encoder ()
  "JS TextEncoder (UTF-8 encoding)."
  (%js-make-object
   "encoding" "utf-8"
   "encode"   (lambda (str)
                (let* ((bytes (%js-utf8-octets str))
                       (vec (%js-make-typed-array "Uint8Array" (length bytes))))
                  (loop for i below (length bytes)
                        do (%js-ta-set vec i (aref bytes i)))
                  vec))
   "encodeInto" #'%js-text-encode-into))

(defun %js-make-text-decoder (&optional (encoding "utf-8"))
  "JS TextDecoder for UTF-8 byte inputs."
  (let ((normalized (%js-text-decoder-encoding encoding)))
    (%js-make-object
     "encoding" normalized
     "fatal" nil
     "ignoreBOM" nil
     "decode"   (lambda (&optional buf _options)
                  (declare (ignore _options))
                  (cond
                    ((or (null buf) (eq buf +js-undefined+)) "")
                    (t
                     (let ((bytes (%js-text-buffer-octets buf)))
                       (if bytes
                           (%js-text-decode-octets bytes)
                           (%js-to-string buf)))))))))
