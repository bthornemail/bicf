;; Unit tests for NRR Storage

(load "../../src/nrr/storage.scm")
(load "../../src/nrr/storage-memory.scm")

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

;; Test memory storage
(test "memory-put: stores content and returns reference"
      (lambda ()
        (init-nrr 'memory)
        (let ((ref (nrr-put "test content")))
          (and (string? ref)
               (nrr-ref? ref)))))

(test "memory-get: retrieves content by reference"
      (lambda ()
        (init-nrr 'memory)
        (let ((ref (nrr-put "test content")))
          (let ((content (nrr-get ref)))
            (string=? content "test content")))))

;; Run all tests
(define (run-storage-tests)
  (display "Running NRR storage tests...\n")
  (let ((results '()))
    (set! results (cons (test "memory storage"
                              (lambda ()
                                (init-nrr 'memory)
                                (let ((ref (nrr-put "test")))
                                  (string? (nrr-get ref)))))
                        results))
    (display "NRR storage tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-storage-tests))

