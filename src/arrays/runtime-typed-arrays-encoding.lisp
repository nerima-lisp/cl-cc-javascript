;;;; packages/javascript/src/runtime-typed-arrays-encoding.lisp — ES2025 TypedArray encoding
;;;;
;;;; Uint8Array hex/base64 encoding helpers:
;;;;   toHex, toBase64, fromHex, fromBase64, setFromHex, setFromBase64
;;;;
;;;; Load order: after runtime-typed-arrays.lisp, before runtime-typed-arrays-methods.lisp.

(in-package :cl-cc/javascript)

(defparameter +%js-base64-alphabet+
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  "Base64 encoding alphabet (RFC 4648 standard encoding).")

;;; JS exposes base64 twice — as atob/btoa over a binary string
;;; (runtime-ops-encoding.lisp) and as Uint8Array.toBase64/fromBase64 over a
;;; typed array.  The RFC 4648 bit shuffling and `=' padding rules are the same
;;; in both; only where the bytes come from and where the result goes differ.
;;; Both pairs used to carry their own copy of the arithmetic, so a padding fix
;;; had to be made twice.  These two helpers hold the algorithm; the four
;;; entry points supply only the source and the sink.

(defun %js-base64-encode-bytes (bytes n)
  "Base64-encode the first N elements of BYTES (any vector of octets).
Returns the encoded string, `='-padded to a multiple of four characters."
  (let ((alphabet +%js-base64-alphabet+))
    (with-output-to-string (out)
      (loop for i from 0 below n by 3
            do (let* ((b0 (aref bytes i))
                      (b1 (if (< (1+ i) n) (aref bytes (1+ i)) 0))
                      (b2 (if (< (+ i 2) n) (aref bytes (+ i 2)) 0)))
                 (write-char (char alphabet (ash b0 -2)) out)
                 (write-char (char alphabet (logior (ash (logand b0 3) 4) (ash b1 -4))) out)
                 (write-char (if (< (1+ i) n)
                                 (char alphabet (logior (ash (logand b1 15) 2) (ash b2 -6)))
                                 #\=)
                             out)
                 (write-char (if (< (+ i 2) n) (char alphabet (logand b2 63)) #\=) out))))))

(defun %js-base64-decode-bytes (b64-string emit)
  "Decode BASE64-STRING, calling EMIT on each decoded octet in order.

Surrounding ASCII whitespace is trimmed first.  A trailing group of fewer than
four characters is ignored, and `=' padding suppresses the octets it stands
for, so a well-formed input yields exactly its original bytes.  EMIT is the
only thing that varies between callers: atob writes characters, fromBase64
pushes onto a byte vector."
  (let* ((s (string-trim '(#\Space #\Tab #\Newline #\Return) b64-string))
         (alphabet +%js-base64-alphabet+))
    (flet ((dc (ch) (or (position ch alphabet) 0)))
      (loop for i from 0 below (length s) by 4
            while (< (+ i 3) (length s))
            do (let* ((pad2 (char= (char s (+ i 2)) #\=))
                      (pad3 (char= (char s (+ i 3)) #\=))
                      (g0 (dc (char s i)))
                      (g1 (dc (char s (1+ i))))
                      (g2 (if pad2 0 (dc (char s (+ i 2)))))
                      (g3 (if pad3 0 (dc (char s (+ i 3))))))
                 (funcall emit (logior (ash g0 2) (ash g1 -4)))
                 (unless pad2
                   (funcall emit (logior (ash (logand g1 15) 4) (ash g2 -2))))
                 (unless pad3
                   (funcall emit (logior (ash (logand g2 3) 6) g3))))))))

(defun %js-uint8-to-hex (ta)
  "Uint8Array.prototype.toHex() — ES2025. Returns lowercase hex pairs."
  (string-downcase
   (with-output-to-string (out)
     (dotimes (i (js-ta-length ta))
       (format out "~2,'0x" (aref (js-ta-buffer ta) i))))))

(defun %js-uint8-from-hex (hex-str)
  "Uint8Array.fromHex(string) — ES2025."
  (let* ((s (%js-to-string hex-str))
         (n (floor (length s) 2))
         (ta (%js-make-typed-array "Uint8Array" n)))
    (dotimes (i n ta)
      (setf (aref (js-ta-buffer ta) i)
            (parse-integer s :start (* 2 i) :end (* 2 (1+ i)) :radix 16)))))

(defun %js-uint8-to-base64 (ta &optional opts)
  "Uint8Array.prototype.toBase64() — ES2025."
  (declare (ignore opts))
  (%js-base64-encode-bytes (js-ta-buffer ta) (js-ta-length ta)))

(defun %js-uint8-from-base64 (b64-str &optional opts)
  "Uint8Array.fromBase64(string) — ES2025."
  (declare (ignore opts))
  (let ((bytes (make-array 0 :element-type '(unsigned-byte 8)
                             :adjustable t :fill-pointer 0)))
    (%js-base64-decode-bytes (%js-to-string b64-str)
                             (lambda (byte) (vector-push-extend byte bytes)))
    (let ((ta (%js-make-typed-array "Uint8Array" (length bytes))))
      (loop for b across bytes for i from 0 do (setf (aref (js-ta-buffer ta) i) b))
      ta)))

(defun %js-uint8-copy-decoded-into (target decoded)
  (let ((written (min (js-ta-length target) (js-ta-length decoded))))
    (dotimes (i written)
      (%js-ta-set target i (aref (js-ta-buffer decoded) i)))
    written))

(defun %js-uint8-set-from-hex (ta hex-str)
  "Uint8Array.prototype.setFromHex(string) — ES2025."
  (let* ((s (%js-to-string hex-str))
         (decoded (%js-uint8-from-hex s))
         (written (%js-uint8-copy-decoded-into ta decoded)))
    (%js-make-object "read" (coerce (* written 2) 'double-float)
                     "written" (coerce written 'double-float))))

(defun %js-uint8-set-from-base64 (ta b64-str &optional opts)
  "Uint8Array.prototype.setFromBase64(string) — ES2025."
  (let* ((s (string-trim '(#\Space #\Tab #\Newline #\Return)
                         (%js-to-string b64-str)))
         (decoded (%js-uint8-from-base64 s opts))
         (written (%js-uint8-copy-decoded-into ta decoded)))
    (%js-make-object "read" (coerce (length s) 'double-float)
                     "written" (coerce written 'double-float))))
