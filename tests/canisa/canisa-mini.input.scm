;; Minimal CAN-ISA v1.0 program for deterministic meet/join demonstration.
;;
;; Backend (MVP): univariate F₂[x] polynomials.
;; Convention: current state is implicit; STATE_COPY uses handle 0 to mean "current".
;;
;; Build:
;;   p = x^3 + 1
;;   q = x^2 + 1
;; gcd(p,q) = x + 1
;;
;; Program computes gcd and hashes the canonical state into out-handle 1.

(
  (DEF_MOD 0 2)

  ;; p = x^3 + 1
  (STATE_CLEAR)
  (TERM_NEW 10 1 0)        ;; const 1
  (STATE_ADD 10)
  (TERM_NEW 11 1 3)        ;; x^3
  (STATE_ADD 11)
  (STATE_NORM 1)
  (STATE_COPY 100 0)       ;; s100 := p

  ;; q = x^2 + 1
  (STATE_CLEAR)
  (TERM_NEW 12 1 0)        ;; const 1
  (STATE_ADD 12)
  (TERM_NEW 13 1 2)        ;; x^2
  (STATE_ADD 13)
  (STATE_NORM 1)
  (STATE_COPY 101 0)       ;; s101 := q

  ;; gcd(p, q)
  (STATE_COPY 0 100)       ;; current := p
  (STATE_GCD 101)
  (STATE_NORM 1)
  (STATE_HASH 1 1)         ;; SHA-256 into out=1
  (PROJ_FANO 2)            ;; Fano projection hash into out=2
  (HALT)
)
