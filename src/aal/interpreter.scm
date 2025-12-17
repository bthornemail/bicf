;; ============================================================
;; AAL Interpreter (R5RS Scheme)
;; Alternative interpreter mode for direct execution
;; ============================================================

(load "compiler.scm")
(load "semantics.scm")

;; -----------------------------
;; Interpreter State
;; -----------------------------

;; Initial state
(define (make-initial-state)
  (make-state
   '()  ;; Empty registers (will be initialized as needed)
   '()  ;; Empty memory
   0    ;; PC = 0
   (make-flags #f #f)))  ;; Flags: Z=false, C=false

;; -----------------------------
;; Interpreter Execution
;; -----------------------------

;; interpret: Execute AAL program
(define (interpret input)
  (if (not (string? input))
      (error "interpret: expected string" input)
      (let ((compiled (compile input)))
        (if (compilation-error? compiled)
            compiled
            (let ((prog (cadr compiled)))
              (execute prog (make-initial-state) 1000))))))  ;; Max 1000 steps

;; execute: Execute program from initial state
(define (execute prog initial-state max-steps)
  (if (not (program? prog))
      (error "execute: expected Program" prog)
      (if (not (state? initial-state))
          (error "execute: expected State" initial-state)
          (let loop ((state initial-state)
                     (steps 0))
            (if (>= steps max-steps)
                (list 'ExecutionResult 'Timeout state steps)
                (let ((pc (state-pc state))
                      (instrs (program-instrs prog)))
                  (if (>= pc (length instrs))
                      (list 'ExecutionResult 'Halted state steps)
                      (let ((instr (list-ref instrs pc)))
                        (if (eq? (instr-mnem instr) 'HLT)
                            (list 'ExecutionResult 'Halted state steps)
                            (let ((next-state (step state prog)))
                              (if (state? next-state)
                                  (loop next-state (+ steps 1))
                                  (list 'ExecutionResult 'Error next-state steps))))))))))))

;; -----------------------------
;; Step-by-Step Execution
;; -----------------------------

;; interpret-step: Execute single step
(define (interpret-step state prog)
  (if (not (state? state))
      (error "interpret-step: expected State" state)
      (if (not (program? prog))
          (error "interpret-step: expected Program" prog)
          (step state prog))))

;; -----------------------------
;; Debugging Support
;; -----------------------------

;; print-state: Pretty print state
(define (print-state state)
  (if (not (state? state))
      (error "print-state: expected State" state)
      (begin
        (display "=== AAL State ===\n")
        (display "PC: ")
        (display (state-pc state))
        (display "\n")
        (display "Registers:\n")
        (let ((regs (state-regs state)))
          (if (null? regs)
              (display "  (empty)\n")
              (let loop ((regs regs))
                (if (not (null? regs))
                    (let ((reg-entry (car regs)))
                      (display "  ")
                      (display (car reg-entry))
                      (display ": ")
                      (display (poly-to-nat (cdr reg-entry)))
                      (display "\n")
                      (loop (cdr regs)))))))
        (display "Flags: Z=")
        (display (flags-z (state-flags state)))
        (display ", C=")
        (display (flags-c (state-flags state)))
        (display "\n"))))

;; print-program: Pretty print program
(define (print-program prog)
  (if (not (program? prog))
      (error "print-program: expected Program" prog)
      (begin
        (display "=== AAL Program ===\n")
        (let ((instrs (program-instrs prog))
              (labels (program-labels prog)))
          (if (not (null? labels))
              (begin
                (display "Labels:\n")
                (let loop ((labels labels))
                  (if (not (null? labels))
                      (let ((label (car labels)))
                        (display "  ")
                        (display (car label))
                        (display ": ")
                        (display (cdr label))
                        (display "\n")
                        (loop (cdr labels)))))))
          (display "Instructions:\n")
          (let loop ((instrs instrs)
                     (index 0))
            (if (not (null? instrs))
                (begin
                  (display index)
                  (display ": ")
                  (display (instr-mnem (car instrs)))
                  (display " ")
                  (let ((ops (instr-operands (car instrs))))
                    (let op-loop ((ops ops))
                      (if (not (null? ops))
                          (begin
                            (display (car ops))
                            (if (not (null? (cdr ops)))
                                (display ", "))
                            (op-loop (cdr ops))))))
                  (display "\n")
                  (loop (cdr instrs) (+ index 1)))))))))

;; -----------------------------
;; Interactive Mode
;; -----------------------------

;; interpret-interactive: Interactive interpreter
(define (interpret-interactive prog)
  (if (not (program? prog))
      (error "interpret-interactive: expected Program" prog)
      (let ((state (make-initial-state)))
        (display "AAL Interactive Interpreter\n")
        (display "Type 'step' to execute next instruction, 'state' to show state, 'quit' to exit\n")
        (let loop ((current-state state))
          (display "> ")
          (let ((command (read)))
            (case command
              ((step)
               (let ((next-state (interpret-step current-state prog)))
                 (if (state? next-state)
                     (begin
                       (print-state next-state)
                       (loop next-state))
                     (begin
                       (display "Error or halt\n")
                       (loop current-state)))))
              ((state)
               (print-state current-state)
               (loop current-state))
              ((quit exit)
               (display "Exiting\n"))
              (else
               (display "Unknown command\n")
               (loop current-state))))))))

;; ============================================================
;; End of Interpreter
;; ============================================================

