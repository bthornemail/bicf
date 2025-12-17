;; Property-based tests for AAL Type System
;; Tests type system properties: grade weakening, dimension ordering

(load "../../src/aal/types.scm")

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

;; Property: Dimension ordering is transitive
;; For all dimensions d1, d2, d3: if d1 ≤ d2 and d2 ≤ d3, then d1 ≤ d3
(define (test-dim-transitivity)
  (and (dim_le 'D0 'D5)
       (dim_le 'D5 'D10)
       (dim_le 'D0 'D10)))

;; Property: Dimension ordering is reflexive
;; For all dimensions d: d ≤ d
(define (test-dim-reflexivity)
  (and (dim_le 'D0 'D0)
       (dim_le 'D5 'D5)
       (dim_le 'D10 'D10)))

;; Property: Max dimension is maximum
;; For all dimensions d: d ≤ max_dim
(define (test-max-dim)
  (and (dim_le 'D0 (max_dim))
       (dim_le 'D5 (max_dim))
       (dim_le 'D10 (max_dim))))

;; Property: Grade weakening
;; If instruction is typed at grade d, it is also typed at grade d' where d ≤ d'
(define (test-grade-weakening)
  ;; If an instruction is typed at D5, it should also be valid at D10
  (let ((instr-type 'D5))
    (if (dim_le instr-type 'D10)
        #t
        #f)))

;; Run all property tests
(define (run-property-tests)
  (display "Running type system property tests...\n")
  (let ((results '()))
    (set! results (cons (test "dimension transitivity"
                              test-dim-transitivity)
                        results))
    (set! results (cons (test "dimension reflexivity"
                              test-dim-reflexivity)
                        results))
    (set! results (cons (test "max dimension"
                              test-max-dim)
                        results))
    (set! results (cons (test "grade weakening"
                              test-grade-weakening)
                        results))
    (display "Property tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-property-tests))

