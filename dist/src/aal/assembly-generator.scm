;; ============================================================
;; AAL Assembly Generator (R5RS Scheme)
;; Generates executable assembly code from AAL programs
;; Source: AAL Spec Section 8 (Semantics)
;; ============================================================

(load "ast.scm")
(load "polynomials.scm")

;; -----------------------------
;; Target Architecture Definitions
;; -----------------------------

;; Supported architectures
(define *architectures* '(x86 arm riscv generic))

(define (architecture? x)
  (memq x *architectures*))

;; Current target architecture
(define *target-arch* 'generic)

(define (set-target-arch arch)
  (if (not (architecture? arch))
      (error "set-target-arch: expected architecture" arch)
      (set! *target-arch* arch)))

(define (get-target-arch)
  *target-arch*)

;; -----------------------------
;; Register Mapping
;; -----------------------------

;; Map AAL registers to target architecture registers
(define (map-register aal-reg arch)
  (if (not (reg? aal-reg))
      (error "map-register: expected Reg" aal-reg)
      (if (not (architecture? arch))
          (error "map-register: expected architecture" arch)
          (case arch
            ((x86)
             (case aal-reg
               ((R0) 'eax)
               ((R1) 'ebx)
               ((R2) 'ecx)
               ((R3) 'edx)
               ((R4) 'esi)
               ((R5) 'edi)
               ((R6) 'ebp)
               ((R7) 'esp)
               ((PC) 'eip)
               ((SP) 'esp)
               ((FLAGS) 'eflags)
               (else aal-reg)))
            ((arm)
             (case aal-reg
               ((R0) 'r0)
               ((R1) 'r1)
               ((R2) 'r2)
               ((R3) 'r3)
               ((R4) 'r4)
               ((R5) 'r5)
               ((R6) 'r6)
               ((R7) 'r7)
               ((PC) 'pc)
               ((SP) 'sp)
               ((FLAGS) 'cpsr)
               (else aal-reg)))
            ((riscv)
             (case aal-reg
               ((R0) 'zero)  ;; R0 is always zero in RISC-V
               ((R1) 'ra)
               ((R2) 'sp)
               ((R3) 'gp)
               ((R4) 'tp)
               ((R5) 't0)
               ((R6) 't1)
               ((R7) 't2)
               ((PC) 'pc)
               ((SP) 'sp)
               ((FLAGS) 'flags)
               (else aal-reg)))
            ((generic)
             ;; Generic: keep AAL register names
             aal-reg)
            (else aal-reg)))))

;; -----------------------------
;; Instruction Generation
;; -----------------------------

;; generate-instruction: Generate assembly instruction from AAL instruction
(define (generate-instruction instr arch labels)
  (if (not (instr? instr))
      (error "generate-instruction: expected Instr" instr)
      (if (not (architecture? arch))
          (error "generate-instruction: expected architecture" arch)
          (let ((mnem (instr-mnem instr))
                (operands (instr-operands instr)))
            (case mnem
              ((MOV)
               (generate-mov instr arch))
              ((ADD SUB XOR AND OR)
               (generate-arithmetic instr arch))
              ((SHL SHR ROL ROR)
               (generate-shift instr arch))
              ((LD ST)
               (generate-memory instr arch))
              ((PUSH POP)
               (generate-stack instr arch))
              ((JMP JE JNE JZ JNZ CALL RET)
               (generate-control-flow instr arch labels))
              ((HLT NOP)
               (generate-simple instr arch))
              (else
               (error "generate-instruction: unknown mnemonic" mnem)))))))

;; generate-mov: Generate MOV instruction
(define (generate-mov instr arch)
  (let ((operands (instr-operands instr))
        (dst (car operands))
        (src (cadr operands)))
    (case arch
      ((x86)
       (string-append "mov "
                      (operand-to-string dst arch) ", "
                      (operand-to-string src arch)))
      ((arm)
       (string-append "mov "
                      (operand-to-string dst arch) ", "
                      (operand-to-string src arch)))
      ((riscv)
       (if (oimm? src)
           (string-append "li "
                          (operand-to-string dst arch) ", "
                          (operand-to-string src arch))
           (string-append "mv "
                          (operand-to-string dst arch) ", "
                          (operand-to-string src arch))))
      ((generic)
       (string-append "MOV "
                      (operand-to-string dst arch) ", "
                      (operand-to-string src arch)))
      (else ""))))

;; generate-arithmetic: Generate arithmetic instructions
(define (generate-arithmetic instr arch)
  (let ((mnem (instr-mnem instr))
        (operands (instr-operands instr))
        (dst (car operands))
        (src (cadr operands)))
    (let ((op-name (symbol->string mnem)))
      (case arch
        ((x86)
         (string-append (string-downcase op-name) " "
                        (operand-to-string dst arch) ", "
                        (operand-to-string src arch)))
        ((arm)
         (string-append (string-downcase op-name) " "
                        (operand-to-string dst arch) ", "
                        (operand-to-string dst arch) ", "
                        (operand-to-string src arch)))
        ((riscv)
         (case mnem
           ((ADD) (string-append "add "
                                 (operand-to-string dst arch) ", "
                                 (operand-to-string dst arch) ", "
                                 (operand-to-string src arch)))
           ((SUB) (string-append "sub "
                                 (operand-to-string dst arch) ", "
                                 (operand-to-string dst arch) ", "
                                 (operand-to-string src arch)))
           ((XOR) (string-append "xor "
                                 (operand-to-string dst arch) ", "
                                 (operand-to-string dst arch) ", "
                                 (operand-to-string src arch)))
           (else (string-append (symbol->string mnem) " "
                                 (operand-to-string dst arch) ", "
                                 (operand-to-string src arch)))))
        ((generic)
         (string-append (symbol->string mnem) " "
                        (operand-to-string dst arch) ", "
                        (operand-to-string src arch)))
        (else "")))))

;; generate-shift: Generate shift/rotate instructions
(define (generate-shift instr arch)
  (let ((mnem (instr-mnem instr))
        (operands (instr-operands instr))
        (dst (car operands))
        (src (cadr operands))
        (amount (if (>= (length operands) 3) (caddr operands) (cadr operands))))
    (case arch
      ((x86)
       (string-append (case mnem
                        ((SHL) "shl")
                        ((SHR) "shr")
                        ((ROL) "rol")
                        ((ROR) "ror")
                        (else "shl"))
                      " "
                      (operand-to-string dst arch) ", "
                      (operand-to-string amount arch)))
      ((arm)
       (string-append (case mnem
                        ((SHL) "lsl")
                        ((SHR) "lsr")
                        ((ROL) "ror")
                        ((ROR) "ror")
                        (else "lsl"))
                      " "
                      (operand-to-string dst arch) ", "
                      (operand-to-string dst arch) ", "
                      (operand-to-string amount arch)))
      ((riscv)
       (string-append (case mnem
                        ((SHL) "sll")
                        ((SHR) "srl")
                        ((ROL) "rol")
                        ((ROR) "ror")
                        (else "sll"))
                      " "
                      (operand-to-string dst arch) ", "
                      (operand-to-string dst arch) ", "
                      (operand-to-string amount arch)))
      ((generic)
       (string-append (symbol->string mnem) " "
                      (operand-to-string dst arch) ", "
                      (operand-to-string amount arch)))
      (else ""))))

;; generate-memory: Generate memory access instructions
(define (generate-memory instr arch)
  (let ((mnem (instr-mnem instr))
        (operands (instr-operands instr)))
    (case mnem
      ((LD)
       (let ((dst (car operands))
             (src (cadr operands)))
         (case arch
           ((x86)
            (string-append "mov "
                           (operand-to-string dst arch) ", ["
                           (operand-to-string src arch) "]"))
           ((arm)
            (string-append "ldr "
                           (operand-to-string dst arch) ", ["
                           (operand-to-string src arch) "]"))
           ((riscv)
            (string-append "lw "
                           (operand-to-string dst arch) ", ("
                           (operand-to-string src arch) ")"))
           ((generic)
            (string-append "LD "
                           (operand-to-string dst arch) ", ["
                           (operand-to-string src arch) "]"))
           (else ""))))
      ((ST)
       (let ((dst (car operands))
             (src (cadr operands)))
         (case arch
           ((x86)
            (string-append "mov ["
                           (operand-to-string dst arch) "], "
                           (operand-to-string src arch)))
           ((arm)
            (string-append "str "
                           (operand-to-string src arch) ", ["
                           (operand-to-string dst arch) "]"))
           ((riscv)
            (string-append "sw "
                           (operand-to-string src arch) ", ("
                           (operand-to-string dst arch) ")"))
           ((generic)
            (string-append "ST ["
                           (operand-to-string dst arch) "], "
                           (operand-to-string src arch)))
           (else ""))))
      (else ""))))

;; generate-stack: Generate stack operations
(define (generate-stack instr arch)
  (let ((mnem (instr-mnem instr))
        (operands (instr-operands instr))
        (reg (car operands)))
    (case mnem
      ((PUSH)
       (case arch
         ((x86) (string-append "push " (operand-to-string reg arch)))
         ((arm) (string-append "push {" (operand-to-string reg arch) "}"))
         ((riscv) (string-append "addi sp, sp, -4\nsw "
                                  (operand-to-string reg arch) ", 0(sp)"))
         ((generic) (string-append "PUSH " (operand-to-string reg arch)))
         (else "")))
      ((POP)
       (case arch
         ((x86) (string-append "pop " (operand-to-string reg arch)))
         ((arm) (string-append "pop {" (operand-to-string reg arch) "}"))
         ((riscv) (string-append "lw "
                                  (operand-to-string reg arch) ", 0(sp)\naddi sp, sp, 4"))
         ((generic) (string-append "POP " (operand-to-string reg arch)))
         (else "")))
      (else ""))))

;; generate-control-flow: Generate control flow instructions
(define (generate-control-flow instr arch labels)
  (let ((mnem (instr-mnem instr))
        (operands (instr-operands instr))
        (target (if (null? operands) #f (car operands))))
    (if (not target)
        ""
        (let ((label-str (if (olabel? target)
                             (olabel-label target)
                             "")))
          (case mnem
            ((JMP)
             (case arch
               ((x86) (string-append "jmp " label-str))
               ((arm) (string-append "b " label-str))
               ((riscv) (string-append "j " label-str))
               ((generic) (string-append "JMP " label-str))
               (else "")))
            ((JE)
             (case arch
               ((x86) (string-append "je " label-str))
               ((arm) (string-append "beq " label-str))
               ((riscv) (string-append "beq zero, zero, " label-str))
               ((generic) (string-append "JE " label-str))
               (else "")))
            ((JNE)
             (case arch
               ((x86) (string-append "jne " label-str))
               ((arm) (string-append "bne " label-str))
               ((riscv) (string-append "bne zero, zero, " label-str))
               ((generic) (string-append "JNE " label-str))
               (else "")))
            ((JZ)
             (case arch
               ((x86) (string-append "jz " label-str))
               ((arm) (string-append "beq " label-str))
               ((riscv) (string-append "beq zero, zero, " label-str))
               ((generic) (string-append "JZ " label-str))
               (else "")))
            ((JNZ)
             (case arch
               ((x86) (string-append "jnz " label-str))
               ((arm) (string-append "bne " label-str))
               ((riscv) (string-append "bne zero, zero, " label-str))
               ((generic) (string-append "JNZ " label-str))
               (else "")))
            ((CALL)
             (case arch
               ((x86) (string-append "call " label-str))
               ((arm) (string-append "bl " label-str))
               ((riscv) (string-append "jal ra, " label-str))
               ((generic) (string-append "CALL " label-str))
               (else "")))
            ((RET)
             (case arch
               ((x86) "ret")
               ((arm) "bx lr")
               ((riscv) "ret")
               ((generic) "RET")
               (else "")))
            (else ""))))))

;; generate-simple: Generate simple instructions (HLT, NOP)
(define (generate-simple instr arch)
  (let ((mnem (instr-mnem instr)))
    (case mnem
      ((HLT)
       (case arch
         ((x86) "hlt")
         ((arm) "bkpt #0")
         ((riscv) "ebreak")
         ((generic) "HLT")
         (else "")))
      ((NOP)
       (case arch
         ((x86) "nop")
         ((arm) "nop")
         ((riscv) "nop")
         ((generic) "NOP")
         (else "")))
      (else ""))))

;; -----------------------------
;; Operand to String
;; -----------------------------

;; operand-to-string: Convert operand to assembly string
(define (operand-to-string operand arch)
  (if (not (operand? operand))
      (error "operand-to-string: expected Operand" operand)
      (cond
       ((oreg? operand)
        (let ((reg (oreg-reg operand)))
          (symbol->string (map-register reg arch))))
       ((oimm? operand)
        (let ((poly (oimm-poly operand))
              (val (poly-to-nat poly)))
          (case arch
            ((x86 arm riscv) (string-append "#" (number->string val)))
            ((generic) (string-append "#" (number->string val)))
            (else (number->string val)))))
       ((omem? operand)
        (let ((base (omem-base operand))
              (offset (omem-offset operand)))
          (case arch
            ((x86) (string-append "[" (symbol->string (map-register base arch))
                                  (if (not (= offset 0))
                                      (string-append " + " (number->string offset))
                                      "") "]"))
            ((arm) (string-append "[" (symbol->string (map-register base arch))
                                   (if (not (= offset 0))
                                       (string-append ", #" (number->string offset))
                                       "")
                                   "]"))
            ((riscv) (string-append (number->string offset) "("
                                     (symbol->string (map-register base arch)) ")"))
            ((generic) (string-append "[" (symbol->string base)
                                       (if (not (= offset 0))
                                           (string-append " + " (number->string offset))
                                           "") "]"))
            (else ""))))
       ((olabel? operand)
        (olabel-label operand))
       (else ""))))

;; -----------------------------
;; Label Resolution
;; -----------------------------

;; resolve-labels: Resolve labels in program
(define (resolve-labels prog)
  (if (not (program? prog))
      (error "resolve-labels: expected Program" prog)
      (let ((labels (program-labels prog))
            (instrs (program-instrs prog)))
        ;; Create label map
        (let ((label-map (make-label-map labels)))
          ;; Process instructions and replace label references
          (let loop ((instrs instrs)
                     (index 0)
                     (result '()))
            (if (null? instrs)
                (reverse result)
                (let ((instr (car instrs))
                      (operands (instr-operands instr)))
                  ;; Check if any operand is a label that needs resolution
                  (let ((new-operands
                         (map (lambda (op)
                                (if (olabel? op)
                                    (let ((label-name (olabel-label op)))
                                      (let ((label-addr (assoc label-name label-map)))
                                        (if label-addr
                                            (make-oimm (nat-to-poly (cdr label-addr)))
                                            op)))
                                    op))
                              operands)))
                    (loop (cdr instrs)
                          (+ index 1)
                          (cons (make-instr (instr-mnem instr) new-operands) result))))))))))

;; make-label-map: Create map from label names to addresses
(define (make-label-map labels)
  (if (not (list? labels))
      '()
      (map (lambda (label)
             (if (pair? label)
                 (cons (car label) (cdr label))
                 label))
           labels)))

;; -----------------------------
;; Memory Layout Generation
;; -----------------------------

;; generate-memory-layout: Generate memory layout directives
(define (generate-memory-layout prog arch)
  (if (not (program? prog))
      (error "generate-memory-layout: expected Program" prog)
      (case arch
        ((x86)
         (string-append ".section .text\n"
                        ".global _start\n"
                        "_start:\n"))
        ((arm)
         (string-append ".section .text\n"
                        ".global _start\n"
                        "_start:\n"))
        ((riscv)
         (string-append ".section .text\n"
                        ".global _start\n"
                        "_start:\n"))
        ((generic)
         (string-append ".section .text\n"
                        ".global start\n"
                        "start:\n"))
        (else ""))))

;; -----------------------------
;; Main Assembly Generation
;; -----------------------------

;; generate-assembly: Generate assembly code from AAL program
(define (generate-assembly prog . rest)
  (if (not (program? prog))
      (error "generate-assembly: expected Program" prog)
      (let ((arch (if (null? rest) (get-target-arch) (car rest))))
        (if (not (architecture? arch))
            (error "generate-assembly: expected architecture" arch)
            (let ((labels (program-labels prog))
                  (instrs (program-instrs prog))
                  (header (generate-memory-layout prog arch))
                  (instructions '()))
              ;; Generate instructions
              (let loop ((instrs instrs)
                         (instr-index 0))
                (if (null? instrs)
                    (let ((instr-strs (reverse instructions)))
                      (string-append header
                                     (string-join
                                      (map (lambda (instr-str)
                                             (if (string? instr-str)
                                                 instr-str
                                                 ""))
                                           instr-strs)
                                      "\n")
                                     "\n"))
                    (let ((instr (car instrs)))
                      ;; Check if there's a label at this position
                      (let ((label-at-pos
                             (let label-check ((labels labels))
                               (if (null? labels)
                                   #f
                                   (if (= (cdar labels) instr-index)
                                       (caar labels)
                                       (label-check (cdr labels)))))))
                        (if label-at-pos
                            (set! instructions (cons (string-append label-at-pos ":") instructions)))
                        (let ((instr-str (generate-instruction instr arch labels)))
                          (set! instructions (cons instr-str instructions))
                          (loop (cdr instrs) (+ instr-index 1))))))))))))

;; Helper: string-join
(define (string-join strings sep)
  (if (null? strings)
      ""
      (if (null? (cdr strings))
          (car strings)
          (string-append (car strings)
                         sep
                         (string-join (cdr strings) sep)))))

;; Helper: string-downcase
(define (string-downcase str)
  (list->string (map char-downcase (string->list str))))

(define (char-downcase ch)
  (if (char-upper-case? ch)
      (integer->char (+ (char->integer ch) 32))
      ch))

(define (char-upper-case? ch)
  (char<=? #\A ch #\Z))

;; ============================================================
;; End of Assembly Generator
;; ============================================================

