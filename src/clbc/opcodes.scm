;; ============================================================
;; CLBC - opcode constants (MVP)
;; ============================================================

;; Record framing
(define OP_BEGIN_RECORD #xF0)
(define OP_END_RECORD   #xF1)

;; Context building
(define OP_CTX_BEGIN #x10)
(define OP_CTX_META  #x11)
(define OP_VTX_DEF   #x12)
(define OP_EDGE_DEF  #x13)
(define OP_FACE_DEF  #x14)
(define OP_KEY_DEF   #x15)
(define OP_CTX_END   #x16)

;; Transition
(define OP_APPLY_BEGIN     #x20)
(define OP_APPLY_COEFF_REF #x21)
(define OP_APPLY_VARS      #x22)
(define OP_APPLY_OUT       #x23)
(define OP_APPLY_END       #x24)

;; Validation
(define OP_CHECKS #x30)
(define OP_RESULT #x31)
(define OP_HASH   #x32)

;; Projection (Fano)
(define OP_PROJ_BEGIN  #x40)
(define OP_PROJ_INPUT  #x41)
(define OP_PROJ_POINTS #x42)
(define OP_PROJ_LINES  #x43)
(define OP_PROJ_END    #x44)

;; Commit
(define OP_COMMIT #x50)

;; Record kinds (BEGIN_RECORD kind phase)
(define KIND_CONTEXT    0)
(define KIND_TRANSITION 1)
(define KIND_VALIDATION 2)
(define KIND_PROJECTION 3)
(define KIND_COMMIT     4)


