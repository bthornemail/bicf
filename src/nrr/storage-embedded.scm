;; ============================================================
;; NRR Embedded Storage Backend (R5RS Scheme)
;; ESP32 flash sector support (placeholder)
;; ============================================================

;; Loaded via `src/nrr/storage.scm` (avoid CWD-relative loads).

;; -----------------------------
;; Embedded Storage Interface
;; -----------------------------

;; make-embedded-backend: Create embedded storage backend
;; This is a placeholder for ESP32 implementation
(define (make-embedded-backend)
  (make-storage-backend
   'embedded
   embedded-put
   embedded-get))

;; embedded-put: Store content in embedded storage
(define (embedded-put content)
  (if (not (string? content))
      (error "embedded-put: expected string" content)
      ;; Placeholder: would use flash sectors on ESP32
      ;; For now, fallback to memory backend
      (let ((ref (make-nrr-ref content)))
        ;; Store in memory as fallback
        (if (defined? 'memory-put)
            (memory-put content)
            (error "embedded-put: embedded backend not fully implemented")))))

;; embedded-get: Retrieve content from embedded storage
(define (embedded-get ref)
  (if (not (string? ref))
      (error "embedded-get: expected string reference" ref)
      ;; Placeholder: would read from flash sectors
      ;; For now, fallback to memory backend
      (if (defined? 'memory-get)
          (memory-get ref)
          (error "embedded-get: embedded backend not fully implemented"))))

;; Note: Full ESP32 implementation would include:
;; - Flash sector management
;; - Ring-buffered log
;; - Optional blob storage
;; - Wear leveling
;; - Error recovery

;; ============================================================
;; End of Embedded Storage (Placeholder)
;; ============================================================
