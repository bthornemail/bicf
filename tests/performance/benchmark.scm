;; Performance benchmarks for BICF Production System
;; Benchmarks: AAL compiler, assembly generation, memory usage

(load "../../src/aal/compiler.scm")
(load "../../src/aal/ast.scm")
(load "../../src/aal/polynomials.scm")
(load "../../src/aal/assembly-generator.scm")

;; Test helper
(define (test name test-fn)
  (display "Benchmarking: ")
  (display name)
  (display "... ")
  (let ((start-time (current-time))
        (result (test-fn))
        (end-time (current-time)))
    (let ((duration (- end-time start-time)))
      (display "Time: ")
      (display duration)
      (display "ms\n")
      result)))

;; Helper: current-time (simplified)
(define (current-time)
  (if (defined? 'get-time-of-day)
      (get-time-of-day)
      0))

;; Helper: defined?
(define (defined? sym)
  (let ((result (catch #t
                     (lambda () (eval sym))
                     (lambda (key . args) #f))))
    (not (eq? result #f))))

;; Benchmark: AAL Compiler
(define (benchmark-aal-compiler)
  ;; Keep this minimal and known-good for the current parser/compiler.
  (let ((program "MOV R0, R1\n"))
    (let ((result (compile program)))
      ;; MVP compiler returns (CompiledProgram ast types)
      (and (list? result) (eq? (car result) 'CompiledProgram)))))

;; Benchmark: Assembly Generation
(define (benchmark-assembly-gen)
  (let ((program (list (make-instr 'MOV (list (make-oreg 'R0) (make-oimm '(#t))))
                       (make-instr 'ADD (list (make-oreg 'R0) (make-oimm '(#t))))
                       (make-instr 'HLT '()))))
    (let ((aal-prog (make-program program '())))
      (let ((assembly (generate-assembly-from-aal aal-prog 'generic)))
        (string? assembly)))))

;; Benchmark: Polynomial Operations
(define (benchmark-polynomials)
  (let ((p '(#t #f #t #f #t))
        (q '(#f #t #f #t #f)))
    (let ((result (poly-mul (poly-add p q) (poly-gcd p q))))
      (list? result))))

;; Benchmark: Memory Usage (simplified)
(define (benchmark-memory)
  ;; Create large program
  (let loop ((i 0)
             (instrs '()))
    (if (< i 100)
        (loop (+ i 1)
              (cons (make-instr 'NOP '()) instrs))
        (let ((prog (make-program (reverse instrs) '())))
          (program? prog)))))

;; Run all benchmarks
(define (run-benchmarks)
  (display "Running performance benchmarks...\n")
  (display "====================================\n")
  (test "AAL Compiler" benchmark-aal-compiler)
  (test "Assembly Generation" benchmark-assembly-gen)
  (test "Polynomial Operations" benchmark-polynomials)
  (test "Memory Usage" benchmark-memory)
  (display "====================================\n")
  (display "Benchmarks completed.\n"))

;; Execute if run directly
(if (not (null? (command-line)))
    (run-benchmarks))

