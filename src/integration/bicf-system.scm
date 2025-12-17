;; ============================================================
;; BICF System Coordination
;; Main system entry point and coordination
;; ============================================================

(load "module-loader.scm")

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
    (else (error "Unknown operation" op))))

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
          (else (error "Unknown command" command))))))

