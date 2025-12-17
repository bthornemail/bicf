;; Property-based tests for AAL Semantics
;; Tests: determinism, progress, preservation

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

;; Property: Determinism
;; For all states s, programs p: step(s, p) is unique
(define (test-determinism)
  (let ((state (make-state '() '() 0 (make-flags #f #f)))
        (prog (list (make-instr 'MOV (list (make-oreg 'R0) (make-oimm '(#t)))))))
    (let ((result1 (step state prog))
          (result2 (step state prog)))
      (equal? result1 result2))))

;; Property: Progress
;; For all well-typed programs p, states s: either step(s, p) exists or s is final
(define (test-progress)
  (let ((state (make-state '() '() 0 (make-flags #f #f)))
        (prog (list (make-instr 'HLT '()))))
    ;; HLT should always be executable
    (let ((result (step state prog)))
      (state? result))))

;; Property: Preservation
;; If state s has type T and step(s, p) = s', then s' has type T
(define (test-preservation)
  ;; Simplified: if step succeeds, state structure is preserved
  (let ((state (make-state '() '() 0 (make-flags #f #f)))
        (prog (list (make-instr 'NOP '()))))
    (let ((next-state (step state prog)))
      (and (state? next-state)
           (= (length (state-regs state)) (length (state-regs next-state)))))))

;; Run all property tests
(define (run-property-tests)
  (display "Running semantics property tests...\n")
  (let ((results '()))
    (set! results (cons (test "determinism"
                              test-determinism)
                        results))
    (set! results (cons (test "progress"
                              test-progress)
                        results))
    (set! results (cons (test "preservation"
                              test-preservation)
                        results))
    (display "Property tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-property-tests))

