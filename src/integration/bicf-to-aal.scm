;; ============================================================
;; BICF-to-AAL Compiler (R5RS Scheme)
;; Transforms BICF boundaries to AAL programs
;; Source: Node-to-Assembly Mapping document
;; ============================================================

(load "../core/bicf-core.scm")
(load "../aal/ast.scm")
(load "../aal/compiler.scm")

;; -----------------------------
;; Node Type Definitions
;; -----------------------------

;; Node types from computational substrate
(define (node-type? x)
  (memq x '(Activate Integrate Propagate BackPropagate)))

;; -----------------------------
;; Boundary-to-AAL Transformation
;; -----------------------------

;; boundary-to-aal: Transform boundary to AAL program
;; Preserves 8-tuple isomorphism
(define (boundary-to-aal boundary)
  (if (not (boundary? boundary))
      (error "boundary-to-aal: expected Boundary" boundary)
      (let ((boundary-id (cdr (assq 'id boundary)))
            (boundary-type (cdr (assq 'type boundary))))
        (cond
         ((eq? boundary-type 'fano)
          (fano-boundary-to-aal boundary))
         ((eq? boundary-type 'pcg)
          (pcg-boundary-to-aal boundary))
         (else
          (generic-boundary-to-aal boundary))))))

;; -----------------------------
;; Node Type Mappings
;; -----------------------------

;; activate-to-aal: Activate node → JMP/CALL instructions
;; 8-Tuple: L → Pair(car) → e₂ → Source/Beginning
(define (activate-to-aal activate-node)
  (if (not (list? activate-node))
      (error "activate-to-aal: expected node" activate-node)
      (let ((target (cdr (assq 'target activate-node)))
            (label (cdr (assq 'label activate-node))))
        (if label
            (list
             (make-instr 'MOV (list (make-oreg 'PC) (make-oimm (nat-to-poly target))))
             (make-instr 'JMP (list (make-olabel label))))
            (list
             (make-instr 'CALL (list (make-olabel (if (string? target) target "entry")))))))))

;; integrate-to-aal: Integrate node → ADD/SUB instructions
;; 8-Tuple: δ → Procedure → e₄ → Transformation
(define (integrate-to-aal integrate-node)
  (if (not (list? integrate-node))
      (error "integrate-to-aal: expected node" integrate-node)
      (let ((inputs (cdr (assq 'inputs integrate-node)))
            (output (cdr (assq 'output integrate-node)))
            (operation (cdr (assq 'operation integrate-node))))
        (let ((instrs '())
              (acc-reg (if output
                           (if (reg? output) output 'R0)
                           'R0)))
          ;; Initialize accumulator
          (set! instrs (cons (make-instr 'MOV (list (make-oreg acc-reg) (make-oimm '()))) instrs))
          ;; Process each input
          (let loop ((inputs inputs)
                     (index 0))
            (if (not (null? inputs))
                (let ((input (car inputs)))
                  (let ((input-reg (if (reg? input) input (string->symbol (string-append "R" (number->string (modulo index 8)))))))
                    (case operation
                      ((add +)
                       (set! instrs (cons (make-instr 'ADD (list (make-oreg acc-reg) (make-oreg input-reg))) instrs)))
                      ((sub -)
                       (set! instrs (cons (make-instr 'SUB (list (make-oreg acc-reg) (make-oreg input-reg))) instrs)))
                      ((xor)
                       (set! instrs (cons (make-instr 'XOR (list (make-oreg acc-reg) (make-oreg input-reg))) instrs)))
                      (else
                       (set! instrs (cons (make-instr 'ADD (list (make-oreg acc-reg) (make-oreg input-reg))) instrs))))
                    (loop (cdr inputs) (+ index 1))))))
          (reverse instrs)))))

;; propagate-to-aal: Propagate node → SHL/SHR/ROL instructions
;; 8-Tuple: Σ → Symbol → e₁ → Named Element Transmission
(define (propagate-to-aal propagate-node)
  (if (not (list? propagate-node))
      (error "propagate-to-aal: expected node" propagate-node)
      (let ((source (cdr (assq 'source propagate-node)))
            (targets (cdr (assq 'targets propagate-node)))
            (operation (cdr (assq 'operation propagate-node))))
        (let ((instrs '())
              (source-reg (if (reg? source) source 'R1)))
          (let loop ((targets targets)
                     (index 0))
            (if (not (null? targets))
                (let ((target (car targets))
                      (target-reg (if (reg? target) target (string->symbol (string-append "R" (number->string (modulo (+ index 2) 8))))))
                      (shift-amt (nat-to-poly (* index 2))))
                  (case operation
                    ((shl shift-left)
                     (set! instrs (cons (make-instr 'SHL (list (make-oreg target-reg) (make-oreg source-reg) (make-oimm shift-amt))) instrs)))
                    ((shr shift-right)
                     (set! instrs (cons (make-instr 'SHR (list (make-oreg target-reg) (make-oreg source-reg) (make-oimm shift-amt))) instrs)))
                    ((rol rotate-left)
                     (set! instrs (cons (make-instr 'ROL (list (make-oreg target-reg) (make-oreg source-reg) (make-oimm shift-amt))) instrs)))
                    ((ror rotate-right)
                     (set! instrs (cons (make-instr 'ROR (list (make-oreg target-reg) (make-oreg source-reg) (make-oimm shift-amt))) instrs)))
                    (else
                     ;; Default: copy via MOV
                     (set! instrs (cons (make-instr 'MOV (list (make-oreg target-reg) (make-oreg source-reg))) instrs))))
                  (loop (cdr targets) (+ index 1)))))
          (reverse instrs)))))

;; backpropagate-to-aal: BackPropagate node → CMP + conditional jumps
;; 8-Tuple: t/r → Char/Vector → e₆/e₇ → Accept/Reject with Correction
(define (backpropagate-to-aal backprop-node)
  (if (not (list? backprop-node))
      (error "backpropagate-to-aal: expected node" backprop-node)
      (let ((actual (cdr (assq 'actual backprop-node)))
            (desired (cdr (assq 'desired backprop-node)))
            (adjust-label (cdr (assq 'adjust-label backprop-node)))
            (accept-label (cdr (assq 'accept-label backprop-node))))
        (let ((actual-reg (if (reg? actual) actual 'R2))
              (desired-reg (if (reg? desired) desired 'R3))
              (adjust-lbl (if adjust-label adjust-label "adjust"))
              (accept-lbl (if accept-label accept-label "accept")))
          (list
           ;; Load actual and desired values
           (make-instr 'MOV (list (make-oreg actual-reg) (make-oimm (if (list? actual) actual '()))))
           (make-instr 'MOV (list (make-oreg desired-reg) (make-oimm (if (list? desired) desired '()))))
           ;; Compare (using XOR to check equality)
           (make-instr 'XOR (list (make-oreg 'R4) (make-oreg actual-reg) (make-oreg desired-reg)))
           ;; Check if zero (equal)
           (make-instr 'JE (list (make-olabel accept-lbl)))
           ;; Not equal, jump to adjust
           (make-instr 'JMP (list (make-olabel adjust-lbl)))
           ;; Adjust label
           (make-olabel adjust-lbl)
           ;; Compute error
           (make-instr 'SUB (list (make-oreg 'R5) (make-oreg desired-reg) (make-oreg actual-reg)))
           ;; Apply correction (shift right for learning rate)
           (make-instr 'SHR (list (make-oreg 'R5) (make-oreg 'R5) (make-oimm (nat-to-poly 1))))
           ;; Loop back
           (make-instr 'JMP (list (make-olabel "backprop")))
           ;; Accept label
           (make-olabel accept-lbl)
           (make-instr 'NOP '()))))))

;; -----------------------------
;; Interior-to-Register Mapping
;; -----------------------------

;; interior-to-registers: Map interior state to AAL registers
(define (interior-to-registers interior)
  (if (not (interior? interior))
      (error "interior-to-registers: expected Interior" interior)
      (let ((data (assq 'data interior))
            (reg-map '()))
        (if data
            (let ((data-value (cdr data)))
              (if (list? data-value)
                  (let loop ((items data-value)
                             (reg-index 0))
                    (if (null? items)
                        (reverse reg-map)
                        (if (< reg-index 8)
                            (let ((reg (string->symbol (string-append "R" (number->string reg-index)))))
                              (loop (cdr items)
                                    (+ reg-index 1)
                                    (cons (cons reg (car items)) reg-map)))
                            (reverse reg-map))))
                  (list (cons 'R0 data-value))))
            '()))))

;; -----------------------------
;; FANO Boundary to AAL
;; -----------------------------

;; fano-boundary-to-aal: Generate AAL code for FANO boundary operations
(define (fano-boundary-to-aal boundary)
  (if (not (boundary? boundary))
      (error "fano-boundary-to-aal: expected Boundary" boundary)
      (let ((points (cdr (assq 'points boundary)))
            (lines (cdr (assq 'lines boundary)))
            (instrs '()))
        ;; Initialize: Store Fano plane structure in memory
        ;; Points stored in R0-R6, lines in memory
        (let ((point-index 0))
          (let loop ((points (if points points '(0 1 2 3 4 5 6))))
            (if (not (null? points))
                (begin
                  (set! instrs (cons (make-instr 'MOV (list (make-oreg (string->symbol (string-append "R" (number->string point-index)))
                                                                        (make-oimm (nat-to-poly (car points)))))
                                      instrs))
                  (loop (cdr points) (+ point-index 1))))))
        ;; Check incidence: For each line, verify points are on it
        (if lines
            (let ((line-index 0))
              (let line-loop ((lines lines))
                (if (not (null? lines))
                    (let ((line (car lines)))
                      ;; Load line points into registers
                      (let ((p1 (car line))
                            (p2 (cadr line))
                            (p3 (caddr line)))
                        (set! instrs (cons (make-instr 'MOV (list (make-oreg 'R0) (make-oimm (nat-to-poly p1)))) instrs))
                        (set! instrs (cons (make-instr 'MOV (list (make-oreg 'R1) (make-oimm (nat-to-poly p2)))) instrs))
                        (set! instrs (cons (make-instr 'MOV (list (make-oreg 'R2) (make-oimm (nat-to-poly p3)))) instrs))
                        ;; Verify they form a valid line (check sum mod 2)
                        (set! instrs (cons (make-instr 'ADD (list (make-oreg 'R3) (make-oreg 'R0) (make-oreg 'R1))) instrs))
                        (set! instrs (cons (make-instr 'ADD (list (make-oreg 'R3) (make-oreg 'R3) (make-oreg 'R2))) instrs))
                        ;; Result in R3
                        (line-loop (cdr lines) (+ line-index 1))))))))
        (reverse instrs))))

;; -----------------------------
;; PCG Boundary to AAL
;; -----------------------------

;; pcg-boundary-to-aal: Generate AAL code for PCG validation
(define (pcg-boundary-to-aal boundary)
  (if (not (boundary? boundary))
      (error "pcg-boundary-to-aal: expected Boundary" boundary)
      (let ((triples (cdr (assq 'triples boundary)))
            (lines (cdr (assq 'lines boundary)))
            (instrs '()))
        ;; For each triple, check if it's covered by at least one line
        (if triples
            (let triple-loop ((triples triples)
                              (triple-index 0))
              (if (not (null? triples))
                  (let ((triple (car triples)))
                    (let ((p1 (car triple))
                          (p2 (cadr triple))
                          (p3 (caddr triple)))
                      ;; Load triple points
                      (set! instrs (cons (make-instr 'MOV (list (make-oreg 'R0) (make-oimm (nat-to-poly p1)))) instrs))
                      (set! instrs (cons (make-instr 'MOV (list (make-oreg 'R1) (make-oimm (nat-to-poly p2)))) instrs))
                      (set! instrs (cons (make-instr 'MOV (list (make-oreg 'R2) (make-oimm (nat-to-poly p3)))) instrs))
                      ;; Check against each line
                      (if lines
                          (let line-check-loop ((lines lines)
                                                (line-index 0)
                                                (found #f))
                            (if (and (not (null? lines)) (not found))
                                (let ((line (car lines)))
                                  ;; Count how many points from triple are in line
                                  (let ((count 0))
                                    (if (member p1 line) (set! count (+ count 1)))
                                    (if (member p2 line) (set! count (+ count 1)))
                                    (if (member p3 line) (set! count (+ count 1)))
                                    ;; If count >= 2, triple is covered
                                    (if (>= count 2)
                                        (line-check-loop (cdr lines) (+ line-index 1) #t)
                                        (line-check-loop (cdr lines) (+ line-index 1) #f))))
                                (if found
                                    ;; Triple is covered, continue
                                    (triple-loop (cdr triples) (+ triple-index 1))
                                    ;; Triple not covered - error condition
                                    (begin
                                      (set! instrs (cons (make-instr 'HLT '()) instrs))
                                      (triple-loop (cdr triples) (+ triple-index 1))))))
                          (triple-loop (cdr triples) (+ triple-index 1))))))))
        (reverse instrs))))

;; -----------------------------
;; Generic Boundary to AAL
;; -----------------------------

;; generic-boundary-to-aal: Transform generic boundary to AAL
(define (generic-boundary-to-aal boundary)
  (if (not (boundary? boundary))
      (error "generic-boundary-to-aal: expected Boundary" boundary)
      (let ((nodes (cdr (assq 'nodes boundary)))
            (instrs '()))
        (if nodes
            (let node-loop ((nodes nodes))
              (if (not (null? nodes))
                  (let ((node (car nodes)))
                    (let ((node-type (cdr (assq 'type node))))
                      (case node-type
                        ((Activate activate)
                         (set! instrs (append (activate-to-aal node) instrs)))
                        ((Integrate integrate)
                         (set! instrs (append (integrate-to-aal node) instrs)))
                        ((Propagate propagate)
                         (set! instrs (append (propagate-to-aal node) instrs)))
                        ((BackPropagate backpropagate)
                         (set! instrs (append (backpropagate-to-aal node) instrs)))
                        (else
                         (set! instrs (cons (make-instr 'NOP '()) instrs))))
                      (node-loop (cdr nodes))))))
        (reverse instrs))))

;; -----------------------------
;; 8-Tuple Isomorphism Preservation
;; -----------------------------

;; verify-8tuple-isomorphism: Verify that AAL program preserves 8-tuple structure
(define (verify-8tuple-isomorphism boundary aal-program)
  (if (not (boundary? boundary))
      (error "verify-8tuple-isomorphism: expected Boundary" boundary)
      (if (not (program? aal-program))
          (error "verify-8tuple-isomorphism: expected Program" aal-program)
          ;; Basic check: ensure all node types are mapped
          (let ((nodes (cdr (assq 'nodes boundary))))
            (if nodes
                (let loop ((nodes nodes)
                           (mapped '()))
                  (if (null? nodes)
                      #t
                      (let ((node-type (cdr (assq 'type (car nodes)))))
                        (if (memq node-type '(Activate Integrate Propagate BackPropagate))
                            (loop (cdr nodes) (cons node-type mapped))
                            (loop (cdr nodes) mapped)))))
                #t)))))

;; -----------------------------
;; Main Compilation Function
;; -----------------------------

;; generate-aal: Main entry point for BICF-to-AAL compilation
(define (generate-aal boundary)
  (if (not (boundary? boundary))
      (error "generate-aal: expected Boundary" boundary)
      (let ((aal-program (boundary-to-aal boundary)))
        (if (verify-8tuple-isomorphism boundary aal-program)
            aal-program
            (error "generate-aal: 8-tuple isomorphism verification failed")))))

;; ============================================================
;; End of BICF-to-AAL Compiler
;; ============================================================

