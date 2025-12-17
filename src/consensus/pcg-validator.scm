;; Pair-Cover Guarantee (PCG) Validator
;; Implements PCG validation per RFC-0002 and RFC-0003

;; Standard Fano plane lines (from Lean 4 formalization)
;; First Fano plane (points 0-6):
(define fano-lines-first
  '((0 1 3)    ; L0
    (0 2 6)    ; L1
    (0 4 5)    ; L2
    (1 2 4)    ; L3
    (1 5 6)    ; L4
    (2 3 5)    ; L5
    (3 4 6)))  ; L6

;; Second Fano plane (points 7-13, mapped from first by adding 7)
(define (map-to-second-half line)
  (map (lambda (p) (+ p 7)) line))

(define fano-lines-second
  (map map-to-second-half fano-lines-first))

;; All 14 lines (7 from first Fano + 7 from second Fano)
(define all-pcg-lines
  (append fano-lines-first fano-lines-second))

;; Helper: check if point is in line
(define (point-in-line? point line)
  (member point line))

;; Helper: count how many points from triple are in a line
(define (count-triple-in-line triple line)
  (let ((p1 (car triple))
        (p2 (cadr triple))
        (p3 (caddr triple)))
    (+ (if (point-in-line? p1 line) 1 0)
       (if (point-in-line? p2 line) 1 0)
       (if (point-in-line? p3 line) 1 0))))

;; Helper: check if a triple is covered by at least one line (≥2 points on line)
(define (triple-covered? triple lines)
  (let check-lines ((lines lines))
    (if (null? lines)
        #f
        (let ((line (car lines)))
          (if (>= (count-triple-in-line triple line) 2)
              #t
              (check-lines (cdr lines)))))))

;; Generate all triples from a universe of points
(define (generate-triples points)
  (let loop ((points points) (triples '()))
    (if (< (length points) 3)
        triples
        (let ((p1 (car points)))
          (let loop2 ((rest1 (cdr points)) (acc triples))
            (if (< (length rest1) 2)
                (loop (cdr points) acc)
                (let ((p2 (car rest1)))
                  (let loop3 ((rest2 (cdr rest1)) (acc2 acc))
                    (if (null? rest2)
                        (loop2 (cdr rest1) acc2)
                        (let ((p3 (car rest2)))
                          (loop3 (cdr rest2) (cons (list p1 p2 p3) acc2))))))))))))

;; Extract universe and lines from decoded structure
;; Expected format: decoded may contain 'universe and 'lines
;; If not present, assume standard 14-point universe with 14 lines
(define (extract-pcg-structure decoded)
  (let ((universe (if (assq 'universe decoded)
                      (cdr (assq 'universe decoded))
                      (list 0 1 2 3 4 5 6 7 8 9 10 11 12 13)))
        (lines (if (assq 'lines decoded)
                  (cdr (assq 'lines decoded))
                  all-pcg-lines)))
    (cons universe lines)))

;; Validate Pair-Cover Guarantee
;; PCG: For every triple T ⊆ U with |T| = 3, there exists a line ℓ ∈ L such that:
;;      |T ∩ ℓ| ≥ 2
(define (check-pcg-pair-cover decoded boundary)
  (let* ((structure (extract-pcg-structure decoded))
         (universe (car structure))
         (lines (cdr structure))
         (triples (generate-triples universe)))
    
    ;; Check each triple
    (let check-all-triples ((triples triples))
      (if (null? triples)
          #t  ; All triples covered
          (let ((triple (car triples)))
            (if (triple-covered? triple lines)
                (check-all-triples (cdr triples))
                (error "PCG validation failed: triple" triple "not covered by any line")))))))

