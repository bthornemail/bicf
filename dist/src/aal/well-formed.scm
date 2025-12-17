;; ============================================================
;; AAL Well-Formedness Judgments (R5RS Scheme)
;; Implements well-formedness checks
;; Source: AAL Spec Section 5
;; ============================================================

(load "ast.scm")

;; -----------------------------
;; Context (Gamma)
;; -----------------------------

;; Context: Contains label definitions
;; Represented as alist: ((label-name . instruction-index) ...)
(define (make-context labels)
  (if (not (list? labels))
      (error "make-context: expected list" labels)
      labels))

(define (context? x)
  (and (list? x)
       (or (null? x)
           (and (pair? x)
                (pair? (car x))
                (string? (caar x))
                (integer? (cdar x))))))

;; context-has-label: Check if context contains label
(define (context-has-label ctx label-name)
  (if (not (context? ctx))
      (error "context-has-label: expected Context" ctx)
      (if (not (string? label-name))
          (error "context-has-label: expected string" label-name)
          (assoc label-name ctx))))

;; -----------------------------
;; Operand Well-Formedness
;; -----------------------------

;; wf-operand: Well-formedness judgment for operands
(define (wf-operand ctx operand)
  (if (not (context? ctx))
      (error "wf-operand: expected Context" ctx)
      (if (not (operand? operand))
          (error "wf-operand: expected Operand" operand)
          (cond
           ((oreg? operand) #t)
           ((oimm? operand) #t)
           ((omem? operand) #t)
           ((olabel? operand)
            (let ((label-name (olabel-label operand)))
              (if (context-has-label ctx label-name)
                  #t
                  #f)))
           (else #f)))))

;; -----------------------------
;; Instruction Well-Formedness
;; -----------------------------

;; wf-instr: Well-formedness judgment for instructions
(define (wf-instr ctx instr)
  (if (not (context? ctx))
      (error "wf-instr: expected Context" ctx)
      (if (not (instr? instr))
          (error "wf-instr: expected Instr" instr)
          (let ((mnem (instr-mnem instr))
                (operands (instr-operands instr))
                (expected-arity (mnemonic-arity mnem)))
            (if (not (= (length operands) expected-arity))
                #f
                ;; Check all operands are well-formed
                (let loop ((ops operands))
                  (if (null? ops)
                      #t
                      (if (wf-operand ctx (car ops))
                          (loop (cdr ops))
                          #f))))))))

;; -----------------------------
;; Program Well-Formedness
;; -----------------------------

;; no-duplicate-labels: Check for duplicate labels in program
(define (no-duplicate-labels prog)
  (if (not (program? prog))
      (error "no-duplicate-labels: expected Program" prog)
      (let ((labels (program-labels prog)))
        (let loop ((seen '())
                   (remaining labels))
          (if (null? remaining)
              #t
              (let ((label-name (caar remaining)))
                (if (memq label-name seen)
                    #f
                    (loop (cons label-name seen)
                          (cdr remaining)))))))))

;; wf-program: Well-formedness judgment for programs
(define (wf-program prog)
  (if (not (program? prog))
      (error "wf-program: expected Program" prog)
      (if (not (no-duplicate-labels prog))
          #f
          (let ((ctx (make-context (program-labels prog)))
                (instrs (program-instrs prog)))
            (let loop ((instrs instrs))
              (if (null? instrs)
                  #t
                  (if (wf-instr ctx (car instrs))
                      (loop (cdr instrs))
                      #f)))))))

;; -----------------------------
;; Label Resolution
;; -----------------------------

;; resolve-label: Resolve label to instruction index
(define (resolve-label ctx label-name)
  (if (not (context? ctx))
      (error "resolve-label: expected Context" ctx)
      (if (not (string? label-name))
          (error "resolve-label: expected string" label-name)
          (let ((label-entry (context-has-label ctx label-name)))
            (if label-entry
                (cdr label-entry)
                (error "resolve-label: label not found" label-name))))))

;; -----------------------------
;; Validation Helpers
;; -----------------------------

;; validate-program: Complete validation (well-formedness + labels)
(define (validate-program prog)
  (if (not (program? prog))
      (error "validate-program: expected Program" prog)
      (let ((wf-result (wf-program prog)))
        (if (not wf-result)
            #f
            (let ((labels (program-labels prog)))
              (if (null? labels)
                  #t
                  ;; Check all labels are valid strings
                  (let loop ((labels labels))
                    (if (null? labels)
                        #t
                        (if (string? (caar labels))
                            (loop (cdr labels))
                            #f)))))))))

;; ============================================================
;; End of Well-Formedness Judgments
;; ============================================================

