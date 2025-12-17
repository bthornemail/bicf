;; Unit tests for AAL Type System

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

;; Test dimension ordering
(test "dim-le: D0 <= D1"
      (lambda ()
        (dim-le 'D0 'D1)))

(test "dim-le: D0 <= D0"
      (lambda ()
        (dim-le 'D0 'D0)))

(test "max-dim: D0 and D1"
      (lambda ()
        (eq? (max-dim 'D0 'D1) 'D1)))

;; Test min-grade
(test "min-grade: MOV is D0"
      (lambda ()
        (eq? (min-grade 'MOV) 'D0)))

(test "min-grade: LD is D3"
      (lambda ()
        (eq? (min-grade 'LD) 'D3)))

;; Test typed-instr
(test "typed-instr: MOV reg, reg"
      (lambda ()
        (let ((instr (make-instr 'MOV (list (make-oreg 'R0) (make-oreg 'R1)))))
          (let ((ty (typed-instr instr)))
            (and (box? ty)
                 (eq? (box-dim ty) 'D0))))))

;; Run all tests
(define (run-types-tests)
  (display "Running type system tests...\n")
  (let ((results '()))
    (set! results (cons (test "dim-le D0 <= D1"
                              (lambda () (dim-le 'D0 'D1)))
                        results))
    (set! results (cons (test "min-grade MOV"
                              (lambda () (eq? (min-grade 'MOV) 'D0)))
                        results))
    (display "Type system tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-types-tests))

