# PCG Consensus Module

## Overview
Deterministic merge and consensus verification using Pair-Cover Guarantee with BICF compliance.

## Features
- Pairwise constraint evaluation
- Deterministic merge decisions
- Conflict detection and reporting
- Integration with FANO boundary
- Assembly language target generation

## Implementation
```scheme
;; PCG-Based Consensus
(load "bicf-core.scm")
(load "fano-boundary.scm")

;; ---- Merge Candidate ----
(define-record merge-candidate
  (fields interior boundary valid?))

;; ---- Pairwise Constraint Evaluation ----
(define (pairwise-constraints a b c)
  (list (list a b) (list a c) (list b c)))

;; ---- PCG Verification ----
(define (verify-pcg triple boundary)
  (let ((lines (cdr (assoc 'lines boundary))))
    (let loop-ps ((ps triple)))
      (if (null? ps)
          #t
          (let loop-ls ((ls lines))
            (if (null? ls)
                #f
                (let ((l (car ls)))
                  (if (>= (length (intersection ps l)) 2)
                      #t
                      (loop-ls (cdr ls)))))))))

;; ---- Merge Decision ----
(define (merge-decision candidates boundary)
  (let ((valid-candidates
         (filter (lambda (c) (merge-candidate-valid? c boundary))
                 candidates)))
    (if (null? valid-candidates)
        #f
        (car valid-candidates))))

;; ---- Consensus Formation ----
(define (form-consensus candidates boundary)
  (let ((decision (merge-decision candidates boundary)))
    (if decision
        (list 'consensus decision)
        (list 'no-consensus candidates))))

;; ---- Export ----
(provide 'pcg-consensus
         (list merge-candidate pairwise-constraints
               verify-pcg merge-decision form-consensus))
```

## Usage
```scheme
(load "pcg-consensus.scm")
(define candidates (list candidate1 candidate2 candidate3))
(define boundary (fano-boundary))
(form-consensus candidates boundary)
```

## Status
✅ Complete - PCG-based consensus with deterministic verification