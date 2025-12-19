;; CLI: .canbc → run CAN-ISA VM → print state hash
;;
;; Usage:
;;   guile -s tools/can-run.scm program.canbc

(use-modules (rnrs io ports))

(define (read-file-bytes path)
  (call-with-input-file path
    (lambda (port)
      (let loop ((out '()))
        (let ((b (get-u8 port)))
          (if (eof-object? b)
              (reverse out)
              (loop (cons b out))))))))

(load (string-append (getcwd) "/src/canisa/vm.scm"))

(define (main argv)
  (if (< (length argv) 2)
      (begin
        (display "usage: guile -s tools/can-run.scm <program.canbc>\n")
        (exit 2))
      (let* ((path (list-ref argv 1))
             (bytes (read-file-bytes path))
             (res (vm-run-canbc-bytes bytes)))
        (display "ok?: ") (display (cdr (assq 'ok? res))) (newline)
        (display "events: ") (display (cdr (assq 'events res))) (newline)
        (display "state-hash: ") (display (cdr (assq 'state_hash res))) (newline)
        (let ((errs (cdr (assq 'errors res))))
          (if (and errs (not (null? errs)))
              (begin
                (display "errors:\n")
                (for-each (lambda (e) (display "  - ") (display e) (newline)) errs))))
        (exit (if (cdr (assq 'ok? res)) 0 1)))))

(main (command-line))
