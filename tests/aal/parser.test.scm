;; Unit tests for AAL Parser

(load "../../src/aal/parser.scm")

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

;; Test parsing simple instruction
(test "parse MOV instruction"
      (lambda ()
        (let ((prog (parse-aal "MOV R0, R1\n")))
          (and (program? prog)
               (= (length (program-instrs prog)) 1)))))

(test "parse ADD instruction"
      (lambda ()
        (let ((prog (parse-aal "ADD R0, #5\n")))
          (and (program? prog)
               (= (length (program-instrs prog)) 1)))))

(test "parse label"
      (lambda ()
        (let ((prog (parse-aal "loop:\nMOV R0, R1\n")))
          (and (program? prog)
               (not (null? (program-labels prog)))))))

;; Run all tests
(define (run-parser-tests)
  (display "Running parser tests...\n")
  (let ((results '()))
    (set! results (cons (test "parse MOV"
                              (lambda ()
                                (let ((prog (parse-aal "MOV R0, R1\n")))
                                  (and (program? prog)
                                       (= (length (program-instrs prog)) 1)))))
                        results))
    (display "Parser tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-parser-tests))

