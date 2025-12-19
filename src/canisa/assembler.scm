;; CAN-ISA v1.0 Assembler (R5RS Scheme / Guile)
;;
;; Encodes a small subset of CAN-ISA v1.0 bytecode deterministically.
;; Source of truth: dev-docs/Inbox/CanvasL - Final Frontier/10 - CAN-ISA v1.0 — Opcode Table (Normative).md
;;
;; This is intentionally minimal and MCU-friendly:
;; - Little-endian integers
;; - No implicit state outside the instruction stream
;; - Deterministic encoding

(define (u8 x)
  (if (and (integer? x) (<= 0 x) (<= x 255))
      x
      (error "u8: out of range" x)))

(define (u16 x)
  (if (and (integer? x) (<= 0 x) (<= x 65535))
      x
      (error "u16: out of range" x)))

(define (u32 x)
  (if (and (integer? x) (<= 0 x) (<= x 4294967295))
      x
      (error "u32: out of range" x)))

(define (i16 x)
  (if (and (integer? x) (<= -32768 x) (<= x 32767))
      x
      (error "i16: out of range" x)))

(define (i32 x)
  (if (and (integer? x) (<= -2147483648 x) (<= x 2147483647))
      x
      (error "i32: out of range" x)))

(define (u16le x)
  (let ((n (u16 x)))
    (list (logand n #xff)
          (logand (ash n -8) #xff))))

(define (u32le x)
  (let ((n (u32 x)))
    (list (logand n #xff)
          (logand (ash n -8) #xff)
          (logand (ash n -16) #xff)
          (logand (ash n -24) #xff))))

(define (i16le x)
  ;; two's complement
  (let ((n (if (< x 0) (+ x 65536) x)))
    (u16le n)))

(define (i32le x)
  (let ((n (if (< x 0) (+ x 4294967296) x)))
    (u32le n)))

(define *canisa-opcodes*
  '((NOP . #x00)
    (HALT . #x01)
    (TRAP . #x02)
    (DEF_MOD . #x10)
    (TERM_NEW . #x20)
    (TERM_SET_VAR . #x21)
    (TERM_CLR_VAR . #x22)
    (TERM_SET_VARS . #x23)
    (TERM_COPY . #x24)
    (TERM_ZERO . #x25)
    (STATE_ADD . #x30)
    (STATE_SUB . #x31)
    (STATE_MUL . #x32)
    (STATE_CLEAR . #x33)
    (STATE_COPY . #x34)
    (STATE_SIZE . #x35)
    (STATE_NORM . #x40)
    (STATE_SORT . #x41)
    (STATE_PRUNE . #x42)
    (STATE_SEAL . #x43)
    (STATE_MERGE . #x50)
    (STATE_DIFF . #x51)
    (STATE_GCD . #x52)
    (STATE_LCM . #x53)
    (STATE_SERIALIZE . #x60)
    (STATE_HASH . #x61)))

(define (lookup-opcode sym)
  (let ((p (assoc sym *canisa-opcodes*)))
    (if p (cdr p)
        (error "canisa: unknown opcode" sym))))

(define (emit-op sym)
  (list (u8 (lookup-opcode sym))))

(define (assemble-instr instr)
  (if (not (pair? instr))
      (error "canisa: instruction must be a list" instr)
      (let ((op (car instr))
            (args (cdr instr)))
        (cond
         ((eq? op 'NOP)
          (emit-op 'NOP))
         ((eq? op 'HALT)
          (emit-op 'HALT))
         ((eq? op 'TRAP)
          (append (emit-op 'TRAP)
                  (u16le (car args))))
         ((eq? op 'DEF_MOD)
          (let ((mode (car args))
                (p (cadr args)))
            (append (emit-op 'DEF_MOD)
                    (list (u8 mode))
                    (u32le p))))
         ((eq? op 'TERM_NEW)
          (let ((dst (car args))
                (coeff (cadr args))
                (exp2 (caddr args)))
            (append (emit-op 'TERM_NEW)
                    (u16le dst)
                    (i32le (i32 coeff))
                    (i16le (i16 exp2)))))
         ((eq? op 'TERM_SET_VAR)
          (append (emit-op 'TERM_SET_VAR)
                  (u16le (car args))
                  (u16le (cadr args))))
         ((eq? op 'TERM_CLR_VAR)
          (append (emit-op 'TERM_CLR_VAR)
                  (u16le (car args))
                  (u16le (cadr args))))
         ((eq? op 'TERM_ZERO)
          (append (emit-op 'TERM_ZERO)
                  (u16le (car args))))
         ((eq? op 'TERM_COPY)
          (append (emit-op 'TERM_COPY)
                  (u16le (car args))
                  (u16le (cadr args))))
         ((eq? op 'STATE_ADD)
          (append (emit-op 'STATE_ADD)
                  (u16le (car args))))
         ((eq? op 'STATE_CLEAR)
          (emit-op 'STATE_CLEAR))
         ((eq? op 'STATE_COPY)
          (append (emit-op 'STATE_COPY)
                  (u16le (car args))
                  (u16le (cadr args))))
         ((eq? op 'STATE_NORM)
          (append (emit-op 'STATE_NORM)
                  (list (u8 (car args)))))
         ((eq? op 'STATE_GCD)
          (append (emit-op 'STATE_GCD)
                  (u16le (car args))))
         ((eq? op 'STATE_LCM)
          (append (emit-op 'STATE_LCM)
                  (u16le (car args))))
         ((eq? op 'STATE_HASH)
          (append (emit-op 'STATE_HASH)
                  (list (u8 (car args)))
                  (u16le (cadr args))))
         (else
          (error "canisa: unsupported instruction in MVP assembler" instr))))))

(define (assemble-program program)
  (if (not (list? program))
      (error "canisa: program must be a list" program)
      (let loop ((xs program) (out '()))
        (if (null? xs)
            (reverse out)
            (loop (cdr xs) (append (reverse (assemble-instr (car xs))) out))))))

;; CANBC container format (MVP)
;;
;; bytes:
;;   magic  : "CANBC" 0x00  (6 bytes)
;;   version: u16le (1)
;;   length : u32le payload length
;;   payload: CAN-ISA bytecode bytes
(define (canbc-wrap payload)
  (if (not (list? payload))
      (error "canbc-wrap: expected byte list" payload)
      (let ((magic (list (char->integer #\C)
                         (char->integer #\A)
                         (char->integer #\N)
                         (char->integer #\B)
                         (char->integer #\C)
                         0)))
        (append magic
                (u16le 1)
                (u32le (length payload))
                payload)))
)
