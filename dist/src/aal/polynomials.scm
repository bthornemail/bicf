;; ============================================================
;; AAL Polynomial Algebra (R5RS Scheme)
;; Implements polynomial operations over F2[x]
;; Source: AAL Spec Section 7
;; ============================================================

;; -----------------------------
;; Type Definition
;; -----------------------------

;; poly: list of booleans (little-endian, canonical form)
;; Example: [true, false, true] represents 1 + x^2 = x^2 + 1
;;          (coefficient of x^0 is first element)

(define (poly? x)
  (and (list? x)
       (or (null? x)
           (and (not (null? x))
                (let loop ((lst x))
                  (if (null? lst)
                      #t
                      (and (boolean? (car lst))
                           (loop (cdr lst)))))))))

;; -----------------------------
;; Canonical Form
;; -----------------------------

;; trim: Remove trailing zeros to get canonical form
;; [true, false, false] -> [true]
;; [] -> [] (zero polynomial)
(define (trim poly)
  (if (not (poly? poly))
      (error "trim: expected poly" poly)
      (let loop ((lst (reverse poly)))
        (if (null? lst)
            '()
            (if (car lst)
                (reverse lst)
                (loop (cdr lst)))))))

;; poly-equal?: Check if two polynomials are equal (in canonical form)
(define (poly-equal? p1 p2)
  (if (not (poly? p1))
      (error "poly-equal?: expected poly" p1)
      (if (not (poly? p2))
          (error "poly-equal?: expected poly" p2)
          (equal? (trim p1) (trim p2)))))

;; -----------------------------
;; Basic Operations
;; -----------------------------

