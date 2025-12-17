;; Integration tests for NRR system

(load "../../src/nrr/storage.scm")
(load "../../src/nrr/log.scm")
(load "../../src/nrr/replay.scm")
(load "../../src/canvasl/nrr-backend.scm")

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

;; Test end-to-end: put, log, replay
(test "NRR integration: put-log-replay"
      (lambda ()
        (init-nrr 'memory)
        (nrr-log-clear)
        (let ((content "test content")
              (ref (nrr-put content))
              (entry (make-log-entry 0 'boundary ref)))
          (nrr-append entry)
          (let ((entries (nrr-log)))
            (and (= (length entries) 1)
                 (equal? (log-entry-ref (car entries)) ref))))))

;; Run all tests
(define (run-integration-tests)
  (display "Running NRR integration tests...\n")
  (let ((results '()))
    (set! results (cons (test "end-to-end"
                              (lambda ()
                                (init-nrr 'memory)
                                (let ((ref (nrr-put "test")))
                                  (string? (nrr-get ref)))))
                        results))
    (display "NRR integration tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-integration-tests))

