;; Unit tests for BICF Core

(load "../../src/core/bicf-core.scm")

;; Test Axiom 1: Boundary-Interior Duality
(define (test-axiom1)
  (let ((boundary (make-simple-boundary "test-boundary"))
        (choice (make-choice "test-choice" '((data . "test"))))
        (interior (realize choice boundary)))
    (if (axiom1-boundary-interior-duality interior boundary)
        (display "✓ Axiom 1 passed\n")
        (error "Axiom 1 failed"))))

;; Test Axiom 2: Non-Canonicity
(define (test-axiom2)
  (let ((boundary (make-simple-boundary "test-boundary"))
        (choice1 (make-choice "choice1" '((data . "data1"))))
        (choice2 (make-choice "choice2" '((data . "data2")))))
    (if (axiom2-non-canonicity boundary choice1 choice2)
        (display "✓ Axiom 2 passed\n")
        (error "Axiom 2 failed"))))

;; Run all tests
(define (run-core-tests)
  (display "Running BICF Core unit tests...\n")
  (test-axiom1)
  (test-axiom2)
  (display "All core tests passed!\n"))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-core-tests))

