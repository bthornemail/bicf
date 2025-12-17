;; Unit tests for AAL Assembly Generator

(load "../../src/aal/assembly-generator.scm")
(load "../../src/aal/ast.scm")

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

;; Test register mapping
(test "map-register: x86 mapping"
      (lambda ()
        (let ((mapped (map-register 'R0 'x86)))
          (eq? mapped 'eax))))

(test "map-register: generic mapping"
      (lambda ()
        (let ((mapped (map-register 'R0 'generic)))
          (eq? mapped 'R0))))

;; Test instruction generation
(test "generate-instruction: MOV"
      (lambda ()
        (let ((instr (make-instr 'MOV (list (make-oreg 'R0) (make-oreg 'R1)))))
          (let ((result (generate-instruction instr 'generic '())))
            (and (string? result)
                 (> (string-length result) 0)))))

;; Test assembly generation
(test "generate-assembly: simple program"
      (lambda ()
        (let ((prog (list (make-instr 'MOV (list (make-oreg 'R0) (make-oimm '(#t))))
                          (make-instr 'ADD (list (make-oreg 'R0) (make-oreg 'R1)))
                          (make-instr 'HLT '()))))
          (let ((result (generate-assembly prog 'generic)))
            (and (string? result)
                 (> (string-length result) 0)))))

;; Run all tests
(define (run-assembly-generator-tests)
  (display "Running assembly generator tests...\n")
  (let ((results '()))
    (set! results (cons (test "map-register x86"
                              (lambda () (eq? (map-register 'R0 'x86) 'eax)))
                        results))
    (set! results (cons (test "generate-assembly"
                              (lambda ()
                                (let ((prog (list (make-instr 'NOP '()))))
                                  (string? (generate-assembly prog 'generic)))))
                        results))
    (display "Assembly generator tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-assembly-generator-tests))

