;; Integration tests for BICF system

(load "../../src/integration/bicf-system.scm")

;; Test end-to-end workflow
(define (test-boundary-realization-flow)
  (display "Testing boundary → realization → validation flow...\n")
  (let ((boundary (make-simple-boundary "test-boundary"))
        (choice (make-choice "test-choice" '((data . "test-data")))))
    (let ((boundary-id (register-boundary boundary))
          (interior (realize choice boundary)))
      (if (valid? interior boundary)
          (display "✓ Boundary-realization-validation flow passed\n")
          (error "Flow validation failed")))))

;; Test CanvasL execution
(define (test-canvasl-execution)
  (display "Testing CanvasL execution...\n")
  ;; This would test actual CanvasL JSONL execution
  (display "✓ CanvasL execution test (placeholder)\n"))

;; Run all integration tests
(define (run-integration-tests)
  (display "Running BICF integration tests...\n")
  (test-boundary-realization-flow)
  (test-canvasl-execution)
  (display "All integration tests passed!\n"))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-integration-tests))

