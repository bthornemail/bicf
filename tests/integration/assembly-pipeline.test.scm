;; Integration tests for BICF → AAL → Assembly pipeline

(load "../../src/integration/assembly-generator.scm")

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

;; Test complete pipeline
(test "bicf-to-assembly-pipeline: end-to-end"
      (lambda ()
        (let ((boundary (make-simple-boundary "test-boundary")))
          (let ((result (bicf-to-assembly-pipeline boundary 'generic 'text)))
            (and (list? result)
                 (eq? (car result) 'AssemblyResult)))))

;; Test generate-assembly function
(test "generate-assembly: from boundary"
      (lambda ()
        (let ((boundary (make-simple-boundary "test")))
          (let ((result (generate-assembly boundary 'generic 'text)))
            (and (string? result)
                 (> (string-length result) 0)))))

;; Run all tests
(define (run-assembly-pipeline-tests)
  (display "Running assembly pipeline tests...\n")
  (let ((results '()))
    (set! results (cons (test "pipeline end-to-end"
                              (lambda ()
                                (let ((boundary (make-simple-boundary "test")))
                                  (list? (bicf-to-assembly-pipeline boundary 'generic 'text)))))
                        results))
    (display "Assembly pipeline tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-assembly-pipeline-tests))

