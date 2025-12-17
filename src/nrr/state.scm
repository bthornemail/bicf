;; ============================================================
;; NRR Polynomial State Management (R5RS Scheme)
;; State compression: coefficients + inputs + phase
;; ============================================================

(load "replay.scm")

;; -----------------------------
;; Polynomial State Representation
;; -----------------------------

;; State: (coefficients, inputs, phase)
;; Instead of storing full state, store polynomial representation
(define (make-polynomial-state coefficients inputs phase)
  (list 'PolynomialState coefficients inputs phase))

(define (polynomial-state? x)
  (and (list? x)
       (= (length x) 4)
       (eq? (car x) 'PolynomialState)))

(define (polynomial-state-coeffs state)
  (if (polynomial-state? state)
      (cadr state)
      (error "polynomial-state-coeffs: expected PolynomialState" state)))

(define (polynomial-state-inputs state)
  (if (polynomial-state? state)
      (caddr state)
      (error "polynomial-state-inputs: expected PolynomialState" state)))

(define (polynomial-state-phase state)
  (if (polynomial-state? state)
      (cadddr state)
      (error "polynomial-state-phase: expected PolynomialState" state)))

;; -----------------------------
;; State Compression
;; -----------------------------

;; compress-state: Compress execution state to polynomial representation
(define (compress-state env phase)
  (if (not (list? env))
      (error "compress-state: expected environment" env)
      (if (not (integer? phase))
          (error "compress-state: expected integer phase" phase)
          ;; Extract coefficients and inputs from environment
          (let ((coefficients '())
                (inputs '()))
            (let loop ((env env))
              (if (null? env)
                  (make-polynomial-state coefficients inputs phase)
                  (let ((entry (car env))
                        (ref (car entry))
                        (val (cdr entry)))
                    ;; Convert value to polynomial if possible
                    (if (list? val)
                        (let ((poly (if (poly? val)
                                       val
                                       (list-to-poly val))))
                          (set! coefficients (cons (cons ref poly) coefficients))
                          (loop (cdr env)))
                        (begin
                          (set! inputs (cons (cons ref val) inputs))
                          (loop (cdr env))))))))))

;; list-to-poly: Convert list to polynomial
(define (list-to-poly lst)
  (if (not (list? lst))
      (error "list-to-poly: expected list" lst)
      (map (lambda (x)
             (if (number? x)
                 (not (= x 0))
                 (if (boolean? x)
                     x
                     #f)))
           lst)))

;; -----------------------------
;; State Decompression
;; -----------------------------

;; decompress-state: Reconstruct environment from polynomial state
(define (decompress-state poly-state)
  (if (not (polynomial-state? poly-state))
      (error "decompress-state: expected PolynomialState" poly-state)
      (let ((coeffs (polynomial-state-coeffs poly-state))
            (inputs (polynomial-state-inputs poly-state))
            (env '()))
        ;; Reconstruct from coefficients
        (let coeff-loop ((coeffs coeffs))
          (if (not (null? coeffs))
              (let ((entry (car coeffs))
                    (ref (car entry))
                    (poly (cdr entry)))
                (set! env (cons (cons ref (poly-to-list poly)) env))
                (coeff-loop (cdr coeffs)))))
        ;; Add inputs
        (let input-loop ((inputs inputs))
          (if (not (null? inputs))
              (let ((entry (car inputs)))
                (set! env (cons entry env))
                (input-loop (cdr inputs)))))
        env)))

;; poly-to-list: Convert polynomial to list
(define (poly-to-list poly)
  (if (not (poly? poly))
      (error "poly-to-list: expected poly" poly)
      (map (lambda (b) (if b 1 0)) poly)))

;; -----------------------------
;; Constant Memory Replay
;; -----------------------------

;; replay-with-compression: Replay using polynomial state compression
(define (replay-with-compression entries boundary-reg)
  (if (not (list? entries))
      (error "replay-with-compression: expected list" entries)
      (let ((initial-state (make-replay-state
                            (env-empty)
                            boundary-reg
                            -1))
            (compressed-states '()))
        (let loop ((entries entries)
                   (state initial-state))
          (if (null? entries)
              (reverse compressed-states)
              (let ((entry (car entries))
                    (env (replay-state-env state))
                    (phase (replay-state-phase state)))
                ;; Compress state before processing next entry
                (let ((compressed (compress-state env phase)))
                  (set! compressed-states (cons compressed compressed-states))
                  ;; Process entry and continue
                  (let ((new-env (replay-from-log (list entry) boundary-reg)))
                    (loop (cdr entries)
                          (make-replay-state new-env
                                            (replay-state-boundary-reg state)
                                            (log-entry-phase entry))))))))))

;; ============================================================
;; End of Polynomial State Management
;; ============================================================

