;; ============================================================
;; NRR File-Based Storage Backend (R5RS Scheme)
;; Directory structure: /repo/objects/, /repo/log.bin
;; ============================================================

;; Loaded via `src/nrr/storage.scm` (avoid CWD-relative loads).

;; -----------------------------
;; File Storage Structure
;; -----------------------------

;; Directory layout:
;; /repo/
;;   objects/
;;     ab/cd/abcd1234...    # content blobs
;;   log.bin                # append-only binary log
;;   boundary.bin           # active boundary refs

;; make-file-backend: Create file-based storage backend
(define (make-file-backend repo-path)
  (if (not (string? repo-path))
      (error "make-file-backend: expected string path" repo-path)
      (begin
        ;; Ensure directory structure exists
        (ensure-repo-structure repo-path)
        (make-storage-backend
         'file
         (lambda (content) (file-put repo-path content))
         (lambda (ref) (file-get repo-path ref))))))

;; ensure-repo-structure: Create repository directory structure
(define (ensure-repo-structure repo-path)
  (if (not (string? repo-path))
      (error "ensure-repo-structure: expected string" repo-path)
      ;; Use deterministic directory creation via mkdir -p.
      ;; This keeps the backend functional on real systems while remaining deterministic.
      (begin
        (system (string-append "mkdir -p " repo-path "/objects"))
        #t)))

;; ensure-parent-dir: ensure the parent directory for a path exists
(define (ensure-parent-dir path)
  (let loop ((i (- (string-length path) 1)))
    (if (< i 0)
        #t
        (if (char=? (string-ref path i) #\/)
            (let ((dir (if (= i 0) "/" (substring path 0 i))))
              (begin
                (system (string-append "mkdir -p " dir))
                #t))
            (loop (- i 1))))))

;; file-put: Store content in file system, return reference
(define (file-put repo-path content)
  (if (not (string? repo-path))
      (error "file-put: expected string path" repo-path)
      (if (not (string? content))
          (error "file-put: expected string content" content)
          (let* ((payload (serialize-content content))
                 (ref (make-nrr-ref payload))
                 (hash (extract-hash-from-ref ref)))
            ;; Store in objects/ab/cd/abcd1234... structure
            (let ((object-path (make-object-path repo-path hash)))
              ;; Write content to file
              (ensure-parent-dir object-path)
              (write-file object-path payload)
              ref)))))

;; make-object-path: Generate object file path from hash
(define (make-object-path repo-path hash)
  (if (not (string? repo-path))
      (error "make-object-path: expected string" repo-path)
      (if (not (string? hash))
          (error "make-object-path: expected string hash" hash)
          (let* ((prefix-len (min 2 (string-length hash)))
                 (prefix (substring hash 0 prefix-len))
                 (suffix (if (> (string-length hash) 2)
                             (substring hash 2)
                             "")))
            (string-append repo-path "/objects/" prefix "/" suffix)))))

;; file-get: Retrieve content from file system by reference
(define (file-get repo-path ref)
  (if (not (string? repo-path))
      (error "file-get: expected string path" repo-path)
      (if (not (string? ref))
          (error "file-get: expected string reference" ref)
          (let* ((h (if (nrr-ref? ref)
                        (extract-hash-from-ref ref)
                        ref))
                 (object-path (make-object-path repo-path h)))
            ;; Read content from file
            (let ((content (read-file object-path)))
              (if content
                  (deserialize-content content)
                  (error "file-get: file not found" object-path)))))))

;; write-file: Write content to file
(define (write-file path content)
  (if (not (string? path))
      (error "write-file: expected string path" path)
      (if (not (string? content))
          (error "write-file: expected string content" content)
          ;; In R5RS, file writing
          (let ((port (open-output-file path)))
            (if port
                (begin
                  (display content port)
                  (close-output-port port)
                  #t)
                (error "write-file: cannot open file" path))))))

;; read-file: Read content from file
(define (read-file path)
  (if (not (string? path))
      (error "read-file: expected string path" path)
      (let ((port (open-input-file path)))
        (if port
            (let ((content (read-string port)))
              (close-input-port port)
              content)
            #f))))

;; read-string: Read entire file as string
(define (read-string port)
  (let loop ((result '())
             (ch (read-char port)))
    (if (eof-object? ch)
        (list->string (reverse result))
        (loop (cons ch result) (read-char port)))))

;; ============================================================
;; End of File-Based Storage
;; ============================================================
