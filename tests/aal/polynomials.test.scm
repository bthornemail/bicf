;; Unit tests for AAL Polynomial Algebra

(load "../../src/aal/polynomials.scm")

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

;; Test trim
(test "trim removes trailing zeros"
      (lambda ()
        (poly-equal? (trim '(#t #f #f)) '(#t))))

(test "trim handles empty list"
      (lambda ()
        (poly-equal? (trim '()) '())))

(test "trim handles all zeros"
      (lambda ()
        (poly-equal? (trim '(#f #f #f)) '())))

;; Test poly-add
(test "poly-add: basic addition"
      (lambda ()
        (poly-equal? (poly-add '(#t) '(#f)) '(#t))))

(test "poly-add: XOR property"
      (lambda ()
        (poly-equal? (poly-add '(#t #t) '(#t #t)) '())))

(test "poly-add: different lengths"
      (lambda ()
        (poly-equal? (poly-add '(#t) '(#f #t)) '(#t #t))))

;; Test poly-mul
(test "poly-mul: basic multiplication"
      (lambda ()
        (poly-equal? (poly-mul '(#t) '(#t)) '(#t))))

(test "poly-mul: zero polynomial"
      (lambda ()
        (poly-equal? (poly-mul '(#t) '()) '())))

;; Test shift operations
(test "shift-left: multiply by x"
      (lambda ()
        (poly-equal? (shift-left '(#t) 1) '(#f #t))))

(test "shift-right: divide by x"
      (lambda ()
        (poly-equal? (shift-right '(#f #t) 1) '(#t))))

;; Test GCD/LCM theorem
(test "GCD × LCM = P × Q theorem"
      (lambda ()
        (let ((p '(#t #t))  ;; x + 1
              (q '(#t #f #t)))  ;; x^2 + 1
          (verify-gcd-lcm-theorem p q))))

;; Test algebra laws
(test "commutativity of addition"
      (lambda ()
        (let ((p '(#t #f #t))
              (q '(#f #t)))
          (verify-commutativity p q))))

(test "associativity of addition"
      (lambda ()
        (let ((p '(#t))
              (q '(#f #t))
              (r '(#t #t)))
          (verify-associativity p q r))))

(test "distributivity"
      (lambda ()
        (let ((p '(#t #f))
              (q '(#t))
              (r '(#f #t)))
          (verify-distributivity p q r))))

;; Test nat-to-poly and poly-to-nat
(test "nat-to-poly and poly-to-nat roundtrip"
      (lambda ()
        (let ((n 5))
          (= n (poly-to-nat (nat-to-poly n))))))

;; Run all tests
(define (run-polynomial-tests)
  (display "Running polynomial algebra tests...\n")
  (let ((results '()))
    (set! results (cons (test "trim removes trailing zeros"
                              (lambda () (poly-equal? (trim '(#t #f #f)) '(#t))))
                        results))
    (set! results (cons (test "poly-add basic"
                              (lambda () (poly-equal? (poly-add '(#t) '(#f)) '(#t))))
                        results))
    (set! results (cons (test "GCD × LCM theorem"
                              (lambda () (verify-gcd-lcm-theorem '(#t #t) '(#t #f #t))))
                        results))
    (display "Polynomial tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-polynomial-tests))

