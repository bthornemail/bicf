;; ============================================================
;; NRR Append-Only Log (R5RS Scheme)
;; Binary log format with CanvasL compatibility
;; ============================================================

(load "hash.scm")
(load "storage.scm")
(load "log-entry.scm")

;; -----------------------------
;; Log Storage
;; -----------------------------

;; Log entries stored in memory (for now)
;; In file backend, would use log.bin file
(define *log-entries* '())

;; -----------------------------
;; Log Operations
;; -----------------------------

;; nrr-append: Append log entry
(define (nrr-append entry)
  (if (not (log-entry? entry))
      (error "nrr-append: expected LogEntry" entry)
      (begin
        ;; Store entry content via NRR storage
        (let ((entry-content (serialize-log-entry entry))
              (entry-ref (nrr-put entry-content)))
          ;; Append to log
          (set! *log-entries* (append *log-entries* (list entry)))
          #t))))

;; nrr-log: Retrieve all log entries
(define (nrr-log)
  (reverse *log-entries*))

;; nrr-log-clear: Clear log (for testing)
(define (nrr-log-clear)
  (set! *log-entries* '()))

;; nrr-log-size: Get number of log entries
(define (nrr-log-size)
  (length *log-entries*))

;; -----------------------------
;; Log Filtering
;; -----------------------------

;; nrr-log-by-phase: Get log entries for specific phase
(define (nrr-log-by-phase phase)
  (if (not (integer? phase))
      (error "nrr-log-by-phase: expected integer" phase)
      (filter (lambda (entry)
                (= (log-entry-phase entry) phase))
              (nrr-log))))

;; nrr-log-by-type: Get log entries of specific type
(define (nrr-log-by-type type)
  (if (not (log-entry-type? type))
      (error "nrr-log-by-type: expected log entry type" type)
      (filter (lambda (entry)
                (eq? (log-entry-type entry) type))
              (nrr-log))))

;; Helper: filter
(define (filter pred lst)
  (if (null? lst)
      '()
      (if (pred (car lst))
          (cons (car lst) (filter pred (cdr lst)))
          (filter pred (cdr lst)))))

;; -----------------------------
;; Log Persistence
;; -----------------------------

;; save-log: Save log to persistent storage
(define (save-log log-path)
  (if (not (string? log-path))
      (error "save-log: expected string path" log-path)
      (let ((port (open-output-file log-path)))
        (if port
            (begin
              (let loop ((entries *log-entries*))
                (if (not (null? entries))
                    (begin
                      (display (serialize-log-entry (car entries)) port)
                      (loop (cdr entries)))))
              (close-output-port port)
              #t)
            (error "save-log: cannot open file" log-path)))))

;; load-log: Load log from persistent storage
(define (load-log log-path)
  (if (not (string? log-path))
      (error "load-log: expected string path" log-path)
      (let ((port (open-input-file log-path)))
        (if port
            (let loop ((entries '())
                       (line (read-line port)))
              (if (eof-object? line)
                  (begin
                    (close-input-port port)
                    (set! *log-entries* (reverse entries))
                    #t)
                  (if (and (string? line) (> (string-length line) 0))
                      (let ((entry (deserialize-log-entry line)))
                        (loop (cons entry entries) (read-line port)))
                      (loop entries (read-line port)))))
            (error "load-log: cannot open file" log-path)))))

;; Helper: read-line
(define (read-line port)
  (let loop ((chars '())
             (ch (read-char port)))
    (if (eof-object? ch)
        (if (null? chars)
            (eof-object)
            (list->string (reverse chars)))
        (if (char=? ch #\newline)
            (list->string (reverse chars))
            (loop (cons ch chars) (read-char port))))))

;; ============================================================
;; End of Append-Only Log
;; ============================================================

