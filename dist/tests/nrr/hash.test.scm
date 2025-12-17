;; Unit tests for NRR Content Addressing

(load "../../src/nrr/hash.scm")

;; Test helper
(define (test name test-fn)
  (display "Testing: ")
  (display name)
  (display "... ")
  (if (test-fn)
      (begin
        (display "PASS\n")
        #t)
      (begin
        (display "FAIL\n")
        #f)))

;; Test reference generation
(test "make-nrr-ref: generates NRR reference"
      (lambda ()
        (let ((ref (make-nrr-ref "test content")))
          (and (string? ref)
               (nrr-ref? ref)))))

(test "nrr-ref?: validates NRR reference"
      (lambda ()
        (and (nrr-ref? "nrr:abc123")
             (not (nrr-ref? "commit:abc123")))))

;; Test reference validation
(test "validate-ref: validates different reference formats"
      (lambda ()
        (and (validate-ref "nrr:abc123")
             (validate-ref "commit:abc123")
             (validate-ref "ref:local"))))

;; Run all tests
(define (run-hash-tests)
  (display "Running NRR hash tests...\n")
  (let ((results '()))
    (set! results (cons (test "make-nrr-ref"
                              (lambda () (nrr-ref? (make-nrr-ref "test"))))
                        results))
    (display "NRR hash tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-hash-tests))

