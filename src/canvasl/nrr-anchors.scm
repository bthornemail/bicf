;; ============================================================
;; CanvasL NRR Anchor System (R5RS Scheme)
;; Replace Git commit anchors with NRR content references
;; ============================================================

(load "../nrr/hash.scm")
(load "../nrr/storage.scm")

;; Helper: alist-ref (if not available)
(define (alist-ref a k)
  (let ((p (assq k a)))
    (if p (cdr p) #f)))

;; -----------------------------
;; Anchor Generation
;; -----------------------------

;; make-nrr-anchor: Generate NRR anchor from content
(define (make-nrr-anchor content)
  (if (not (string? content))
      (error "make-nrr-anchor: expected string" content)
      (let ((ref (nrr-put content)))
        ref)))

;; make-anchor-from-step: Generate anchor from CanvasL step
(define (make-anchor-from-step step)
  (if (not (list? step))
      (error "make-anchor-from-step: expected list" step)
      (let ((step-content (serialize-content step)))
        (make-nrr-anchor step-content))))

;; -----------------------------
;; Anchor Validation
;; -----------------------------

;; validate-anchor: Validate anchor format (NRR or Git)
(define (validate-anchor anchor)
  (if (not (string? anchor))
      (error "validate-anchor: expected string" anchor)
      (or (nrr-ref? anchor)
          (git-ref? anchor)
          (local-ref? anchor))))

;; -----------------------------
;; Anchor Conversion
;; -----------------------------

;; normalize-anchor: Normalize anchor to NRR format
(define (normalize-anchor anchor)
  (if (not (string? anchor))
      (error "normalize-anchor: expected string" anchor)
      (cond
       ((nrr-ref? anchor) anchor)
       ((git-ref? anchor)
        ;; Convert Git reference to NRR
        (let ((git-hash (substring anchor 7)))  ;; Skip "commit:" prefix
          (string-append "nrr:" git-hash)))
       ((local-ref? anchor) anchor)  ;; Keep local refs
       (else
        ;; Generate new NRR anchor
        (make-nrr-anchor anchor)))))

;; -----------------------------
;; Backward Compatibility
;; -----------------------------

;; Helper: defined?
(define (defined? sym)
  (let ((result (catch #t
                     (lambda () (eval sym))
                     (lambda (key . args) #f))))
    (not (eq? result #f))))

;; get-anchor-content: Get content from anchor (NRR or Git)
(define (get-anchor-content anchor)
  (if (not (string? anchor))
      (error "get-anchor-content: expected string" anchor)
      (cond
       ((nrr-ref? anchor)
        (nrr-get anchor))
       ((git-ref? anchor)
        ;; Try Git adapter if available
        (if (and (defined? 'git-cat-file) (defined? 'git-available?) (git-available?))
            (git-cat-file anchor)
            (error "get-anchor-content: Git adapter not available" anchor)))
       (else
        (error "get-anchor-content: unknown anchor format" anchor)))))

;; -----------------------------
;; Integration with CanvasL
;; -----------------------------

;; update-step-anchor: Update step with NRR anchor
(define (update-step-anchor step)
  (if (not (list? step))
      (error "update-step-anchor: expected list" step)
      (let ((anchor (alist-ref step 'anchor)))
        (if anchor
            (let ((normalized (normalize-anchor anchor)))
              (cons (cons 'anchor normalized) step))
            ;; Generate new anchor
            (let ((new-anchor (make-anchor-from-step step)))
              (cons (cons 'anchor new-anchor) step))))))

;; ============================================================
;; End of NRR Anchor System
;; ============================================================

