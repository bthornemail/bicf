;; CLI: CanvasL (alist records) → CLBC
;;
;; Usage:
;;   guile -s tools/canvasl-to-clbc.scm input.scm output.clbc

(use-modules (rnrs io ports))

(define (dirname path)
  (let loop ((i (- (string-length path) 1)))
    (if (< i 0) "."
        (if (char=? (string-ref path i) #\/)
            (if (= i 0) "/" (substring path 0 i))
            (loop (- i 1))))))

;; Expect to be executed from repo root (scripts do this); use absolute path anyway.
(load (string-append (getcwd) "/src/clbc/compiler.scm"))

(define (write-bytes-to-file bytes path)
  (call-with-output-file path
    (lambda (port)
      (for-each (lambda (b) (put-u8 port b)) bytes))))

(define (main argv)
  (if (< (length argv) 3)
      (begin
        (display "usage: guile -s tools/canvasl-to-clbc.scm <input.scm> <output.clbc>\n")
        (exit 2))
      (let* ((in (list-ref argv 1))
             (out (list-ref argv 2))
             (records (call-with-input-file in read-records-from-port))
             (enc (canvasl-records->clbc records))
             (bytes (cdr enc)))
        (write-bytes-to-file bytes out)
        (display "Wrote CLBC: ")
        (display out)
        (display " (")
        (display (number->string (length bytes)))
        (display " bytes)\n")
        (exit 0))))

(main (command-line))


