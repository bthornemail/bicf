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
  (register-module 'canvasl-interpreter "../canvasl/interpreter.scm")
  ;; AAL modules
  (register-module 'aal-polynomials "../aal/polynomials.scm")
  (register-module 'aal-ast "../aal/ast.scm")
  (register-module 'aal-parser "../aal/parser.scm")
  (register-module 'aal-types "../aal/types.scm")
  (register-module 'aal-well-formed "../aal/well-formed.scm")
  (register-module 'aal-semantics "../aal/semantics.scm")
  (register-module 'aal-geometry "../aal/geometry.scm")
  (register-module 'aal-compiler "../aal/compiler.scm")
  (register-module 'aal-interpreter "../aal/interpreter.scm")
  (register-module 'bicf-to-aal "bicf-to-aal.scm"))

;; Load all core modules
(define (load-all-modules)
  (init-module-registry)
  (load-module 'bicf-core)
  (load-module 'fano-checker)
  (load-module 'pcg-validator)
  (load-module 'canvasl-interpreter)
  ;; Load AAL modules (optional - only if needed)
  ;; (load-module 'aal-polynomials)
  ;; (load-module 'aal-compiler)
  ;; (load-module 'bicf-to-aal)
  )

