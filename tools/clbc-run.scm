;; CLI: CLBC → run in VM → transcript hash
;;
;; Usage:
;;   guile -s tools/clbc-run.scm program.clbc

(use-modules (rnrs io ports))

(load (string-append (getcwd) "/src/vm/clbc-vm.scm"))

(define (main argv)
  (if (< (length argv) 2)
      (begin
        (display "usage: guile -s tools/clbc-run.scm <program.clbc>\n")
        (exit 2))
      (let* ((path (list-ref argv 1))
             (bytes (read-file-bytes path))
             (res (vm-run-clbc-bytes bytes)))
        (display "ok?: ") (display (cdr (assq 'ok? res))) (newline)
        (display "events: ") (display (cdr (assq 'events res))) (newline)
        (display "transcript-hash: ") (display (cdr (assq 'transcript-hash res))) (newline)
        (let ((errs (cdr (assq 'errors res))))
          (if (and errs (not (null? errs)))
              (begin
                (display "errors:\n")
                (for-each (lambda (e) (display "  - ") (display e) (newline)) errs))))
        (exit (if (cdr (assq 'ok? res)) 0 1)))))

(main (command-line))


