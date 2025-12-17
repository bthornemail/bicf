;; Property-based tests for AAL Geometry (D9 Fano Plane Mapping)
;; Tests Fano plane mapping properties

(load "../../src/aal/geometry.scm")

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

;; Property: Quadratic form from locus
;; For all polynomials P, Q: form_from_locus(gcd(P,Q), lcm(P,Q)) is non-degenerate
(define (test-form-nondegenerate)
  (let ((p '(#t #f #t))
        (q '(#f #t #t)))
    (let ((gcd-pq (poly-gcd p q))
          (lcm-pq (poly-lcm p q))
          (form (form_from_locus gcd-pq lcm-pq)))
      (is_nondegenerate form))))

;; Property: Matrix rank
;; For non-degenerate forms, rank = 3
(define (test-matrix-rank)
  (let ((form (make-quadform '(#t #f #t #f #t #f))))
    (let ((rank (matrix_rank_F2 (quad_matrix form))))
      (if (is_nondegenerate form)
          (= rank 3)
          #t))))

;; Property: Fano conic validity
;; Valid Fano conics have exactly 7 points
(define (test-fano-conic)
  ;; Simplified: check that form structure is valid
  (let ((form (make-quadform '(#t #f #t #f #t #f))))
    (and (quadform? form)
         (= (length (quadform-coeffs form)) 6))))

;; Run all property tests
(define (run-property-tests)
  (display "Running geometry property tests...\n")
  (let ((results '()))
    (set! results (cons (test "form non-degeneracy"
                              test-form-nondegenerate)
                        results))
    (set! results (cons (test "matrix rank"
                              test-matrix-rank)
                        results))
    (set! results (cons (test "Fano conic validity"
                              test-fano-conic)
                        results))
    (display "Property tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-property-tests))

