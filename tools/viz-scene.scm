;; CLI: produce RFC-VIZ-001 scene JSON-ish S-expression
;;
;; Usage:
;;   guile -s tools/viz-scene.scm <k> <globalDecision:0|1> <includeFano:0|1>

(load (string-append (getcwd) "/src/viz/scene.scm"))

(define (main argv)
  (if (< (length argv) 4)
      (begin
        (display "usage: guile -s tools/viz-scene.scm <k> <globalDecision:0|1> <includeFano:0|1>\n")
        (exit 2))
      (let* ((k (string->number (list-ref argv 1)))
             (gd (= 1 (string->number (list-ref argv 2))))
             (fano (= 1 (string->number (list-ref argv 3))))
             (scene (viz-make-scene (if k k 0) gd fano '(0 1 2 3 4 5 6)
                                    '((0 1 3) (0 2 6) (0 4 5) (1 2 4) (1 5 6) (2 3 5) (3 4 6)))))
        (write scene)
        (newline)
        (exit 0))))

(main (command-line))


