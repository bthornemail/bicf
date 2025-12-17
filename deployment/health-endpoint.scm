;; ============================================================
;; BICF Health Endpoint (R5RS Scheme)
;; Health monitoring endpoint for production
;; ============================================================

(load "../src/integration/bicf-system.scm")

;; Health check response
(define (health-check)
  (let ((status 'ok)
        (timestamp (current-time))
        (components '()))
    ;; Check core components
    (let ((core-status (if (defined? 'boundary?)
                          'healthy
                          'unavailable)))
      (set! components (cons (cons 'core core-status) components)))
    
    ;; Check AAL module
    (let ((aal-status (if (defined? 'program?)
                         'healthy
                         'unavailable)))
      (set! components (cons (cons 'aal aal-status) components)))
    
    ;; Check NRR module
    (let ((nrr-status (if (defined? 'nrr-get)
                         'healthy
                         'unavailable)))
      (set! components (cons (cons 'nrr nrr-status) components)))
    
    ;; Overall status
    (let ((overall (if (and (eq? core-status 'healthy)
                            (eq? aal-status 'healthy))
                      'healthy
                      'degraded)))
      `((status . ,overall)
        (timestamp . ,timestamp)
        (components . ,components)))))

;; Metrics endpoint
(define (metrics)
  (let ((metrics '()))
    ;; Add custom metrics here
    (cons '(bicf_requests_total 0)
          (cons '(bicf_errors_total 0)
                metrics))))

;; Helper: current-time (simplified)
(define (current-time)
  (if (defined? 'get-time-of-day)
      (get-time-of-day)
      "unknown"))

;; Helper: defined?
(define (defined? sym)
  (let ((result (catch #t
                     (lambda () (eval sym))
                     (lambda (key . args) #f))))
    (not (eq? result #f))))

;; ============================================================
;; End of Health Endpoint
;; ============================================================

