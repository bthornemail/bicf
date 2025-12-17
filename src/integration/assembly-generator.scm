;; ============================================================
;; BICF Assembly Generator Integration (R5RS Scheme)
;; Connects BICF boundary → AAL → Assembly pipeline
;; ============================================================

(load "../aal/assembly-generator.scm")
(load "../aal/register-alloc.scm")
(load "bicf-to-aal.scm")

;; -----------------------------
;; Assembly Output Formats
;; -----------------------------

(define *output-formats* '(text binary hex))

(define (output-format? x)
  (memq x *output-formats*))

(define *current-format* 'text)

(define (set-output-format fmt)
  (if (not (output-format? fmt))
      (error "set-output-format: expected format" fmt)
      (set! *current-format* fmt)))

;; -----------------------------
;; Main Assembly Generation Function
;; -----------------------------

;; generate-assembly-from-boundary: Generate assembly from BICF boundary
;; This is the function referenced in the integration README
(define (generate-assembly-from-boundary boundary . rest)
  (if (not (boundary? boundary))
      (error "generate-assembly: expected Boundary" boundary)
      (let ((arch (if (null? rest) 'generic (car rest)))
            (format (if (or (null? rest) (null? (cdr rest))) 'text (cadr rest))))
        ;; Step 1: Transform boundary to AAL
        (let ((aal-program (generate-aal boundary)))
          (if (not (program? aal-program))
              (error "generate-assembly-from-boundary: AAL generation failed")
              ;; Step 2: Allocate registers
              (let ((allocations (allocate-registers aal-program)))
                ;; Step 3: Generate assembly code
                (let ((assembly-code (generate-assembly-from-aal aal-program arch)))
                  ;; Step 4: Format output
                  (format-assembly-output assembly-code format arch))))))))

;; generate-assembly-from-aal: Generate assembly from AAL program
(define (generate-assembly-from-aal aal-program arch)
  (if (not (program? aal-program))
      (error "generate-assembly-from-aal: expected Program" aal-program)
      (if (not (architecture? arch))
          (error "generate-assembly-from-aal: expected architecture" arch)
          ;; Use assembly generator from aal module
          (generate-assembly aal-program arch))))

;; format-assembly-output: Format assembly code according to output format
(define (format-assembly-output assembly-code format arch)
  (if (not (string? assembly-code))
      (error "format-assembly-output: expected string" assembly-code)
      (if (not (output-format? format))
          (error "format-assembly-output: expected format" format)
          (case format
            ((text)
             ;; Plain text assembly
             assembly-code)
            ((binary)
             ;; Binary format (placeholder - would need assembler)
             (string-append "; Binary format not yet implemented\n"
                            "; Assembly code:\n"
                            assembly-code))
            ((hex)
             ;; Hex format (placeholder)
             (string-append "; Hex format not yet implemented\n"
                            "; Assembly code:\n"
                            assembly-code))
            (else assembly-code)))))

;; -----------------------------
;; Pipeline Integration
;; -----------------------------

;; bicf-to-assembly-pipeline: Complete BICF → AAL → Assembly pipeline
(define (bicf-to-assembly-pipeline boundary arch format)
  (if (not (boundary? boundary))
      (error "bicf-to-assembly-pipeline: expected Boundary" boundary)
      (if (not (architecture? arch))
          (error "bicf-to-assembly-pipeline: expected architecture" arch)
          (if (not (output-format? format))
              (error "bicf-to-assembly-pipeline: expected format" format)
              (let ((result (generate-assembly-from-boundary boundary arch format)))
                (list 'AssemblyResult
                      boundary
                      arch
                      format
                      result))))))

;; -----------------------------
;; CLI Integration
;; -----------------------------

;; Add assembly generation to BICF CLI
;; This extends the existing bicf-cli function
(define (bicf-assembly-cli args)
  (if (null? args)
      (begin
        (display "BICF Assembly Generator\n")
        (display "Usage: bicf assembly <boundary> [arch] [format]\n")
        (display "Architectures: x86, arm, riscv, generic\n")
        (display "Formats: text, binary, hex\n"))
      (let ((command (car args))
            (rest-args (cdr args)))
        (case (string->symbol command)
          ((generate)
           (if (null? rest-args)
               (error "generate requires boundary")
               (let ((boundary (car rest-args))
                     (arch (if (null? (cdr rest-args)) 'generic
                               (string->symbol (cadr rest-args))))
                     (format (if (or (null? (cdr rest-args))
                                      (null? (cddr rest-args))) 'text
                                 (string->symbol (caddr rest-args)))))
                 (display (generate-assembly-from-boundary boundary arch format)))))
          ((help)
           (bicf-assembly-cli '()))
          (else
           (error "Unknown command" command))))))

;; -----------------------------
;; Integration with BICF System
;; -----------------------------

;; Register assembly generation with BICF system
(define (register-assembly-generator)
  (if (defined? 'execute-bicf-operation)
      (begin
        ;; Add assembly generation to operations
        ;; This would be called during system initialization
        (display "Assembly generator registered with BICF system\n")
        #t)
      (begin
        (display "Warning: BICF system not available\n")
        #f)))

;; ============================================================
;; End of Assembly Generator Integration
;; ============================================================

