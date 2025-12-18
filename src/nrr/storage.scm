;; ============================================================
;; NRR Storage Interface (R5RS Scheme)
;; Storage backend abstraction
;; ============================================================

;; Load helpers relative to this file so tools can load `src/nrr/storage.scm`
;; from any working directory deterministically.
(define (nrr-dirname path)
  (if (not (string? path))
      (error "nrr-dirname: expected string" path)
      (let loop ((i (- (string-length path) 1)))
        (if (< i 0)
            "."
            (if (char=? (string-ref path i) #\/)
                (if (= i 0) "/" (substring path 0 i))
                (loop (- i 1)))))))

(define (nrr-load-relative rel)
  (load (string-append *nrr-base-dir* "/" rel)))

(define *nrr-base-dir*
  (let ((cf (current-filename)))
    (if (and cf (string? cf))
        (nrr-dirname cf)
        (getcwd))))

(nrr-load-relative "hash.scm")

;; -----------------------------
;; Storage Backend Interface
;; -----------------------------

;; Storage backend: (type, put-fn, get-fn)
(define (make-storage-backend type put-fn get-fn)
  (list 'StorageBackend type put-fn get-fn))

(define (storage-backend? x)
  (and (list? x)
       (= (length x) 4)
       (eq? (car x) 'StorageBackend)))

(define (storage-backend-type backend)
  (if (storage-backend? backend)
      (cadr backend)
      (error "storage-backend-type: expected StorageBackend" backend)))

(define (storage-backend-put backend)
  (if (storage-backend? backend)
      (caddr backend)
      (error "storage-backend-put: expected StorageBackend" backend)))

(define (storage-backend-get backend)
  (if (storage-backend? backend)
      (cadddr backend)
      (error "storage-backend-get: expected StorageBackend" backend)))

;; Current storage backend
(define *current-backend* #f)

;; -----------------------------
;; Storage Operations
;; -----------------------------

;; nrr-put: Store content, return reference
(define (nrr-put content)
  (if (not *current-backend*)
      (error "nrr-put: storage backend not initialized")
      (let ((put-fn (storage-backend-put *current-backend*)))
        (if (not (procedure? put-fn))
            (error "nrr-put: invalid put function")
            (put-fn content)))))

;; nrr-get: Retrieve content by reference
(define (nrr-get ref)
  (if (not (string? ref))
      (error "nrr-get: expected string reference" ref)
      (if (not *current-backend*)
          (error "nrr-get: storage backend not initialized")
          (let ((get-fn (storage-backend-get *current-backend*)))
            (if (not (procedure? get-fn))
                (error "nrr-get: invalid get function")
                (get-fn ref))))))

;; -----------------------------
;; Backend Management
;; -----------------------------

;; set-storage-backend: Set current storage backend
(define (set-storage-backend backend)
  (if (not (storage-backend? backend))
      (error "set-storage-backend: expected StorageBackend" backend)
      (set! *current-backend* backend)))

;; get-storage-backend: Get current storage backend
(define (get-storage-backend)
  *current-backend*)

;; Helper: check if symbol is defined
(define (defined? sym)
  (let ((result (catch #t
                     (lambda () (eval sym))
                     (lambda (key . args) #f))))
    (not (eq? result #f))))

;; init-nrr: Initialize NRR with storage backend
(define (init-nrr backend-type . args)
  (if (not (symbol? backend-type))
      (error "init-nrr: expected symbol" backend-type)
      (case backend-type
        ((file)
         (if (null? args)
             (error "init-nrr: file backend requires path")
             (let ((path (car args)))
               (nrr-load-relative "storage-file.scm")
               (catch #t
                 (lambda ()
                   (set-storage-backend (make-file-backend path)))
                 (lambda (key . args2)
                   (error "init-nrr: file backend not available"))))))
        ((memory)
         (nrr-load-relative "storage-memory.scm")
         (catch #t
           (lambda () (set-storage-backend (make-memory-backend)))
           (lambda (key . args2)
             (error "init-nrr: memory backend not available"))))
        ((embedded)
         (nrr-load-relative "storage-embedded.scm")
         (catch #t
           (lambda () (set-storage-backend (make-embedded-backend)))
           (lambda (key . args2)
             (error "init-nrr: embedded backend not available"))))
        (else
         (error "init-nrr: unknown backend type" backend-type)))))

;; -----------------------------
;; Content Serialization
;; -----------------------------

;; serialize-content: Serialize content for storage
(define (serialize-content content)
  (cond
   ((string? content) content)
   ((list? content)
    ;; Serialize alist or list to string
    (content-to-string content))
   (else
    (error "serialize-content: unsupported content type" content))))

;; content-to-string: Convert content to string representation
(define (content-to-string content)
  (if (list? content)
      (let loop ((items content)
                 (result "("))
        (if (null? items)
            (string-append result ")")
            (let ((item (car items)))
              (if (pair? item)
                  ;; Alist entry
                  (loop (cdr items)
                        (string-append result
                                       "(" (content-to-string (car item))
                                       " . " (content-to-string (cdr item)) ") "))
                  ;; List element
                  (loop (cdr items)
                        (string-append result
                                       (content-to-string item) " "))))))
      (if (string? content)
          (string-append "\"" content "\"")
          (if (number? content)
              (number->string content)
              (if (symbol? content)
                  (symbol->string content)
                  (if (boolean? content)
                      (if content "#t" "#f")
                      ""))))))

;; deserialize-content: Deserialize content from storage
(define (deserialize-content content-str)
  (if (not (string? content-str))
      (error "deserialize-content: expected string" content-str)
      ;; For now, return as string
      ;; In full implementation, would parse back to original format
      content-str))

;; ============================================================
;; End of Storage Interface
;; ============================================================
