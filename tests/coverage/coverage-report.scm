;; Test Coverage Reporting
;; Tracks which functions/modules are tested

(define *coverage-data* '())

;; Record function call
(define (record-coverage module function)
  (let ((entry (assoc module *coverage-data*)))
    (if entry
        (let ((funcs (cdr entry)))
          (if (not (memq function funcs))
              (set-cdr! entry (cons function funcs))))
        (set! *coverage-data* (cons (cons module (list function)) *coverage-data*)))))

;; Get coverage for module
(define (get-module-coverage module)
  (let ((entry (assoc module *coverage-data*)))
    (if entry
        (cdr entry)
        '())))

;; Generate coverage report
(define (generate-coverage-report)
  (display "Test Coverage Report\n")
  (display "====================\n")
  (let loop ((modules *coverage-data*))
    (if (not (null? modules))
        (let ((module (car modules)))
          (display "Module: ")
          (display (car module))
          (display "\n  Functions tested: ")
          (display (length (cdr module)))
          (display "\n")
          (loop (cdr modules))))))

;; Calculate coverage percentage (simplified)
(define (calculate-coverage module total-functions)
  (let ((tested (length (get-module-coverage module))))
    (if (> total-functions 0)
        (* 100 (/ tested total-functions))
        0)))

;; ============================================================
;; End of Coverage Reporting
;; ============================================================

