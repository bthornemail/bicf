;; Integration tests for AAL system

(load "../../src/aal/interpreter.scm")

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

;; Test end-to-end compilation and execution
(test "compile simple program"
      (lambda ()
        (let ((result (compile "MOV R0, #1\nADD R0, #1\n")))
          (and (list? result)
               (eq? (car result) 'CompiledProgram)))))

;; Test interpreter
(test "interpret simple program"
      (lambda ()
        (let ((result (interpret "MOV R0, #1\nHLT\n")))
          (and (list? result)
               (eq? (car result) 'ExecutionResult)))))

;; Run all tests
(define (run-integration-tests)
  (display "Running integration tests...\n")
  (let ((results '()))
    (set! results (cons (test "compile simple program"
                              (lambda ()
                                (let ((result (compile "MOV R0, #1\n")))
                                  (and (list? result)
                                       (eq? (car result) 'CompiledProgram)))))
                        results))
    (display "Integration tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-integration-tests))

