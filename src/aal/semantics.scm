;; ============================================================
;; AAL Small-Step Semantics (R5RS Scheme)
;; Implements complete small-step semantics
;; Source: AAL Spec Section 8
;; ============================================================

(load "ast.scm")
(load "polynomials.scm")
(load "well-formed.scm")

;; -----------------------------
;; State Definition
;; -----------------------------

;; Flags: Zero flag, Carry flag, etc.
(define (make-flags z c)
  (list 'Flags z c))

(define (flags? x)
  (and (list? x)
       (= (length x) 3)
       (eq? (car x) 'Flags)
       (boolean? (cadr x))
       (boolean? (caddr x))))

(define (flags-z flags)
  (if (flags? flags)
      (cadr flags)
      (error "flags-z: expected Flags" flags)))

(define (flags-c flags)
  (if (flags? flags)
      (caddr flags)
      (error "flags-c: expected Flags" flags)))

(define (set-flags-z flags z)
  (if (flags? flags)
      (make-flags z (flags-c flags))
      (error "set-flags-z: expected Flags" flags)))

;; State: regs (Reg → poly), mem (nat → poly), pc (nat), flags (Flags)
(define (make-state regs mem pc flags)
  (list 'State regs mem pc flags))

(define (state? x)
  (and (list? x)
       (= (length x) 5)
       (eq? (car x) 'State)))

(define (state-regs state)
  (if (state? state)
      (cadr state)
      (error "state-regs: expected State" state)))

(define (state-mem state)
  (if (state? state)
      (caddr state)
      (error "state-mem: expected State" state)))

(define (state-pc state)
  (if (state? state)
      (cadddr state)
      (error "state-pc: expected State" state)))

(define (state-flags state)
  (if (state? state)
      (cadddr (cdr state))
      (error "state-flags: expected State" state)))

;; Update register in state
(define (state-set-reg state reg val)
  (if (not (state? state))
      (error "state-set-reg: expected State" state)
      (if (not (reg? reg))
          (error "state-set-reg: expected Reg" reg)
          (let ((regs (state-regs state)))
            (make-state
             (cons (cons reg val) regs)
             (state-mem state)
             (state-pc state)
             (state-flags state))))))

;; Get register value (default to zero polynomial)
(define (state-get-reg state reg)
  (if (not (state? state))
      (error "state-get-reg: expected State" state)
      (if (not (reg? reg))
          (error "state-get-reg: expected Reg" reg)
          (let ((regs (state-regs state)))
            (let ((entry (assq reg regs)))
              (if entry
                  (cdr entry)
                  '()))))))  ;; Zero polynomial

;; Update memory
(define (state-set-mem state addr val)
  (if (not (state? state))
      (error "state-set-mem: expected State" state)
      (make-state
       (state-regs state)
       (cons (cons addr val) (state-mem state))
       (state-pc state)
       (state-flags state))))

;; Get memory value (default to zero polynomial)
(define (state-get-mem state addr)
  (if (not (state? state))
      (error "state-get-mem: expected State" state)
      (let ((mem (state-mem state)))
        (let ((entry (assoc addr mem)))
          (if entry
              (cdr entry)
              '())))))

;; -----------------------------
;; Operand Evaluation
;; -----------------------------

;; eval-operand: Evaluate operand to polynomial value
(define (eval-operand state operand)
  (if (not (state? state))
      (error "eval-operand: expected State" state)
      (if (not (operand? operand))
          (error "eval-operand: expected Operand" operand)
          (cond
           ((oreg? operand)
            (state-get-reg state (oreg-reg operand)))
           ((oimm? operand)
            (oimm-poly operand))
           ((omem? operand)
            (let ((base-reg (omem-base operand))
                  (offset (omem-offset operand)))
              (let ((base-addr (poly-to-nat (state-get-reg state base-reg)))
                    (offset-val (if (integer? offset)
                                    offset
                                    (poly-to-nat (eval-operand state offset)))))
                (let ((addr (+ base-addr offset-val)))
                  (state-get-mem state addr)))))
           (else
            (error "eval-operand: cannot evaluate label operand" operand))))))

;; -----------------------------
;; Flag Computation
;; -----------------------------

;; compute-flags: Compute flags from operation result
(define (compute-flags result)
  (if (not (poly? result))
      (error "compute-flags: expected poly" result)
      (let ((trimmed (trim result)))
        (make-flags
         (null? trimmed)  ;; Z: zero flag
         #f))))  ;; C: carry flag (simplified)

;; -----------------------------
;; Step Relation
;; -----------------------------

;; step: Single step of execution
;; Returns: new state or error
(define (step state prog)
  (if (not (state? state))
      (error "step: expected State" state)
      (if (not (program? prog))
          (error "step: expected Program" prog)
          (let ((pc (state-pc state))
                (instrs (program-instrs prog))
                (ctx (make-context (program-labels prog))))
            (if (>= pc (length instrs))
                (error "step: PC out of bounds" pc)
                (let ((instr (list-ref instrs pc))
                      (operands (instr-operands instr))
                      (mnem (instr-mnem instr)))
                  (case mnem
                    ((MOV)
                     (if (= (length operands) 2)
                         (let ((dst (car operands))
                               (src (cadr operands))
                               (src-val (eval-operand state src)))
                           (cond
                            ((oreg? dst)
                             (let ((new-state (state-set-reg state (oreg-reg dst) src-val))
                                   (new-flags (compute-flags src-val)))
                               (make-state
                                (state-regs new-state)
                                (state-mem new-state)
                                (+ pc 1)
                                new-flags)))
                            ((omem? dst)
                             (let ((base-reg (omem-base dst))
                                   (offset (omem-offset dst))
                                   (base-addr (poly-to-nat (state-get-reg state base-reg)))
                                   (offset-val (if (integer? offset)
                                                   offset
                                                   (poly-to-nat (eval-operand state offset)))))
                               (let ((addr (+ base-addr offset-val))
                                     (new-state (state-set-mem state addr src-val)))
                                 (make-state
                                  (state-regs new-state)
                                  (state-mem new-state)
                                  (+ pc 1)
                                  (state-flags new-state)))))))
                         (error "step: MOV arity error")))
                    ((ADD)
                     (if (= (length operands) 2)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (src-val (eval-operand state (cadr operands)))
                               (dst-val (state-get-reg state dst-reg))
                               (result (poly-add dst-val src-val))
                               (new-flags (compute-flags result)))
                           (make-state
                            (cons (cons dst-reg result) (state-regs state))
                            (state-mem state)
                            (+ pc 1)
                            new-flags))
                         (error "step: ADD arity error")))
                    ((SUB)
                     (if (= (length operands) 2)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (src-val (eval-operand state (cadr operands)))
                               (dst-val (state-get-reg state dst-reg))
                               (result (poly-add dst-val src-val))  ;; SUB = ADD in F2
                               (new-flags (compute-flags result)))
                           (make-state
                            (cons (cons dst-reg result) (state-regs state))
                            (state-mem state)
                            (+ pc 1)
                            new-flags))
                         (error "step: SUB arity error")))
                    ((XOR)
                     (if (= (length operands) 2)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (src-val (eval-operand state (cadr operands)))
                               (dst-val (state-get-reg state dst-reg))
                               (result (poly-add dst-val src-val))  ;; XOR = ADD in F2
                               (new-flags (compute-flags result)))
                           (make-state
                            (cons (cons dst-reg result) (state-regs state))
                            (state-mem state)
                            (+ pc 1)
                            new-flags))
                         (error "step: XOR arity error")))
                    ((AND)
                     (if (= (length operands) 2)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (src-val (eval-operand state (cadr operands)))
                               (dst-val (state-get-reg state dst-reg))
                               (result (poly-and dst-val src-val))
                               (new-flags (compute-flags result)))
                           (make-state
                            (cons (cons dst-reg result) (state-regs state))
                            (state-mem state)
                            (+ pc 1)
                            new-flags))
                         (error "step: AND arity error")))
                    ((OR)
                     (if (= (length operands) 2)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (src-val (eval-operand state (cadr operands)))
                               (dst-val (state-get-reg state dst-reg))
                               (result (poly-or dst-val src-val))
                               (new-flags (compute-flags result)))
                           (make-state
                            (cons (cons dst-reg result) (state-regs state))
                            (state-mem state)
                            (+ pc 1)
                            new-flags))
                         (error "step: OR arity error")))
                    ((SHL)
                     (if (= (length operands) 2)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (k (poly-to-nat (oimm-poly (cadr operands))))
                               (dst-val (state-get-reg state dst-reg))
                               (result (shift-left dst-val k))
                               (new-flags (compute-flags result)))
                           (make-state
                            (cons (cons dst-reg result) (state-regs state))
                            (state-mem state)
                            (+ pc 1)
                            (state-flags state)))
                         (error "step: SHL arity error")))
                    ((SHR)
                     (if (= (length operands) 2)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (k (poly-to-nat (oimm-poly (cadr operands))))
                               (dst-val (state-get-reg state dst-reg))
                               (result (shift-right dst-val k))
                               (new-flags (compute-flags result)))
                           (make-state
                            (cons (cons dst-reg result) (state-regs state))
                            (state-mem state)
                            (+ pc 1)
                            (state-flags state)))
                         (error "step: SHR arity error")))
                    ((ROL)
                     (if (= (length operands) 2)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (k (poly-to-nat (oimm-poly (cadr operands))))
                               (dst-val (state-get-reg state dst-reg))
                               (w 8)  ;; word size
                               (result (poly-rol dst-val k w))
                               (new-flags (compute-flags result)))
                           (make-state
                            (cons (cons dst-reg result) (state-regs state))
                            (state-mem state)
                            (+ pc 1)
                            (state-flags state)))
                         (error "step: ROL arity error")))
                    ((ROR)
                     (if (= (length operands) 2)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (k (poly-to-nat (oimm-poly (cadr operands))))
                               (dst-val (state-get-reg state dst-reg))
                               (w 8)  ;; word size
                               (result (poly-ror dst-val k w))
                               (new-flags (compute-flags result)))
                           (make-state
                            (cons (cons dst-reg result) (state-regs state))
                            (state-mem state)
                            (+ pc 1)
                            (state-flags state)))
                         (error "step: ROR arity error")))
                    ((PUSH)
                     (if (= (length operands) 1)
                         (let ((src-reg (oreg-reg (car operands)))
                               (src-val (state-get-reg state src-reg))
                               (sp (poly-to-nat (state-get-reg state 'SP)))
                               (sp-new (- sp 8)))
                           (make-state
                            (cons (cons 'SP (nat-to-poly sp-new)) (state-regs state))
                            (cons (cons sp-new src-val) (state-mem state))
                            (+ pc 1)
                            (state-flags state)))
                         (error "step: PUSH arity error")))
                    ((POP)
                     (if (= (length operands) 1)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (sp (poly-to-nat (state-get-reg state 'SP)))
                               (val (state-get-mem state sp))
                               (sp-new (+ sp 8)))
                           (make-state
                            (cons (cons dst-reg val)
                                  (cons (cons 'SP (nat-to-poly sp-new)) (state-regs state)))
                            (state-mem state)
                            (+ pc 1)
                            (state-flags state)))
                         (error "step: POP arity error")))
                    ((JMP)
                     (if (= (length operands) 1)
                         (let ((label-name (olabel-label (car operands)))
                               (new-pc (resolve-label ctx label-name)))
                           (make-state
                            (state-regs state)
                            (state-mem state)
                            new-pc
                            (state-flags state)))
                         (error "step: JMP arity error")))
                    ((JE)
                     (if (= (length operands) 1)
                         (let ((label-name (olabel-label (car operands)))
                               (z-flag (flags-z (state-flags state))))
                           (if z-flag
                               (let ((new-pc (resolve-label ctx label-name)))
                                 (make-state
                                  (state-regs state)
                                  (state-mem state)
                                  new-pc
                                  (state-flags state)))
                               (make-state
                                (state-regs state)
                                (state-mem state)
                                (+ pc 1)
                                (state-flags state))))
                         (error "step: JE arity error")))
                    ((JNE)
                     (if (= (length operands) 1)
                         (let ((label-name (olabel-label (car operands)))
                               (z-flag (flags-z (state-flags state))))
                           (if (not z-flag)
                               (let ((new-pc (resolve-label ctx label-name)))
                                 (make-state
                                  (state-regs state)
                                  (state-mem state)
                                  new-pc
                                  (state-flags state)))
                               (make-state
                                (state-regs state)
                                (state-mem state)
                                (+ pc 1)
                                (state-flags state))))
                         (error "step: JNE arity error")))
                    ((JZ)
                     (if (= (length operands) 1)
                         (let ((label-name (olabel-label (car operands)))
                               (z-flag (flags-z (state-flags state))))
                           (if z-flag
                               (let ((new-pc (resolve-label ctx label-name)))
                                 (make-state
                                  (state-regs state)
                                  (state-mem state)
                                  new-pc
                                  (state-flags state)))
                               (make-state
                                (state-regs state)
                                (state-mem state)
                                (+ pc 1)
                                (state-flags state))))
                         (error "step: JZ arity error")))
                    ((JNZ)
                     (if (= (length operands) 1)
                         (let ((label-name (olabel-label (car operands)))
                               (z-flag (flags-z (state-flags state))))
                           (if (not z-flag)
                               (let ((new-pc (resolve-label ctx label-name)))
                                 (make-state
                                  (state-regs state)
                                  (state-mem state)
                                  new-pc
                                  (state-flags state)))
                               (make-state
                                (state-regs state)
                                (state-mem state)
                                (+ pc 1)
                                (state-flags state))))
                         (error "step: JNZ arity error")))
                    ((CALL)
                     (if (= (length operands) 1)
                         (let ((label-name (olabel-label (car operands)))
                               (new-pc (resolve-label ctx label-name))
                               (sp (poly-to-nat (state-get-reg state 'SP)))
                               (sp-new (- sp 8))
                               (return-addr (nat-to-poly (+ pc 1))))
                           (make-state
                            (cons (cons 'SP (nat-to-poly sp-new)) (state-regs state))
                            (cons (cons sp-new return-addr) (state-mem state))
                            new-pc
                            (state-flags state)))
                         (error "step: CALL arity error")))
                    ((RET)
                     (if (= (length operands) 0)
                         (let ((sp (poly-to-nat (state-get-reg state 'SP)))
                               (return-addr (poly-to-nat (state-get-mem state sp)))
                               (sp-new (+ sp 8)))
                           (make-state
                            (cons (cons 'SP (nat-to-poly sp-new)) (state-regs state))
                            (state-mem state)
                            return-addr
                            (state-flags state)))
                         (error "step: RET arity error")))
                    ((HLT)
                     state)  ;; Terminal: no state change
                    ((NOP)
                     (make-state
                      (state-regs state)
                      (state-mem state)
                      (+ pc 1)
                      (state-flags state)))
                    ((LD)
                     (if (= (length operands) 2)
                         (let ((dst-reg (oreg-reg (car operands)))
                               (mem-op (cadr operands))
                               (addr (poly-to-nat (eval-operand state mem-op)))
                               (val (state-get-mem state addr)))
                           (make-state
                            (cons (cons dst-reg val) (state-regs state))
                            (state-mem state)
                            (+ pc 1)
                            (state-flags state)))
                         (error "step: LD arity error")))
                    ((ST)
                     (if (= (length operands) 2)
                         (let ((mem-op (car operands))
                               (src-val (eval-operand state (cadr operands)))
                               (addr (poly-to-nat (eval-operand state mem-op)))
                               (new-state (state-set-mem state addr src-val)))
                           (make-state
                            (state-regs new-state)
                            (state-mem new-state)
                            (+ pc 1)
                            (state-flags state)))
                         (error "step: ST arity error")))
                    (else
                     (error "step: unknown mnemonic" mnem)))))))))

;; Helper functions for bitwise operations
(define (poly-and p1 p2)
  (let ((p1-trimmed (trim p1))
        (p2-trimmed (trim p2))
        (max-len (max (length p1-trimmed) (length p2-trimmed))))
    (trim
     (let loop ((i 0)
                (result '()))
       (if (>= i max-len)
           (reverse result)
           (let ((c1 (if (< i (length p1-trimmed))
                         (list-ref p1-trimmed i)
                         #f))
                 (c2 (if (< i (length p2-trimmed))
                         (list-ref p2-trimmed i)
                         #f)))
             (loop (+ i 1)
                   (cons (and c1 c2) result))))))))

(define (poly-or p1 p2)
  (let ((p1-trimmed (trim p1))
        (p2-trimmed (trim p2))
        (max-len (max (length p1-trimmed) (length p2-trimmed))))
    (trim
     (let loop ((i 0)
                (result '()))
       (if (>= i max-len)
           (reverse result)
           (let ((c1 (if (< i (length p1-trimmed))
                         (list-ref p1-trimmed i)
                         #f))
                 (c2 (if (< i (length p2-trimmed))
                         (list-ref p2-trimmed i)
                         #f)))
             (loop (+ i 1)
                   (cons (or c1 c2) result))))))))

;; Rotation operations (modulo x^w - 1)
(define (poly-rol poly k w)
  (let ((trimmed (trim poly))
        (k-mod (modulo k w)))
    (if (null? trimmed)
        '()
        (let ((padded (append trimmed (make-list (- w (length trimmed)) #f))))
          (append (list-tail padded k-mod)
                  (list-head padded k-mod))))))

(define (poly-ror poly k w)
  (let ((trimmed (trim poly))
        (k-mod (modulo k w)))
    (if (null? trimmed)
        '()
        (let ((padded (append trimmed (make-list (- w (length trimmed)) #f))))
          (append (list-tail padded (- w k-mod))
                  (list-head padded (- w k-mod)))))))

(define (list-head lst n)
  (if (<= n 0)
      '()
      (if (null? lst)
          '()
          (cons (car lst) (list-head (cdr lst) (- n 1))))))

;; -----------------------------
;; Multi-Step Relation
;; -----------------------------

;; multi-step: Reflexive-transitive closure
(define (multi-step state1 state2 prog max-steps)
  (if (not (state? state1))
      (error "multi-step: expected State" state1)
      (if (not (state? state2))
          (error "multi-step: expected State" state2)
          (if (not (program? prog))
              (error "multi-step: expected Program" prog)
              (if (equal? state1 state2)
                  #t
                  (if (<= max-steps 0)
                      #f
                      (let ((next-state (step state1 prog)))
                        (if (state? next-state)
                            (multi-step next-state state2 prog (- max-steps 1))
                            #f))))))))

;; ============================================================
;; End of Semantics
;; ============================================================

