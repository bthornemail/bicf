;; ============================================================
;; CanvasL NRR Execution Logging (R5RS Scheme)
;; Log CanvasL steps via NRR append-only log
;; ============================================================

(load "../nrr/hash.scm")
(load "../nrr/storage.scm")
(load "../nrr/log.scm")

;; Helper: alist-ref (if not available)
(define (alist-ref a k)
  (let ((p (assq k a)))
    (if p (cdr p) #f)))

;; -----------------------------
;; Step Logging
;; -----------------------------

;; log-canvasl-step: Log CanvasL execution step
(define (log-canvasl-step step phase)
  (if (not (list? step))
      (error "log-canvasl-step: expected list" step)
      (if (not (integer? phase))
          (error "log-canvasl-step: expected integer phase" phase)
          (let ((step-content (serialize-content step))
                (step-ref (nrr-put step-content))
                (step-type (alist-ref step 'type)))
            ;; Determine log entry type
            (let ((entry-type
                   (cond
                    ((equal? step-type "boundary") 'boundary)
                    ((equal? step-type "interior") 'interior)
                    ((equal? step-type "guarantee") 'guarantee)
                    (else 'interior))))  ;; Default to interior
              ;; Create and append log entry
              (let ((entry (make-log-entry phase entry-type step-ref)))
                (nrr-append entry)
                step-ref))))))

;; -----------------------------
;; Execution Trace Logging
;; -----------------------------

;; log-execution-trace: Log entire execution trace
(define (log-execution-trace steps boundary-reg)
  (if (not (list? steps))
      (error "log-execution-trace: expected list" steps)
      (let loop ((steps steps)
                 (phase 0))
        (if (null? steps)
            #t
            (let ((step (car steps)))
              (let ((step-phase (alist-ref step 'phase)))
                (log-canvasl-step step (if step-phase step-phase phase))
                (loop (cdr steps) (+ phase 1))))))))

;; -----------------------------
;; Log Replay Support
;; -----------------------------

;; get-step-from-log: Retrieve step content from log entry
(define (get-step-from-log entry)
  (if (not (log-entry? entry))
      (error "get-step-from-log: expected LogEntry" entry)
      (let ((ref (log-entry-ref entry)))
        (let ((content (nrr-get ref)))
          (if content
              (deserialize-content content)
              (error "get-step-from-log: content not found" ref))))))

;; -----------------------------
;; Integration with CanvasL Interpreter
;; -----------------------------

;; Enhanced run-trace: Log execution
(define (run-trace-nrr steps boundary-reg initial-env)
  (if (not (list? steps))
      (error "run-trace-nrr: expected list" steps)
      (begin
        ;; Log execution trace
        (log-execution-trace steps boundary-reg)
        ;; Run trace using original interpreter
        (run-trace steps boundary-reg initial-env))))

;; ============================================================
;; End of CanvasL NRR Logging
;; ============================================================

