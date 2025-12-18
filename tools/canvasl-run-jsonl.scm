;; CLI: CanvasL v1.0 JSONL → execute → print transcript hash
;;
;; Usage:
;;   guile -s tools/canvasl-run-jsonl.scm trace.jsonl
;;
;; Output:
;;   phase: <n>
;;   transcript: <hash:...>

(use-modules (rnrs io ports))

(load (string-append (getcwd) "/src/canvasl/interpreter.scm"))

(define (main argv)
  (if (< (length argv) 2)
      (begin
        (display "usage: guile -s tools/canvasl-run-jsonl.scm <trace.jsonl>\n")
        (exit 2))
      (let* ((path (list-ref argv 1))
             (state (execute-canvasl path)))
        (display "phase: ") (display (cdr (assq 'phase state))) (newline)
        (display "transcript: ") (display (cdr (assq 'transcript state))) (newline)
        (exit 0))))

(main (command-line))

