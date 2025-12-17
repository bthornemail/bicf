;; Unit tests for AAL Geometry (D9)

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

;; Test take6
(test "take6 extracts 6 coefficients"
      (lambda ()
        (= (length (take6 '(#t #f #t #f #t #f))) 6)))

;; Test form-from-locus
(test "form-from-locus creates quadratic form"
      (lambda ()
        (let ((qf (form-from-locus '(#t) '(#t))))
          (quad-form? qf))))

;; Test quad-matrix
(test "quad-matrix creates 3x3 matrix"
      (lambda ()
        (let ((qf (make-quad-form #t #f #t #f #t #f))
              (matrix (quad-matrix qf)))
          (and (list? matrix)
               (= (length matrix) 3)
               (= (length (car matrix)) 3)))))

;; Run all tests
(define (run-geometry-tests)
  (display "Running geometry tests...\n")
  (let ((results '()))
    (set! results (cons (test "take6"
                              (lambda () (= (length (take6 '(#t #f #t))) 6)))
                        results))
    (set! results (cons (test "form-from-locus"
                              (lambda () (quad-form? (form-from-locus '(#t) '(#t)))))
                        results))
    (display "Geometry tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-geometry-tests))

