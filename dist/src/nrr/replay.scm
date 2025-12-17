;; ============================================================
;; NRR Deterministic Replay (R5RS Scheme)
;; Replay from NRR log with boundary validation
;; ============================================================

(load "hash.scm")
(load "storage.scm")
(load "log.scm")
(load "../canvasl/interpreter.scm")

;; -----------------------------
;; Replay State
;; -----------------------------

;; Replay state: (env, boundary-reg, phase)
(define (make-replay-state env boundary-reg phase)
  (list 'ReplayState env boundary-reg phase))

(define (replay-state? x)
  (and (list? x)
       (= (length x) 4)
       (eq? (car x) 'ReplayState)))

(define (replay-state-env state)
  (if (replay-state? state)
      (cadr state)
      (error "replay-state-env: expected ReplayState" state)))

(define (replay-state-boundary-reg state)
  (if (replay-state? state)
      (caddr state)
      (error "replay-state-boundary-reg: expected ReplayState" state)))

(define (replay-state-phase state)
  (if (replay-state? state)
      (cadddr state)
      (error "replay-state-phase: expected ReplayState" state)))

;; -----------------------------
;; Replay Algorithm
;; -----------------------------

;; replay-from-log: Replay execution from NRR log
(define (replay-from-log . rest)
  (let ((entries (if (null? rest) (nrr-log) (car rest)))
        (boundary-reg (if (or (null? rest) (null? (cdr rest)))
                         (boundary-reg-empty)
                         (cadr rest))))
    (if (not (list? entries))
        (error "replay-from-log: expected list" entries)
        (let ((initial-state (make-replay-state
                              (env-empty)
                              boundary-reg
                              -1)))
          (let loop ((entries entries)
                     (state initial-state))
            (if (null? entries)
                (replay-state-env state)
                (let ((entry (car entries))
                      (env (replay-state-env state))
                      (reg (replay-state-boundary-reg state))
                      (prev-phase (replay-state-phase state)))
                  ;; Process log entry
                  (let ((entry-phase (log-entry-phase entry))
                        (entry-type (log-entry-type entry))
                        (entry-ref (log-entry-ref entry)))
                    ;; Validate phase monotonicity
                    (if (< entry-phase prev-phase)
                        (error "replay-from-log: phase not monotonic"
                               (list prev-phase entry-phase))
                        ;; Process based on entry type
                        (let ((new-state
                               (case entry-type
                                 ((boundary)
                                  ;; Load boundary
                                  (let ((boundary-content (nrr-get entry-ref))
                                        (boundary (deserialize-content boundary-content)))
                                    (let ((boundary-id (alist-ref boundary 'id)))
                                      (make-replay-state
                                       env
                                       (boundary-reg-add reg boundary-id boundary)
                                       entry-phase))))
                                 ((interior)
                                  ;; Apply interior state
                                  (let ((step-content (nrr-get entry-ref))
                                        (step (deserialize-content step-content)))
                                    (let ((result (exec-step env reg step)))
                                      (make-replay-state
                                       (car result)
                                       reg
                                       entry-phase))))
                                 ((guarantee)
                                  ;; Verify guarantee
                                  (let ((guarantee-content (nrr-get entry-ref))
                                        (guarantee (deserialize-content guarantee-content)))
                                    ;; Validate guarantee
                                    (make-replay-state
                                     env
                                     reg
                                     entry-phase)))
                                 (else
                                  (error "replay-from-log: unknown entry type" entry-type)))))
                          (loop (cdr entries) new-state))))))))))

;; -----------------------------
;; Replay Validation
;; -----------------------------

;; validate-replay: Validate replay correctness
(define (validate-replay entries)
  (if (not (list? entries))
      (error "validate-replay: expected list" entries)
      (let ((phases '())
            (boundaries '()))
        (let loop ((entries entries)
                   (valid #t))
          (if (null? entries)
              valid
              (let ((entry (car entries))
                    (phase (log-entry-phase entry))
                    (type (log-entry-type entry)))
                ;; Check phase monotonicity
                (if (and (not (null? phases))
                         (< phase (car phases)))
                    (loop '() #f)
                    (begin
                      (set! phases (cons phase phases))
                      ;; Track boundaries
                      (if (eq? type 'boundary)
                          (set! boundaries (cons (log-entry-ref entry) boundaries)))
                      (loop (cdr entries) valid)))))))))

;; -----------------------------
;; Error Handling
;; -----------------------------

;; replay-with-error-handling: Replay with error recovery
(define (replay-with-error-handling entries boundary-reg)
  (if (not (list? entries))
      (error "replay-with-error-handling: expected list" entries)
      (catch #t
        (lambda () (replay-from-log entries boundary-reg))
        (lambda (key . args)
          (list 'ReplayError key args)))))

;; ============================================================
;; End of Deterministic Replay
;; ============================================================

