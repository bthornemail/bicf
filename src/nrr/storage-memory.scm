;; ============================================================
;; NRR In-Memory Storage Backend (R5RS Scheme)
;; Minimal memory footprint for testing and embedded systems
;; ============================================================

;; Loaded via `src/nrr/storage.scm` (avoid CWD-relative loads).

;; -----------------------------
;; In-Memory Storage
;; -----------------------------

;; Storage: alist mapping ref -> content
(define *memory-storage* '())

;; make-memory-backend: Create in-memory storage backend
(define (make-memory-backend)
  (make-storage-backend
   'memory
   memory-put
   memory-get))

;; memory-put: Store content in memory, return reference
(define (memory-put content)
  (if (not (string? content))
      (error "memory-put: expected string" content)
      (let* ((payload (serialize-content content))
             (ref (make-nrr-ref payload)))
        ;; Check if already stored (deduplication)
        (let ((existing (assoc ref *memory-storage*)))
          (if existing
              ref
              (begin
                (set! *memory-storage* (cons (cons ref payload) *memory-storage*))
                ref))))))

;; memory-get: Retrieve content from memory by reference
(define (memory-get ref)
  (if (not (string? ref))
      (error "memory-get: expected string reference" ref)
      (let ((entry (assoc ref *memory-storage*)))
        (if entry
            (deserialize-content (cdr entry))
            (error "memory-get: reference not found" ref)))))

;; memory-clear: Clear memory storage (for testing)
(define (memory-clear)
  (set! *memory-storage* '()))

;; memory-size: Get number of stored items
(define (memory-size)
  (length *memory-storage*))

;; ============================================================
;; End of In-Memory Storage
;; ============================================================
