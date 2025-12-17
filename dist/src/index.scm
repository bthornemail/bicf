;; ============================================================
;; BICF Production System - Main Entry Point
;; ============================================================

(load "integration/bicf-system.scm")

;; Initialize system on load
(init-bicf-system)

;; Export main CLI function
(define (main args)
  (bicf-cli args))

;; If run as script, execute CLI
(if (not (null? (command-line)))
    (main (cdr (command-line))))

