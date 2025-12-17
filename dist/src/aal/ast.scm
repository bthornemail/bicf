;; ============================================================
;; AAL Abstract Syntax Tree (R5RS Scheme)
;; Implements AAL v3.2 AST definitions
;; Source: AAL Spec Section 3 (EBNF Grammar)
;; ============================================================

;; -----------------------------
;; Register Definitions
;; -----------------------------

;; Reg: R0-R7, PC, SP, FLAGS
(define (reg? x)
  (and (symbol? x)
       (or (memq x '(R0 R1 R2 R3 R4 R5 R6 R7))
           (memq x '(PC SP FLAGS)))))

;; -----------------------------
;; Operand Types
;; -----------------------------

;; OReg: Register operand
(define (make-oreg reg)
  (if (reg? reg)
      (list 'OReg reg)
      (error "make-oreg: expected Reg" reg)))

(define (oreg? x)
  (and (list? x)
       (eq? (car x) 'OReg)
       (= (length x) 2)
       (reg? (cadr x))))

(define (oreg-reg oreg)
  (if (oreg? oreg)
      (cadr oreg)
      (error "oreg-reg: expected OReg" oreg)))

;; OImm: Immediate operand (polynomial as list of booleans)
(define (make-oimm poly)
  (if (list? poly)
      (list 'OImm poly)
      (error "make-oimm: expected list (polynomial)" poly)))

(define (oimm? x)
  (and (list? x)
       (eq? (car x) 'OImm)
       (= (length x) 2)
       (list? (cadr x))))

(define (oimm-poly oimm)
  (if (oimm? oimm)
      (cadr oimm)
      (error "oimm-poly: expected OImm" oimm)))

;; OMem: Memory operand [base + offset]
(define (make-omem base offset)
  (list 'OMem base offset))

(define (omem? x)
  (and (list? x)
       (eq? (car x) 'OMem)
       (= (length x) 3)))

(define (omem-base omem)
  (if (omem? omem)
      (cadr omem)
      (error "omem-base: expected OMem" omem)))

(define (omem-offset omem)
  (if (omem? omem)
      (caddr omem)
      (error "omem-offset: expected OMem" omem)))

;; OLabel: Label operand
(define (make-olabel label)
  (if (string? label)
      (list 'OLabel label)
      (error "make-olabel: expected string" label)))

(define (olabel? x)
  (and (list? x)
       (eq? (car x) 'OLabel)
       (= (length x) 2)
       (string? (cadr x))))

(define (olabel-label olabel)
  (if (olabel? olabel)
      (cadr olabel)
      (error "olabel-label: expected OLabel" olabel)))

;; Operand: Union type
(define (operand? x)
  (or (oreg? x)
      (oimm? x)
      (omem? x)
      (olabel? x)))

;; -----------------------------
;; Mnemonics
;; -----------------------------

(define *mnemonics*
  '(MOV ADD SUB XOR AND OR SHL SHR ROL ROR
    PUSH POP JMP JE JNE JZ JNZ CALL RET
    HLT NOP LD ST))

(define (mnemonic? x)
  (and (symbol? x)
       (memq x *mnemonics*)))

;; Instruction arity (number of operands required)
(define (mnemonic-arity mnem)
  (if (not (mnemonic? mnem))
      (error "mnemonic-arity: expected Mnemonic" mnem)
      (case mnem
        ((MOV ADD SUB XOR AND OR SHL SHR ROL ROR LD ST) 2)
        ((PUSH POP JMP JE JNE JZ JNZ CALL) 1)
        ((RET HLT NOP) 0)
        (else (error "mnemonic-arity: unknown mnemonic" mnem)))))

;; -----------------------------
;; Instructions
;; -----------------------------

;; MkInstr: Instruction with mnemonic and operands
(define (make-instr mnem operands)
  (if (not (mnemonic? mnem))
      (error "make-instr: expected Mnemonic" mnem)
      (if (not (list? operands))
          (error "make-instr: expected list of operands" operands)
          (let ((expected-arity (mnemonic-arity mnem)))
            (if (not (= (length operands) expected-arity))
                (error "make-instr: arity mismatch" (list mnem expected-arity (length operands)))
                (list 'MkInstr mnem operands))))))

(define (instr? x)
  (and (list? x)
       (>= (length x) 2)
       (eq? (car x) 'MkInstr)
       (mnemonic? (cadr x))
       (list? (caddr x))))

(define (instr-mnem instr)
  (if (instr? instr)
      (cadr instr)
      (error "instr-mnem: expected Instr" instr)))

(define (instr-operands instr)
  (if (instr? instr)
      (caddr instr)
      (error "instr-operands: expected Instr" instr)))

;; -----------------------------
;; Labels
;; -----------------------------

;; Label definition: (label-name . instruction-index)
(define (label? x)
  (and (pair? x)
       (string? (car x))
       (integer? (cdr x))
       (>= (cdr x) 0)))

;; -----------------------------
;; Programs
;; -----------------------------

;; Program: list of instructions with optional labels
(define (program? x)
  (and (list? x)
       (or (null? x)
           (let ((first (car x)))
             (or (instr? first)
                 (label? first)
                 (and (pair? first)
                      (label? (car first))
                      (instr? (cdr first))))))))

;; Extract instructions from program (filter out standalone labels)
(define (program-instrs prog)
  (if (not (program? prog))
      (error "program-instrs: expected Program" prog)
      (let loop ((prog prog)
                 (instrs '()))
        (if (null? prog)
            (reverse instrs)
            (let ((item (car prog)))
              (cond
               ((instr? item)
                (loop (cdr prog) (cons item instrs)))
               ((label? item)
                (loop (cdr prog) instrs))
               ((and (pair? item) (label? (car item)) (instr? (cdr item)))
                (loop (cdr prog) (cons (cdr item) instrs)))
               (else
                (error "program-instrs: invalid program item" item))))))))

;; Extract labels from program
(define (program-labels prog)
  (if (not (program? prog))
      (error "program-labels: expected Program" prog)
      (let loop ((prog prog)
                 (index 0)
                 (labels '()))
        (if (null? prog)
            (reverse labels)
            (let ((item (car prog)))
              (cond
               ((instr? item)
                (loop (cdr prog) (+ index 1) labels))
               ((label? item)
                (loop (cdr prog) (+ index 1) (cons (cons (car item) index) labels)))
               ((and (pair? item) (label? (car item)) (instr? (cdr item)))
                (loop (cdr prog) (+ index 1) (cons (cons (car (car item)) index) labels)))
               (else
                (error "program-labels: invalid program item" item))))))))

;; ============================================================
;; End of AST Definitions
;; ============================================================

