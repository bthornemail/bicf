;; ============================================================
;; NRR Git Adapter (R5RS Scheme)
;; Bidirectional conversion between Git and NRR
;; Optional backward compatibility layer
;; ============================================================

(load "storage.scm")
(load "hash.scm")

;; -----------------------------
;; Git Detection
;; -----------------------------

;; git-available?: Check if Git is available
(define (git-available?)
  (let ((result (catch #t
                     (lambda ()
                       ;; Try to run git command
                       (system "git --version > /dev/null 2>&1")
                       #t)
                     (lambda (key . args) #f))))
    result))

;; git-repo?: Check if current directory is a Git repository
(define (git-repo?)
  (let ((result (catch #t
                     (lambda ()
                       (system "test -d .git")
                       #t)
                     (lambda (key . args) #f))))
    result))

;; -----------------------------
;; Git Operations
;; -----------------------------

;; git-hash-object: Git hash-object equivalent
(define (git-hash-object content)
  (if (not (string? content))
      (error "git-hash-object: expected string" content)
      (if (not (git-available?))
          (error "git-hash-object: Git not available")
          (let ((result (catch #t
                             (lambda ()
                               ;; Use git hash-object
                               (let ((port (open-input-pipe
                                            (string-append "echo '" content "' | git hash-object --stdin"))))
                                 (if port
                                     (let ((hash (read-line port)))
                                       (close-input-port port)
                                       (if (string? hash)
                                           (string-trim hash)
                                           #f))
                                     #f)))
                             (lambda (key . args) #f))))
            result))))

;; git-cat-file: Git cat-file equivalent
(define (git-cat-file ref)
  (if (not (string? ref))
      (error "git-cat-file: expected string reference" ref)
      (if (not (git-available?))
          (error "git-cat-file: Git not available")
          (let ((hash (if (git-ref? ref)
                         (substring ref 7)  ;; Skip "commit:" prefix
                         ref)))
            (let ((result (catch #t
                               (lambda ()
                                 (let ((port (open-input-pipe
                                              (string-append "git cat-file -p " hash))))
                                   (if port
                                       (let ((content (read-string port)))
                                         (close-input-port port)
                                         content)
                                       #f)))
                               (lambda (key . args) #f))))
              result)))))

;; git-log: Get Git commit history
(define (git-log)
  (if (not (git-available?))
      (error "git-log: Git not available")
      (let ((result (catch #t
                         (lambda ()
                           (let ((port (open-input-pipe "git log --oneline --all")))
                             (if port
                                 (let loop ((commits '())
                                            (line (read-line port)))
                                   (if (eof-object? line)
                                       (begin
                                         (close-input-port port)
                                         (reverse commits))
                                       (loop (cons line commits) (read-line port))))
                                 '())))
                         (lambda (key . args) '()))))
        result)))

;; -----------------------------
;; NRR-Git Conversion
;; -----------------------------

;; nrr-to-git: Convert NRR reference to Git
(define (nrr-to-git nrr-ref content)
  (if (not (nrr-ref? nrr-ref))
      (error "nrr-to-git: expected NRR reference" nrr-ref)
      (if (not (string? content))
          (error "nrr-to-git: expected string content" content)
          (let ((git-hash (git-hash-object content)))
            (if git-hash
                (string-append "commit:" git-hash)
                (error "nrr-to-git: failed to create Git object"))))))

;; git-to-nrr: Convert Git reference to NRR
(define (git-to-nrr git-ref)
  (if (not (git-ref? git-ref))
      (error "git-to-nrr: expected Git reference" git-ref)
      (let ((content (git-cat-file git-ref)))
        (if content
            (let ((nrr-ref (nrr-put content)))
              nrr-ref
              (error "git-to-nrr: failed to store in NRR"))))))

;; -----------------------------
;; Git Adapter Backend
;; -----------------------------

;; make-git-backend: Create Git adapter storage backend
(define (make-git-backend)
  (if (not (git-available?))
      (error "make-git-backend: Git not available")
      (make-storage-backend
       'git
       (lambda (content)
         (let ((git-hash (git-hash-object content)))
           (if git-hash
               (string-append "commit:" git-hash)
               (error "git-backend-put: failed"))))
       (lambda (ref)
         (if (git-ref? ref)
             (git-cat-file ref)
             (error "git-backend-get: expected Git reference" ref))))))

;; -----------------------------
;; Compatibility Layer
;; -----------------------------

;; auto-select-backend: Automatically select NRR or Git backend
(define (auto-select-backend repo-path)
  (if (git-repo?)
      (begin
        (display "Using Git backend\n")
        (make-git-backend))
      (begin
        (display "Using NRR file backend\n")
        (init-nrr 'file repo-path)
        (get-storage-backend))))

;; Helper: string-trim
(define (string-trim str)
  (if (not (string? str))
      (error "string-trim: expected string" str)
      (let ((len (string-length str)))
        (let loop ((start 0)
                   (end len))
          (if (and (< start len)
                   (char-whitespace? (string-ref str start)))
              (loop (+ start 1) end)
              (if (and (> end start)
                       (char-whitespace? (string-ref str (- end 1))))
                  (loop start (- end 1))
                  (substring str start end)))))))

(define (char-whitespace? ch)
  (or (char=? ch #\space)
      (char=? ch #\tab)
      (char=? ch #\newline)))

;; Helper: system (if not available)
(define (system command)
  ;; Placeholder - would use system call in production
  #f)

;; Helper: open-input-pipe (if not available)
(define (open-input-pipe command)
  ;; Placeholder - would use pipe in production
  #f)

;; ============================================================
;; End of Git Adapter
;; ============================================================

