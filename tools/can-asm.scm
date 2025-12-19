;; CLI: CAN-ISA assembly (Scheme s-expr) → .canbc container
;;
;; Usage:
;;   guile -s tools/can-asm.scm input.scm output.canbc

(use-modules (rnrs io ports))

(load (string-append (getcwd) "/src/canisa/assembler.scm"))

(define (write-bytes-to-file bytes path)
  (call-with-output-file path
    (lambda (port)
      (for-each (lambda (b) (put-u8 port b)) bytes))))

(define (main argv)
  (if (< (length argv) 3)
      (begin
        (display "usage: guile -s tools/can-asm.scm <input.scm> <output.canbc>\n")
        (exit 2))
      (let* ((in (list-ref argv 1))
             (out (list-ref argv 2))
             (program (call-with-input-file in read))
             (payload (assemble-program program))
             (bytes (canbc-wrap payload)))
        (write-bytes-to-file bytes out)
        (display "Wrote CANBC: ") (display out)
        (display " (payload ") (display (number->string (length payload))) (display " bytes)\n")
        (exit 0))))

(main (command-line))

