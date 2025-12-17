;; ============================================================
;; BICF System Coordination
;; Main system entry point and coordination
;; ============================================================

(load "module-loader.scm")

;; Load AAL integration (if available)
(let ((load-result (catch #t
                        (lambda () (load "bicf-to-aal.scm") #t)
                        (lambda (key . args) #f))))
  (if (not load-result)
      (display "Note: AAL integration not loaded\n")))

;; Load NRR integration (if available)
(let ((load-result (catch #t
                        (lambda ()
                          (load "../nrr/storage.scm")
                          (load "../nrr/log.scm")
                          #t)
                        (lambda (key . args) #f))))
  (if (not load-result)
      (display "Note: NRR integration not loaded\n"))))

;; Initialize system
(define (init-bicf-system)
  (display "Initializing BICF System...\n")
  (load-all-modules)
  (display "BICF System initialized.\n"))

;; System state
(define *boundary-registry* '())
(define *initialized* #f)

;; Register a boundary
(define (register-boundary boundary)
  (if (not *initialized*)
      (init-bicf-system))
  (let ((boundary-id (cdr (assq 'id boundary))))
    (set! *boundary-registry*
          (cons (cons boundary-id boundary) *boundary-registry*))
    boundary-id))

;; Get boundary by ID
(define (get-boundary boundary-id)
  (let ((boundary (assoc boundary-id *boundary-registry*)))
    (if boundary
        (cdr boundary)
        (error "Boundary not found" boundary-id))))

;; Execute BICF operation
(define (execute-bicf-operation op . args)
  (if (not *initialized*)
      (init-bicf-system))
  (case op
    ((register-boundary) (apply register-boundary args))
    ((get-boundary) (apply get-boundary args))
    ((realize) (apply realize args))
    ((transform) (apply transform args))
    ((project) (apply project args))
    ((valid?) (apply valid? args))
    ((generate-aal) (apply bicf-generate-aal args))
    (else (error "Unknown operation" op))))

;; generate-aal: Generate AAL program from boundary
;; This ensures bicf-to-aal.scm is loaded and calls its generate-aal function
(define (bicf-generate-aal boundary)
  (if (not *initialized*)
      (init-bicf-system))
  ;; Load bicf-to-aal if not already loaded
  (if (not (defined? 'boundary-to-aal))
      (let ((load-result (catch #t
                              (lambda () (load "bicf-to-aal.scm") #t)
                              (lambda (key . args) #f))))
        (if (not load-result)
            (error "bicf-generate-aal: failed to load AAL integration"))))
  ;; Now call generate-aal from bicf-to-aal.scm
  (if (defined? 'generate-aal)
      (generate-aal boundary)
      (error "bicf-generate-aal: generate-aal function not available")))

;; Helper: check if symbol is defined
(define (defined? sym)
  (let ((result (catch #t
                     (lambda () (eval sym))
                     (lambda (key . args) #f))))
    (not (eq? result #f))))

;; CLI interface helper
(define (bicf-cli args)
  (if (null? args)
      (begin
        (display "BICF System CLI\n")
        (display "Usage: bicf <command> [args...]\n")
        (display "Commands: help, init, register, get, realize, transform, project, valid\n"))
      (let ((command (car args))
            (rest-args (cdr args)))
        (case (string->symbol command)
          ((help) (bicf-cli '()))
          ((init) (init-bicf-system))
          ((register) (if (null? rest-args)
                         (error "register requires boundary")
                         (display (register-boundary (car rest-args)))))
          ((get) (if (null? rest-args)
                    (error "get requires boundary-id")
                    (display (get-boundary (car rest-args)))))
          ((generate-aal) (if (null? rest-args)
                             (error "generate-aal requires boundary")
                             (let ((boundary (car rest-args)))
                               (display (bicf-generate-aal boundary)))))
          (else (error "Unknown command" command))))))

