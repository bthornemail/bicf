;; ============================================================
;; AAL Type System (R5RS Scheme)
;; Implements graded modal type system (D0-D10)
;; Source: AAL Spec Section 4, 6
;; ============================================================

(load "ast.scm")

;; -----------------------------
;; Dimension Types
;; -----------------------------

;; Dimension: D0-D10
(define *dimensions*
  '(D0 D1 D2 D3 D4 D5 D6 D7 D8 D9 D10))

(define (dimension? x)
  (and (symbol? x)
       (memq x *dimensions*)))

;; dim-to-nat: Convert dimension to natural number
(define (dim-to-nat dim)
  (if (not (dimension? dim))
      (error "dim-to-nat: expected Dimension" dim)
      (let loop ((dims *dimensions*)
                 (n 0))
        (if (null? dims)
            (error "dim-to-nat: invalid dimension" dim)
            (if (eq? (car dims) dim)
                n
                (loop (cdr dims) (+ n 1)))))))

;; nat-to-dim: Convert natural number to dimension
(define (nat-to-dim n)
  (if (not (integer? n))
      (error "nat-to-dim: expected integer" n)
      (if (or (< n 0) (> n 10))
          (error "nat-to-dim: n must be 0-10" n)
          (list-ref *dimensions* n))))

;; -----------------------------
;; Dimension Ordering
;; -----------------------------

;; dim-le: Dimension ordering relation (d1 <= d2)
(define (dim-le d1 d2)
  (if (not (dimension? d1))
      (error "dim-le: expected Dimension" d1)
      (if (not (dimension? d2))
          (error "dim-le: expected Dimension" d2)
          (<= (dim-to-nat d1) (dim-to-nat d2)))))

;; max-dim: Maximum dimension
(define (max-dim d1 d2)
  (if (not (dimension? d1))
      (error "max-dim: expected Dimension" d1)
      (if (not (dimension? d2))
          (error "max-dim: expected Dimension" d2)
          (if (dim-le d1 d2)
              d2
              d1))))

;; -----------------------------
;; Type Definitions
;; -----------------------------

;; Type: PolyT | AddrT | StateT | □_d Type
(define (type? x)
  (or (eq? x 'PolyT)
      (eq? x 'AddrT)
      (eq? x 'StateT)
      (and (list? x)
           (= (length x) 3)
           (eq? (car x) 'Box)
           (dimension? (cadr x))
           (type? (caddr x)))))

;; Make graded modality: □_d type
(define (make-box dim ty)
  (if (not (dimension? dim))
      (error "make-box: expected Dimension" dim)
      (if (not (type? ty))
          (error "make-box: expected Type" ty)
          (list 'Box dim ty))))

(define (box? x)
  (and (list? x)
       (= (length x) 3)
       (eq? (car x) 'Box)))

(define (box-dim box)
  (if (box? box)
      (cadr box)
      (error "box-dim: expected Box type" box)))

(define (box-type box)
  (if (box? box)
      (caddr box)
      (error "box-type: expected Box type" box)))

;; -----------------------------
;; Minimum Grade for Mnemonics
;; -----------------------------

;; min-grade: Minimum dimension required for mnemonic
(define (min-grade mnem)
  (if (not (mnemonic? mnem))
      (error "min-grade: expected Mnemonic" mnem)
      (case mnem
        ;; Register-only operations: D0
        ((MOV ADD SUB XOR AND OR SHL SHR ROL ROR)
         'D0)
        ;; Memory operations: D3
        ((LD ST)
         'D3)
        ;; Stack operations: D4
        ((PUSH POP)
         'D4)
        ;; Control flow: D4
        ((JMP JE JNE JZ JNZ CALL RET)
         'D4)
        ;; No-op: D0
        ((NOP)
         'D0)
        ;; Halt: D0
        ((HLT)
         'D0)
        (else
         (error "min-grade: unknown mnemonic" mnem)))))

;; -----------------------------
;; Typing Judgments
;; -----------------------------

;; typed-instr: Instruction typing judgment
;; Returns: □_d (State → State) or #f if type error
(define (typed-instr instr)
  (if (not (instr? instr))
      (error "typed-instr: expected Instr" instr)
      (let ((mnem (instr-mnem instr))
            (operands (instr-operands instr)))
        (let ((min-dim (min-grade mnem)))
          ;; Check operand types based on mnemonic
          (case mnem
            ((MOV)
             (if (= (length operands) 2)
                 (let ((dst (car operands))
                       (src (cadr operands)))
                   (cond
                    ;; MOV reg, reg: D0
                    ((and (oreg? dst) (oreg? src))
                     (make-box 'D0 'StateT))
                    ;; MOV reg, imm: D0
                    ((and (oreg? dst) (oimm? src))
                     (make-box 'D0 'StateT))
                    ;; MOV reg, [mem]: D3
                    ((and (oreg? dst) (omem? src))
                     (make-box 'D3 'StateT))
                    ;; MOV [mem], reg: D3
                    ((and (omem? dst) (oreg? src))
                     (make-box 'D3 'StateT))
                    (else #f)))
                 #f))
            ((ADD SUB XOR AND OR)
             (if (and (= (length operands) 2)
                      (oreg? (car operands))
                      (or (oreg? (cadr operands))
                          (oimm? (cadr operands))))
                 (make-box 'D0 'StateT)
                 #f))
            ((SHL SHR ROL ROR)
             (if (and (= (length operands) 2)
                      (oreg? (car operands))
                      (oimm? (cadr operands)))
                 (make-box 'D0 'StateT)
                 #f))
            ((LD)
             (if (and (= (length operands) 2)
                      (oreg? (car operands))
                      (omem? (cadr operands)))
                 (make-box 'D3 'StateT)
                 #f))
            ((ST)
             (if (and (= (length operands) 2)
                      (omem? (car operands))
                      (or (oreg? (cadr operands))
                          (oimm? (cadr operands))))
                 (make-box 'D3 'StateT)
                 #f))
            ((PUSH POP)
             (if (and (= (length operands) 1)
                      (oreg? (car operands)))
                 (make-box 'D4 'StateT)
                 #f))
            ((JMP JE JNE JZ JNZ CALL)
             (if (and (= (length operands) 1)
                      (olabel? (car operands)))
                 (make-box 'D4 'StateT)
                 #f))
            ((RET HLT NOP)
             (if (= (length operands) 0)
                 (make-box min-dim 'StateT)
                 #f))
            (else #f))))))

;; typed-program: Program typing judgment
;; Returns: list of types or #f if type error
(define (typed-program prog)
  (if (not (program? prog))
      (error "typed-program: expected Program" prog)
      (let ((instrs (program-instrs prog)))
        (let loop ((instrs instrs)
                   (types '()))
          (if (null? instrs)
              (reverse types)
              (let ((ty (typed-instr (car instrs))))
                (if (not ty)
                    #f
                    (loop (cdr instrs) (cons ty types)))))))))

;; -----------------------------
;; Grade Weakening
;; -----------------------------

;; grade-weaken: Weaken grade from d1 to d2 (if d1 <= d2)
;; □_d1 T -> □_d2 T
(define (grade-weaken ty d2)
  (if (not (type? ty))
      (error "grade-weaken: expected Type" ty)
      (if (not (dimension? d2))
          (error "grade-weaken: expected Dimension" d2)
          (if (box? ty)
              (let ((d1 (box-dim ty))
                    (inner-ty (box-type ty)))
                (if (dim-le d1 d2)
                    (make-box d2 inner-ty)
                    (error "grade-weaken: cannot weaken from higher to lower dimension" (list d1 d2))))
              ty))))

;; ============================================================
;; End of Type System
;; ============================================================

