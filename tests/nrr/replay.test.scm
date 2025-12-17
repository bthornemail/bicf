;; Unit tests for NRR Replay

(load "../../src/nrr/replay.scm")
(load "../../src/nrr/log.scm")

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

;; Test replay validation
(test "validate-replay: validates log entries"
      (lambda ()
        (let ((entries (list (make-log-entry 0 'boundary "nrr:test1")
                             (make-log-entry 1 'interior "nrr:test2"))))
          (validate-replay entries))))

;; Run all tests
(define (run-replay-tests)
  (display "Running NRR replay tests...\n")
  (let ((results '()))
    (set! results (cons (test "replay validation"
                              (lambda ()
                                (validate-replay (list (make-log-entry 0 'boundary "nrr:test")))))
                        results))
    (display "NRR replay tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-replay-tests))

