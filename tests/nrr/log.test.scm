;; Unit tests for NRR Log

(load "../../src/nrr/log.scm")
(load "../../src/nrr/log-entry.scm")

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

;; Test log entry creation
(test "make-log-entry: creates log entry"
      (lambda ()
        (let ((entry (make-log-entry 0 'boundary "nrr:abc123")))
          (and (log-entry? entry)
               (= (log-entry-phase entry) 0)
               (eq? (log-entry-type entry) 'boundary)))))

;; Test log append
(test "nrr-append: appends log entry"
      (lambda ()
        (nrr-log-clear)
        (let ((entry (make-log-entry 0 'boundary "nrr:abc123")))
          (nrr-append entry)
          (= (nrr-log-size) 1))))

;; Run all tests
(define (run-log-tests)
  (display "Running NRR log tests...\n")
  (let ((results '()))
    (set! results (cons (test "log append"
                              (lambda ()
                                (nrr-log-clear)
                                (nrr-append (make-log-entry 0 'boundary "nrr:test"))
                                (= (nrr-log-size) 1)))
                        results))
    (display "NRR log tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-log-tests))

