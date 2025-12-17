;; ============================================================
;; AAL Register Allocation (R5RS Scheme)
;; Register allocation algorithm with spilling and optimization
;; ============================================================

(load "ast.scm")

;; -----------------------------
;; Register Allocation State
;; -----------------------------

;; Available AAL registers
(define *aal-registers* '(R0 R1 R2 R3 R4 R5 R6 R7))

;; Register allocation state
(define (make-reg-alloc-state)
  (list 'RegAllocState
        '()  ;; allocated: ((var . reg) ...)
        '()  ;; free: list of available registers
        *aal-registers*))  ;; all registers

(define (reg-alloc-state? x)
  (and (list? x)
       (= (length x) 4)
       (eq? (car x) 'RegAllocState)))

(define (reg-alloc-allocated state)
  (if (reg-alloc-state? state)
      (cadr state)
      (error "reg-alloc-allocated: expected RegAllocState" state)))

(define (reg-alloc-free state)
  (if (reg-alloc-state? state)
      (caddr state)
      (error "reg-alloc-free: expected RegAllocState" state)))

(define (reg-alloc-all-regs state)
  (if (reg-alloc-state? state)
      (cadddr state)
      (error "reg-alloc-all-regs: expected RegAllocState" state)))

;; -----------------------------
;; Variable Tracking
;; -----------------------------

;; Variable: represents a value that needs a register
(define (make-var name)
  (list 'Var name))

(define (var? x)
  (and (list? x)
       (= (length x) 2)
       (eq? (car x) 'Var)))

(define (var-name var)
  (if (var? var)
      (cadr var)
      (error "var-name: expected Var" var)))

;; -----------------------------
;; Live Range Analysis
;; -----------------------------

;; Live range: (var start-instr end-instr)
(define (make-live-range var start end)
  (list 'LiveRange var start end))

(define (live-range? x)
  (and (list? x)
       (= (length x) 4)
       (eq? (car x) 'LiveRange)))

(define (live-range-var lr)
  (if (live-range? lr)
      (cadr lr)
      (error "live-range-var: expected LiveRange" lr)))

(define (live-range-start lr)
  (if (live-range? lr)
      (caddr lr)
      (error "live-range-start: expected LiveRange" lr)))

(define (live-range-end lr)
  (if (live-range? lr)
      (cadddr lr)
      (error "live-range-end: expected LiveRange" lr)))

;; Compute live ranges from program
(define (compute-live-ranges prog)
  (if (not (program? prog))
      (error "compute-live-ranges: expected Program" prog)
      (let ((instrs (program-instrs prog))
            (ranges '()))
        ;; Simple analysis: track variable usage
        ;; In full implementation, would do proper liveness analysis
        (let loop ((instrs instrs)
                   (index 0)
                   (var-map '()))
          (if (null? instrs)
              (reverse ranges)
              (let ((instr (car instrs))
                    (operands (instr-operands instr)))
                ;; Track variables in operands
                (let op-loop ((ops operands)
                              (new-ranges ranges))
                  (if (null? ops)
                      (loop (cdr instrs) (+ index 1) var-map)
                      (let ((op (car ops)))
                        (if (oreg? op)
                            (let ((reg (oreg-reg op)))
                              (let ((var (make-var (symbol->string reg))))
                                (let ((existing (assoc var var-map)))
                                  (if existing
                                      ;; Update end
                                      (op-loop (cdr ops)
                                               (map (lambda (lr)
                                                      (if (eq? (live-range-var lr) var)
                                                          (make-live-range var
                                                                           (live-range-start lr)
                                                                           index)
                                                          lr))
                                                    new-ranges))
                                      ;; New range
                                      (op-loop (cdr ops)
                                               (cons (make-live-range var index index)
                                                     new-ranges)
                                               (cons (cons var index) var-map))))))
                            (op-loop (cdr ops) new-ranges))))))))))))

;; -----------------------------
;; Register Allocation Algorithm
;; -----------------------------

;; allocate-register: Allocate a register for a variable
(define (allocate-register var state)
  (if (not (var? var))
      (error "allocate-register: expected Var" var)
      (if (not (reg-alloc-state? state))
          (error "allocate-register: expected RegAllocState" state)
          (let ((allocated (reg-alloc-allocated state))
                (free (reg-alloc-free state)))
            ;; Check if already allocated
            (let ((existing (assoc var allocated)))
              (if existing
                  (cdr existing)
                  ;; Need to allocate
                  (if (not (null? free))
                      (let ((reg (car free)))
                        ;; Update state
                        (set! state (list 'RegAllocState
                                          (cons (cons var reg) allocated)
                                          (cdr free)
                                          (reg-alloc-all-regs state)))
                        reg)
                      ;; No free registers - need to spill
                      (spill-and-allocate var state))))))))

;; spill-and-allocate: Spill a register and allocate for new variable
(define (spill-and-allocate var state)
  (if (not (var? var))
      (error "spill-and-allocate: expected Var" var)
      (if (not (reg-alloc-state? state))
          (error "spill-and-allocate: expected RegAllocState" state)
          (let ((allocated (reg-alloc-allocated state)))
            (if (null? allocated)
                (error "spill-and-allocate: no registers to spill")
                ;; Spill least recently used (simple heuristic)
                (let ((to-spill (car allocated)))
                  (let ((spilled-reg (cdr to-spill)))
                    ;; Remove from allocated, add to free
                    (set! state (list 'RegAllocState
                                      (cdr allocated)
                                      (cons spilled-reg (reg-alloc-free state))
                                      (reg-alloc-all-regs state)))
                    ;; Allocate for new variable
                    (allocate-register var state))))))))

;; -----------------------------
;; Register Spilling
;; -----------------------------

;; spill-register: Spill a register to memory
(define (spill-register reg offset)
  (if (not (reg? reg))
      (error "spill-register: expected Reg" reg)
      (if (not (integer? offset))
          (error "spill-register: expected integer" offset)
          (list 'Spill reg offset))))

(define (spill? x)
  (and (list? x)
       (= (length x) 3)
       (eq? (car x) 'Spill)))

;; generate-spill-code: Generate assembly code for spilling
(define (generate-spill-code spill arch)
  (if (not (spill? spill))
      (error "generate-spill-code: expected Spill" spill)
      (let ((reg (cadr spill))
            (offset (caddr spill)))
        (case arch
          ((x86)
           (string-append "mov [esp + " (number->string offset) "], "
                          (symbol->string reg)))
          ((arm)
           (string-append "str " (symbol->string reg) ", [sp, #"
                          (number->string offset) "]"))
          ((riscv)
           (string-append "sw " (symbol->string reg) ", "
                          (number->string offset) "(sp)"))
          ((generic)
           (string-append "ST [SP + " (number->string offset) "], "
                          (symbol->string reg)))
          (else "")))))

;; generate-reload-code: Generate assembly code for reloading
(define (generate-reload-code spill arch)
  (if (not (spill? spill))
      (error "generate-reload-code: expected Spill" spill)
      (let ((reg (cadr spill))
            (offset (caddr spill)))
        (case arch
          ((x86)
           (string-append "mov " (symbol->string reg) ", [esp + "
                          (number->string offset) "]"))
          ((arm)
           (string-append "ldr " (symbol->string reg) ", [sp, #"
                          (number->string offset) "]"))
          ((riscv)
           (string-append "lw " (symbol->string reg) ", "
                          (number->string offset) "(sp)"))
          ((generic)
           (string-append "LD " (symbol->string reg) ", [SP + "
                          (number->string offset) "]"))
          (else "")))))

;; -----------------------------
;; Register Optimization
;; -----------------------------

;; optimize-register-usage: Optimize register allocation
(define (optimize-register-usage prog)
  (if (not (program? prog))
      (error "optimize-register-usage: expected Program" prog)
      (let ((live-ranges (compute-live-ranges prog))
            (state (make-reg-alloc-state)))
        ;; Allocate registers based on live ranges
        ;; Sort by start time
        (let ((sorted-ranges
               (sort live-ranges
                     (lambda (lr1 lr2)
                       (< (live-range-start lr1)
                          (live-range-start lr2))))))
          (let loop ((ranges sorted-ranges)
                     (allocations '()))
            (if (null? ranges)
                allocations
                (let ((lr (car ranges))
                      (var (live-range-var lr)))
                  (let ((reg (allocate-register var state)))
                    (loop (cdr ranges)
                          (cons (cons var reg) allocations))))))))))

;; Helper: sort (simple insertion sort)
(define (sort lst cmp)
  (if (null? lst)
      '()
      (let insert ((item (car lst))
                   (sorted '())
                   (remaining (cdr lst)))
        (if (null? sorted)
            (if (null? remaining)
                (list item)
                (insert (car remaining) (list item) (cdr remaining)))
            (if (cmp item (car sorted))
                (if (null? remaining)
                    (cons item sorted)
                    (insert (car remaining) (cons item sorted) (cdr remaining)))
                (if (null? (cdr sorted))
                    (if (null? remaining)
                        (cons (car sorted) (cons item '()))
                        (insert (car remaining)
                                (cons (car sorted) (cons item '()))
                                (cdr remaining)))
                    (insert item (cdr sorted) remaining))))))))

;; -----------------------------
;; AAL Register Constraints
;; -----------------------------

;; check-register-constraints: Check if allocation satisfies AAL constraints
(define (check-register-constraints allocations)
  (if (not (list? allocations))
      (error "check-register-constraints: expected list" allocations)
      (let ((used-regs '()))
        (let loop ((allocs allocations))
          (if (null? allocs)
              #t
              (let ((reg (cdar allocs)))
                (if (memq reg used-regs)
                    #f  ;; Conflict: same register used twice
                    (begin
                      (set! used-regs (cons reg used-regs))
                      (loop (cdr allocs))))))))))

;; -----------------------------
;; Main Register Allocation Function
;; -----------------------------

;; allocate-registers: Main register allocation function
(define (allocate-registers prog)
  (if (not (program? prog))
      (error "allocate-registers: expected Program" prog)
      (let ((allocations (optimize-register-usage prog)))
        (if (check-register-constraints allocations)
            allocations
            (error "allocate-registers: constraint violation")))))

;; ============================================================
;; End of Register Allocation
;; ============================================================

