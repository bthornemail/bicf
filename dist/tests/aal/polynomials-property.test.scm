;; Property-based tests for AAL Polynomial Algebra
;; Tests algebraic laws: commutativity, associativity, distributivity

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

;; Property: Commutativity of addition
;; For all polynomials P, Q: P + Q = Q + P
(define (test-commutativity-add)
  (let ((p '(#t #f #t))
        (q '(#f #t #t)))
    (let ((pq (poly-add p q))
          (qp (poly-add q p)))
      (equal? pq qp))))

;; Property: Associativity of addition
;; For all polynomials P, Q, R: (P + Q) + R = P + (Q + R)
(define (test-associativity-add)
  (let ((p '(#t #f))
        (q '(#f #t))
        (r '(#t #t)))
    (let ((pq-r (poly-add (poly-add p q) r))
          (p-qr (poly-add p (poly-add q r))))
      (equal? pq-r p-qr))))

;; Property: Commutativity of multiplication
;; For all polynomials P, Q: P * Q = Q * P
(define (test-commutativity-mul)
  (let ((p '(#t #f))
        (q '(#f #t)))
    (let ((pq (poly-mul p q))
          (qp (poly-mul q p)))
      (equal? pq qp))))

;; Property: Associativity of multiplication
;; For all polynomials P, Q, R: (P * Q) * R = P * (Q * R)
(define (test-associativity-mul)
  (let ((p '(#t #f))
        (q '(#f #t))
        (r '(#t #t)))
    (let ((pq-r (poly-mul (poly-mul p q) r))
          (p-qr (poly-mul p (poly-mul q r))))
      (equal? pq-r p-qr))))

;; Property: Distributivity
;; For all polynomials P, Q, R: P * (Q + R) = (P * Q) + (P * R)
(define (test-distributivity)
  (let ((p '(#t #f))
        (q '(#f #t))
        (r '(#t #t)))
    (let ((p-qr (poly-mul p (poly-add q r)))
          (pq-pr (poly-add (poly-mul p q) (poly-mul p r))))
      (equal? p-qr pq-pr))))

;; Property: Identity element for addition
;; For all polynomials P: P + 0 = P
(define (test-add-identity)
  (let ((p '(#t #f #t))
        (zero '()))
    (let ((p-zero (poly-add p zero)))
      (equal? (trim p) (trim p-zero)))))

;; Property: Identity element for multiplication
;; For all polynomials P: P * 1 = P (where 1 = (#t))
(define (test-mul-identity)
  (let ((p '(#t #f #t))
        (one '(#t)))
    (let ((p-one (poly-mul p one)))
      (equal? (trim p) (trim p-one)))))

;; Property: GCD × LCM = P × Q
;; For all polynomials P, Q: gcd(P, Q) * lcm(P, Q) = P * Q
(define (test-gcd-lcm)
  (let ((p '(#t #f #t))
        (q '(#f #t #t)))
    (let ((gcd-pq (poly-gcd p q))
          (lcm-pq (poly-lcm p q))
          (pq (poly-mul p q))
          (gcd-lcm (poly-mul gcd-pq lcm-pq)))
      (equal? (trim pq) (trim gcd-lcm)))))

;; Run all property tests
(define (run-property-tests)
  (display "Running polynomial algebra property tests...\n")
  (let ((results '()))
    (set! results (cons (test "commutativity of addition"
                              test-commutativity-add)
                        results))
    (set! results (cons (test "associativity of addition"
                              test-associativity-add)
                        results))
    (set! results (cons (test "commutativity of multiplication"
                              test-commutativity-mul)
                        results))
    (set! results (cons (test "associativity of multiplication"
                              test-associativity-mul)
                        results))
    (set! results (cons (test "distributivity"
                              test-distributivity)
                        results))
    (set! results (cons (test "additive identity"
                              test-add-identity)
                        results))
    (set! results (cons (test "multiplicative identity"
                              test-mul-identity)
                        results))
    (set! results (cons (test "GCD × LCM = P × Q"
                              test-gcd-lcm)
                        results))
    (display "Property tests completed.\n")
    results))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-property-tests))

