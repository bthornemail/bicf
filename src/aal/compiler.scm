;; ============================================================
;; AAL Compiler (R5RS Scheme)
;; Main compiler entry point and pipeline
;; ============================================================

(load "parser.scm")
(load "well-formed.scm")
(load "types.scm")
(load "semantics.scm")

;; -----------------------------
;; Compiler Pipeline
;; -----------------------------

;; compile: Complete compilation pipeline
;; Returns: compiled program or error
(define (compile input)
  (if (not (string? input))
      (error "compile: expected string" input)
      (let ((parse-result (parse-aal input)))
        (if (not parse-result)
            (error "compile: parse error")
            (let ((wf-result (wf-program parse-result)))
              (if (not wf-result)
                  (error "compile: well-formedness check failed")
                  (let ((type-result (typed-program parse-result)))
                    (if (not type-result)
                        (error "compile: type checking failed")
                        ;; Return compiled program (AST + types)
                        (list 'CompiledProgram
                              parse-result
                              type-result)))))))))

;; compile-from-file: Compile from file
(define (compile-from-file filename)
  (if (not (string? filename))
      (error "compile-from-file: expected string" filename)
      (let ((port (open-input-file filename)))
        (if (not port)
            (error "compile-from-file: cannot open file" filename)
            (let ((content (read-string port)))
              (close-input-port port)
              (compile content))))))

;; Helper: read-string (if not available)
(define (read-string port)
  (let loop ((result '())
             (ch (read-char port)))
    (if (eof-object? ch)
        (list->string (reverse result))
        (loop (cons ch result) (read-char port)))))

;; -----------------------------
;; Compilation Errors
;; -----------------------------

;; compilation-error: Structured error reporting
(define (compilation-error phase message details)
  (list 'CompilationError phase message details))

(define (compilation-error? x)
  (and (list? x)
       (= (length x) 4)
       (eq? (car x) 'CompilationError)))

;; -----------------------------
;; Compiler Options
;; -----------------------------

;; Compiler configuration
(define *compiler-options*
  '((optimize . #f)
    (warnings . #t)
    (debug . #f)))

(define (set-compiler-option key value)
  (set! *compiler-options*
        (cons (cons key value)
              (remove (lambda (x) (eq? (car x) key))
                      *compiler-options*))))

(define (get-compiler-option key)
  (let ((entry (assq key *compiler-options*)))
    (if entry
        (cdr entry)
        #f)))

;; -----------------------------
;; Code Generation (Placeholder)
;; -----------------------------

;; generate-code: Generate intermediate representation
;; This will be expanded in Phase 4 (Assembly Generation)
(define (generate-code compiled-prog)
  (if (not (list? compiled-prog))
      (error "generate-code: expected compiled program" compiled-prog)
      (if (not (eq? (car compiled-prog) 'CompiledProgram))
          (error "generate-code: invalid compiled program" compiled-prog)
          (let ((ast (cadr compiled-prog))
                (types (caddr compiled-prog)))
            ;; For now, return AST as intermediate representation
            (list 'IR ast types)))))

;; ============================================================
;; End of Compiler
;; ============================================================

