;; ============================================================
;; BICF Module Loader
;; Dynamic module loading for BICF system components
;; ============================================================

;; Module registry
(define *module-registry* '())

;; Register a module
(define (register-module name path)
  (set! *module-registry*
        (cons (cons name path) *module-registry*)))

;; Load a module by name
(define (load-module name)
  (let ((module-path (assoc name *module-registry*)))
    (if module-path
        (load (cdr module-path))
        (error "Module not found" name))))

;; Initialize module registry with standard modules
(define (init-module-registry)
  (register-module 'bicf-core "../core/bicf-core.scm")
  (register-module 'fano-checker "../fano/fano-checker.scm")
  (register-module 'pcg-validator "../consensus/pcg-validator.scm")
  (register-module 'canvasl-interpreter "../canvasl/interpreter.scm"))

;; Load all core modules
(define (load-all-modules)
  (init-module-registry)
  (load-module 'bicf-core)
  (load-module 'fano-checker)
  (load-module 'pcg-validator)
  (load-module 'canvasl-interpreter))

