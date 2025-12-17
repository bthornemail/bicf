;; ============================================================
;; AAL Geometric Semantics (D9) - Fano Plane Mapping (R5RS Scheme)
;; Implements D9 Fano Plane mapping
;; Source: AAL Spec Section 9
;; ============================================================

(load "polynomials.scm")

;; -----------------------------
;; Quadratic Form Definition
;; -----------------------------

;; QuadForm: 6 coefficients for ternary quadratic form
;; Q(x,y,z) = cxx*x² + cyy*y² + czz*z² + cxy*xy + cxz*xz + cyz*yz
(define (make-quad-form cxx cyy czz cxy cxz cyz)
  (list 'QuadForm cxx cyy czz cxy cxz cyz))

(define (quad-form? x)
  (and (list? x)
       (= (length x) 7)
       (eq? (car x) 'QuadForm)
       (boolean? (cadr x))
       (boolean? (caddr x))
       (boolean? (cadddr x))
       (boolean? (cadddr (cdr x)))
       (boolean? (cadddr (cddr x)))
       (boolean? (cadddr (cdddr x)))))

(define (quad-form-cxx qf)
  (if (quad-form? qf)
      (cadr qf)
      (error "quad-form-cxx: expected QuadForm" qf)))

(define (quad-form-cyy qf)
  (if (quad-form? qf)
      (caddr qf)
      (error "quad-form-cyy: expected QuadForm" qf)))

(define (quad-form-czz qf)
  (if (quad-form? qf)
      (cadddr qf)
      (error "quad-form-czz: expected QuadForm" qf)))

(define (quad-form-cxy qf)
  (if (quad-form? qf)
      (cadddr (cdr qf))
      (error "quad-form-cxy: expected QuadForm" qf)))

(define (quad-form-cxz qf)
  (if (quad-form? qf)
      (cadddr (cddr qf))
      (error "quad-form-cxz: expected QuadForm" qf)))

(define (quad-form-cyz qf)
  (if (quad-form? qf)
      (cadddr (cdddr qf))
      (error "quad-form-cyz: expected QuadForm" qf)))

;; -----------------------------
;; Geometric Construction
;; -----------------------------

;; take6: Extract 6 coefficients from polynomial
;; Pads with false if polynomial has fewer than 6 coefficients
(define (take6 poly)
  (if (not (poly? poly))
      (error "take6: expected poly" poly)
      (let ((trimmed (trim poly))
            (padded (append trimmed (make-list (max 0 (- 6 (length trimmed))) #f))))
        (list-head padded 6))))

;; form-from-locus: gcd × lcm → quadratic form
;; Constructs quadratic form from product of gcd and lcm
(define (form-from-locus g l)
  (if (not (poly? g))
      (error "form-from-locus: expected poly" g)
      (if (not (poly? l))
          (error "form-from-locus: expected poly" l)
          (let ((prod (poly-mul g l))
                (coeffs (take6 prod)))
            (if (< (length coeffs) 6)
                (make-quad-form #f #f #f #f #f #f)
                (make-quad-form
                 (list-ref coeffs 0)  ;; cxx
                 (list-ref coeffs 1)  ;; cyy
                 (list-ref coeffs 2)  ;; czz
                 (list-ref coeffs 3)  ;; cxy
                 (list-ref coeffs 4)  ;; cxz
                 (list-ref coeffs 5)))))))  ;; cyz

;; -----------------------------
;; Matrix Representation
;; -----------------------------

;; quad-matrix: Symmetric matrix representation of quadratic form
;; Returns 3x3 symmetric matrix over F2
;; Matrix: ((a11 a12 a13) (a21 a22 a23) (a31 a32 a33))
(define (quad-matrix qf)
  (if (not (quad-form? qf))
      (error "quad-matrix: expected QuadForm" qf)
      (let ((cxx (quad-form-cxx qf))
            (cyy (quad-form-cyy qf))
            (czz (quad-form-czz qf))
            (cxy (quad-form-cxy qf))
            (cxz (quad-form-cxz qf))
            (cyz (quad-form-cyz qf)))
        ;; Symmetric matrix:
        ;; [cxx  cxy/2  cxz/2]
        ;; [cxy/2  cyy  cyz/2]
        ;; [cxz/2  cyz/2  czz]
        ;; In F2, division by 2 is identity, so:
        (list
         (list cxx cxy cxz)
         (list cxy cyy cyz)
         (list cxz cyz czz)))))

;; -----------------------------
;; Matrix Rank over F2
;; -----------------------------

;; matrix-rank-F2: Gaussian elimination over F2
;; Returns rank of matrix (0-3)
(define (matrix-rank-F2 matrix)
  (if (not (list? matrix))
      (error "matrix-rank-F2: expected matrix" matrix)
      (if (not (= (length matrix) 3))
          (error "matrix-rank-F2: expected 3x3 matrix" matrix)
          (let ((m (list->vector (map list->vector matrix))))
            ;; Gaussian elimination over F2
            (let loop ((row 0)
                       (col 0)
                       (rank 0))
              (if (>= row 3)
                  rank
                  (if (>= col 3)
                      rank
                      ;; Find pivot
                      (let ((pivot-row
                             (let find-pivot ((r row))
                               (if (>= r 3)
                                   -1
                                   (if (vector-ref (vector-ref m r) col)
                                       r
                                       (find-pivot (+ r 1)))))))
                        (if (< pivot-row 0)
                            ;; No pivot in this column, move to next
                            (loop row (+ col 1) rank)
                            ;; Swap rows if needed
                            (let ((m (if (not (= pivot-row row))
                                        (let ((temp (vector-ref m row)))
                                          (vector-set! m row (vector-ref m pivot-row))
                                          (vector-set! m pivot-row temp)
                                          m)
                                        m)))
                              ;; Eliminate below pivot
                              (let ((m
                                     (let eliminate ((r (+ row 1)))
                                       (if (>= r 3)
                                           m
                                           (if (vector-ref (vector-ref m r) col)
                                               ;; Add pivot row to eliminate
                                               (let ((new-row
                                                      (let xor-row ((c 0)
                                                                    (result '()))
                                                        (if (>= c 3)
                                                            (list->vector (reverse result))
                                                            (xor-row (+ c 1)
                                                                     (cons (xor (vector-ref (vector-ref m r) c)
                                                                                (vector-ref (vector-ref m row) c))
                                                                           result))))))
                                                 (vector-set! m r new-row)
                                                 (eliminate (+ r 1)))
                                               (eliminate (+ r 1)))))))
                                (loop (+ row 1) (+ col 1) (+ rank 1)))))))))))))

;; -----------------------------
;; Non-Degeneracy
;; -----------------------------

;; is-nondegenerate: Check if quadratic form is non-degenerate (rank = 3)
(define (is-nondegenerate qf)
  (if (not (quad-form? qf))
      (error "is-nondegenerate: expected QuadForm" qf)
      (= (matrix-rank-F2 (quad-matrix qf)) 3)))

;; -----------------------------
;; Fano Plane Mapping
;; -----------------------------

;; fano-conic-valid: Verify Fano conic validity
;; A quadratic form is valid if it's non-degenerate
(define (fano-conic-valid qf)
  (is-nondegenerate qf))

;; -----------------------------
;; Utility Functions
;; -----------------------------

;; Helper: list->vector (if not available)
(define (list->vector lst)
  (let ((vec (make-vector (length lst))))
    (let loop ((i 0)
               (remaining lst))
      (if (null? remaining)
          vec
          (begin
            (vector-set! vec i (car remaining))
            (loop (+ i 1) (cdr remaining)))))))

;; Helper: vector->list
(define (vector->list vec)
  (let loop ((i 0)
             (result '()))
    (if (>= i (vector-length vec))
        (reverse result)
        (loop (+ i 1) (cons (vector-ref vec i) result)))))

;; ============================================================
;; End of Geometric Semantics
;; ============================================================

