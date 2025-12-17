;; ============================================================
;; NRR Compatibility Layer (R5RS Scheme)
;; Backend selection and fallback
;; ============================================================

(load "storage.scm")
(load "git-adapter.scm")

;; -----------------------------
;; Backend Selection
;; -----------------------------

;; select-backend: Select appropriate storage backend
(define (select-backend backend-type repo-path)
  (if (not (symbol? backend-type))
      (error "select-backend: expected symbol" backend-type)
      (case backend-type
        ((auto)
         ;; Auto-detect: Git if available, else NRR file
         (auto-select-backend repo-path))
        ((nrr file)
         ;; Use NRR file backend
         (init-nrr 'file repo-path)
         (get-storage-backend))
        ((nrr memory)
         ;; Use NRR memory backend
         (init-nrr 'memory)
         (get-storage-backend))
        ((git)
         ;; Use Git backend
         (if (git-available?)
             (make-git-backend)
             (error "select-backend: Git not available")))
        (else
         (error "select-backend: unknown backend type" backend-type)))))

;; -----------------------------
;; Unified Interface
;; -----------------------------

;; nrr-put-unified: Put with automatic backend selection
(define (nrr-put-unified content)
  (if (not *current-backend*)
      (begin
        ;; Auto-initialize with file backend
        (init-nrr 'file "repo/")
        (nrr-put content))
      (nrr-put content)))

;; nrr-get-unified: Get with fallback
(define (nrr-get-unified ref)
  (if (not (string? ref))
      (error "nrr-get-unified: expected string" ref)
      (cond
       ((nrr-ref? ref)
        (if *current-backend*
            (nrr-get ref)
            (begin
              (init-nrr 'file "repo/")
              (nrr-get ref))))
       ((git-ref? ref)
        (if (git-available?)
            (git-cat-file ref)
            (error "nrr-get-unified: Git reference but Git not available" ref)))
       (else
        (error "nrr-get-unified: unknown reference format" ref)))))

;; ============================================================
;; End of Compatibility Layer
;; ============================================================

