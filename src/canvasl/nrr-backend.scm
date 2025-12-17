;; ============================================================
;; CanvasL NRR Backend (R5RS Scheme)
;; Replace in-memory environment with NRR storage
;; ============================================================

(load "../nrr/hash.scm")
(load "../nrr/storage.scm")

;; -----------------------------
;; NRR-Enhanced Environment
;; -----------------------------

;; env-empty: Create empty environment (same interface)
(define (env-empty-nrr)
  '())

;; env-get: Get value from environment or NRR storage
(define (env-get-nrr env ref)
  (if (not (string? ref))
      (error "env-get-nrr: expected string reference" ref)
      ;; Check in-memory environment first
      (let ((p (assoc ref env)))
        (if p
            (cdr p)
            ;; Check if it's an NRR reference
            (if (nrr-ref? ref)
                ;; Use NRR storage
                (let ((nrr-result (catch #t
                                         (lambda () (nrr-get ref))
                                         (lambda (key . args) #f))))
                  (if nrr-result
                      nrr-result
                      #f))
                ;; Try NRR if not in memory (might be stored)
                (let ((nrr-result (catch #t
                                       (lambda () (nrr-get ref))
                                       (lambda (key . args) #f))))
                  (if nrr-result
                      nrr-result
                      #f)))))))

;; env-set: Set value in environment, store in NRR if needed
(define (env-set-nrr env ref val)
  (if (not (string? ref))
      (error "env-set-nrr: expected string reference" ref)
      ;; Store in NRR and get reference
      (let ((content (serialize-content val))
            (nrr-ref (nrr-put content)))
        ;; Store both local reference and NRR reference
        (cons (cons ref val)
              (cons (cons nrr-ref nrr-ref) env)))))

;; env-get/req: Required environment get (with NRR)
(define (env-get/req-nrr env ref)
  (let ((v (env-get-nrr env ref)))
    (if v
        v
        (error "unresolved reference" ref))))

;; -----------------------------
;; Reference Conversion
;; -----------------------------

;; convert-ref-to-nrr: Convert string reference to NRR reference
(define (convert-ref-to-nrr ref content)
  (if (not (string? ref))
      (error "convert-ref-to-nrr: expected string" ref)
      (if (nrr-ref? ref)
          ref
          (let ((serialized (serialize-content content)))
            (make-nrr-ref serialized)))))

;; -----------------------------
;; Integration with CanvasL Interpreter
;; -----------------------------

;; Enhanced exec-step: Use NRR backend
;; Note: This would require modifying exec-step to accept environment functions
;; For now, we provide compatibility wrappers
(define (exec-step-nrr env boundary-reg step)
  ;; Use original exec-step but with NRR-aware environment
  ;; In full implementation, would pass env-get-nrr and env-set-nrr to exec-step
  (exec-step env boundary-reg step))

;; -----------------------------
;; Backward Compatibility
;; -----------------------------

;; Helper: check if symbol is defined
(define (defined? sym)
  (let ((result (catch #t
                     (lambda () (eval sym))
                     (lambda (key . args) #f))))
    (not (eq? result #f))))

;; Use NRR backend if available, fallback to original
(define (env-get-compat env ref)
  (if (and (defined? 'nrr-get) (defined? 'nrr-ref?))
      (env-get-nrr env ref)
      (env-get env ref)))

(define (env-set-compat env ref val)
  (if (and (defined? 'nrr-put) (defined? 'serialize-content))
      (env-set-nrr env ref val)
      (env-set env ref val)))

;; ============================================================
;; End of CanvasL NRR Backend
;; ============================================================