;; poly-add: Coefficient-wise XOR (addition in F2)
;; [true, false] + [false, true] = [true, true]
(define (poly-add p1 p2)
  (if (not (poly? p1))
      (error "poly-add: expected poly" p1)
      (if (not (poly? p2))
          (error "poly-add: expected poly" p2)
          (let ((p1-trimmed (trim p1))
                (p2-trimmed (trim p2))
                (max-len (max (length p1-trimmed) (length p2-trimmed))))
            (trim
             (let loop ((i 0)
                        (result '()))
               (if (>= i max-len)
                   (reverse result)
                   (let ((c1 (if (< i (length p1-trimmed))
                                 (list-ref p1-trimmed i)
                                 #f))
                         (c2 (if (< i (length p2-trimmed))
                                 (list-ref p2-trimmed i)
                                 #f)))
                     (loop (+ i 1)
                           (cons (xor c1 c2) result))))))))))

;; Helper: XOR for booleans
(define (xor a b)
  (if a
      (not b)
      b))

;; poly-mul: Convolution modulo 2
;; Multiply two polynomials: (a0 + a1*x + ...) * (b0 + b1*x + ...)
(define (poly-mul p1 p2)
  (if (not (poly? p1))
      (error "poly-mul: expected poly" p1)
      (if (not (poly? p2))
          (error "poly-mul: expected poly" p2)
          (let ((p1-trimmed (trim p1))
                (p2-trimmed (trim p2)))
            (if (or (null? p1-trimmed) (null? p2-trimmed))
                '()
                (trim
                 (let ((result-len (+ (length p1-trimmed) (length p2-trimmed) -1)))
                   (let loop ((i 0)
                              (result '()))
                     (if (>= i result-len)
                         (reverse result)
                         (let ((coeff
                                (let inner-loop ((j 0)
                                                 (sum #f))
                                  (if (> j (min i (- (length p1-trimmed) 1)))
                                      sum
                                      (let ((k (- i j)))
                                        (if (and (>= k 0)
                                                 (< k (length p2-trimmed)))
                                            (inner-loop (+ j 1)
                                                        (xor sum
                                                             (and (list-ref p1-trimmed j)
                                                                  (list-ref p2-trimmed k))))
                                            (inner-loop (+ j 1) sum)))))))
                           (loop (+ i 1)
                                 (cons coeff result))))))))))

;; -----------------------------
;; Shift Operations
;; -----------------------------

;; shift-left: Multiply by x^k (shift left by k positions)
;; shift-left([true], 2) = [false, false, true] (represents x^2)
(define (shift-left poly k)
  (if (not (poly? poly))
      (error "shift-left: expected poly" poly)
      (if (not (integer? k))
          (error "shift-left: expected integer" k)
          (if (< k 0)
              (error "shift-left: k must be non-negative" k)
              (if (null? (trim poly))
                  '()
                  (append (make-list k #f) poly))))))

;; Helper: make-list creates a list of n elements
(define (make-list n val)
  (if (<= n 0)
      '()
      (cons val (make-list (- n 1) val))))

;; shift-right: Divide by x^k (shift right by k positions, v3.2 addition)
;; shift-right([false, false, true], 2) = [true]
(define (shift-right poly k)
  (if (not (poly? poly))
      (error "shift-right: expected poly" poly)
      (if (not (integer? k))
          (error "shift-right: expected integer" k)
          (if (< k 0)
              (error "shift-right: k must be non-negative" k)
              (if (>= k (length poly))
                  '()
                  (list-tail poly k))))))

;; Helper: list-tail returns the tail of a list starting at index k
;; (R5RS doesn't have list-tail, so we implement it)
(define (list-tail lst k)
  (if (<= k 0)
      lst
      (if (null? lst)
          '()
          (list-tail (cdr lst) (- k 1)))))

;; -----------------------------
;; Division and GCD
;; -----------------------------

;; poly-divmod: Euclidean division
;; Returns (quotient . remainder)
(define (poly-divmod dividend divisor)
  (if (not (poly? dividend))
      (error "poly-divmod: expected poly" dividend)
      (if (not (poly? divisor))
          (error "poly-divmod: expected poly" divisor)
          (let ((divisor-trimmed (trim divisor)))
            (if (null? divisor-trimmed)
                (error "poly-divmod: division by zero")
                (let ((dividend-trimmed (trim dividend)))
                  (if (null? dividend-trimmed)
                      (cons '() '())
                      (let ((divisor-deg (- (length divisor-trimmed) 1))
                            (dividend-deg (- (length dividend-trimmed) 1)))
                        (if (< dividend-deg divisor-deg)
                            (cons '() dividend-trimmed)
                            ;; Perform polynomial long division
                            (let loop ((q '())
                                       (r dividend-trimmed))
                              (let ((r-deg (- (length (trim r)) 1)))
                                (if (< r-deg divisor-deg)
                                    (cons (reverse q) (trim r))
                                    ;; Leading coefficient of r
                                    (let ((r-leading (list-ref (trim r) r-deg)))
                                      (if (not r-leading)
                                          (cons (reverse q) (trim r))
                                          ;; Multiply divisor by x^(r-deg - divisor-deg) and add to quotient
                                          (let ((shift-amt (- r-deg divisor-deg))
                                                (divisor-shifted (shift-left divisor-trimmed shift-amt)))
                                            (loop (cons #t q)
                                                  (trim (poly-add r divisor-shifted))))))))))))))))))

;; poly-div: Division (quotient only)
(define (poly-div dividend divisor)
  (car (poly-divmod dividend divisor)))

;; poly-mod: Modulo (remainder only)
(define (poly-mod dividend divisor)
  (cdr (poly-divmod dividend divisor)))

;; poly-gcd: Extended Euclidean algorithm
(define (poly-gcd a b)
  (if (not (poly? a))
      (error "poly-gcd: expected poly" a)
      (if (not (poly? b))
          (error "poly-gcd: expected poly" b)
          (let ((a-trimmed (trim a))
                (b-trimmed (trim b)))
            (if (null? b-trimmed)
                a-trimmed
                (if (null? a-trimmed)
                    b-trimmed
                    (let loop ((a a-trimmed)
                               (b b-trimmed))
                      (let ((b-trim (trim b)))
                        (if (null? b-trim)
                            a
                            (loop b-trim (poly-mod a b))))))))))))

;; poly-lcm: Least common multiple
;; Using: P × Q = GCD(P,Q) × LCM(P,Q)
;; So: LCM(P,Q) = (P × Q) / GCD(P,Q)
(define (poly-lcm p q)
  (if (not (poly? p))
      (error "poly-lcm: expected poly" p)
      (if (not (poly? q))
          (error "poly-lcm: expected poly" q)
          (let ((p-trimmed (trim p))
                (q-trimmed (trim q)))
            (if (or (null? p-trimmed) (null? q-trimmed))
                '()
                (let ((gcd-pq (poly-gcd p-trimmed q-trimmed)))
                  (if (null? (trim gcd-pq))
                      '()
                      ;; LCM = (P × Q) / GCD
                      (let ((prod (poly-mul p-trimmed q-trimmed)))
                        (poly-div prod gcd-pq))))))))))

;; -----------------------------
;; Verification Functions
;; -----------------------------

;; Verify commutativity: P + Q = Q + P
(define (verify-commutativity p q)
  (poly-equal? (poly-add p q) (poly-add q p)))

;; Verify associativity: (P + Q) + R = P + (Q + R)
(define (verify-associativity p q r)
  (poly-equal? (poly-add (poly-add p q) r)
               (poly-add p (poly-add q r))))

;; Verify distributivity: P × (Q + R) = (P × Q) + (P × R)
(define (verify-distributivity p q r)
  (poly-equal? (poly-mul p (poly-add q r))
               (poly-add (poly-mul p q) (poly-mul p r))))

;; Verify GCD × LCM = P × Q theorem
(define (verify-gcd-lcm-theorem p q)
  (let ((gcd-pq (poly-gcd (trim p) (trim q)))
        (lcm-pq (poly-lcm (trim p) (trim q)))
        (prod-pq (poly-mul (trim p) (trim q))))
    (poly-equal? (poly-mul gcd-pq lcm-pq) prod-pq)))

;; -----------------------------
;; Utility Functions
;; -----------------------------

;; poly-degree: Degree of polynomial (length - 1, or -1 for zero)
(define (poly-degree poly)
  (if (not (poly? poly))
      (error "poly-degree: expected poly" poly)
      (let ((trimmed (trim poly)))
        (if (null? trimmed)
            -1
            (- (length trimmed) 1)))))

;; poly-zero?: Check if polynomial is zero
(define (poly-zero? poly)
  (null? (trim poly)))

;; nat-to-poly: Convert natural number to polynomial
;; nat-to-poly(5) = [true, false, true] (binary: 101 = 1 + x^2)
(define (nat-to-poly n)
  (if (not (integer? n))
      (error "nat-to-poly: expected integer" n)
      (if (< n 0)
          (error "nat-to-poly: n must be non-negative" n)
          (if (= n 0)
              '()
              (let loop ((n n)
                         (result '()))
                (if (= n 0)
                    result
                    (loop (quotient n 2)
                          (cons (odd? n) result))))))))

;; poly-to-nat: Convert polynomial to natural number
;; poly-to-nat([true, false, true]) = 5
(define (poly-to-nat poly)
  (if (not (poly? poly))
      (error "poly-to-nat: expected poly" poly)
      (let loop ((lst (trim poly))
                 (power 0)
                 (sum 0))
        (if (null? lst)
            sum
            (loop (cdr lst)
                  (+ power 1)
                  (if (car lst)
                      (+ sum (expt 2 power))
                      sum))))))

;; ============================================================
;; End of Polynomial Algebra
;; ============================================================

