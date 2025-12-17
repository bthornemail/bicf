;; Unit tests for AAL Semantics

(load "../../src/aal/semantics.scm")

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

;; Test state creation
(test "make-initial-state"
      (lambda ()
        (let ((state (make-state '() '() 0 (make-flags #f #f))))
          (and (state? state)
               (= (state-pc state) 0)))))

;; Test step relation
(test "step: MOV instruction"
      (lambda ()
        (let ((prog (list (make-instr 'MOV (list (make-oreg 'R0) (make-oimm '(#t))))))
              (state (make-state '() '() 0 (make-flags #f #f))))
          (let ((next-state (step state prog)))
            (and (state? next-state)
                 (= (state-pc next-state) 1))))))

;; Run all tests
(define (run-semantics-tests)
  (display "Running semantics tests...\n")
  (let ((results '()))
    (set! results (cons (test "state creation"
                              (lambda ()
                                (state? (make-state '() '() 0 (make-flags #f #f)))))
                        results))
    (display "Semantics tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-semantics-tests))

