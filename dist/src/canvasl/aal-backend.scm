;; ============================================================
;; CanvasL-AAL Bridge (R5RS Scheme)
;; AAL backend for CanvasL interpreter
;; ============================================================

(load "../aal/interpreter.scm")
(load "../aal/compiler.scm")
(load "../integration/bicf-to-aal.scm")

;; -----------------------------
;; CanvasL to AAL Transformation
;; -----------------------------

;; canvasl-to-aal: Transform CanvasL operations to AAL
(define (canvasl-to-aal canvasl-expr)
  (if (not (list? canvasl-expr))
      (error "canvasl-to-aal: expected list" canvasl-expr)
      (let ((expr-type (cdr (assq 'type canvasl-expr)))
            (function (cdr (assq 'function canvasl-expr)))
            (expression (cdr (assq 'expression canvasl-expr)))
            (args (cdr (assq 'args canvasl-expr))))
        (cond
         ;; R5RS function call
         ((and function (string-prefix? function "r5rs:"))
          (r5rs-function-to-aal function args))
         ;; Scheme expression
         (expression
          (scheme-expression-to-aal expression))
         ;; Direct AAL instruction
         ((eq? expr-type 'aal)
          (cdr (assq 'instruction canvasl-expr)))
         ;; Default: try to compile as AAL program
         (else
          (compile (if (string? canvasl-expr)
                       canvasl-expr
                       (canvasl-expr-to-string canvasl-expr))))))))

;; r5rs-function-to-aal: Map R5RS functions to AAL instructions
(define (r5rs-function-to-aal function-name args)
  (let ((func-name (substring function-name 5)))  ;; Remove "r5rs:" prefix
    (cond
     ((string=? func-name "church-add")
      ;; Church addition → AAL ADD
      (if (and (>= (length args) 2)
               (list? args))
          (list (make-instr 'ADD (list (make-oreg 'R0)
                                       (make-oimm (nat-to-poly (car args)))
                                       (make-oimm (nat-to-poly (cadr args))))))
          '()))
     ((string=? func-name "church-mul")
      ;; Church multiplication → AAL MUL (via repeated ADD)
      (if (and (>= (length args) 2)
               (list? args))
          (let ((instrs '())
                (a (car args))
                (b (cadr args)))
            (let loop ((i 0))
              (if (< i b)
                  (begin
                    (set! instrs (cons (make-instr 'ADD (list (make-oreg 'R0)
                                                              (make-oreg 'R0)
                                                              (make-oimm (nat-to-poly a)))) instrs))
                    (loop (+ i 1)))
                  (reverse instrs))))
          '()))
     (else
      ;; Unknown function - return NOP
      (list (make-instr 'NOP '()))))))

;; scheme-expression-to-aal: Compile Scheme expression to AAL
(define (scheme-expression-to-aal expr)
  (if (not (string? expr))
      (error "scheme-expression-to-aal: expected string" expr)
      ;; For now, try to parse as AAL directly
      ;; In full implementation, would parse Scheme and compile
      (compile expr)))

;; canvasl-expr-to-string: Convert CanvasL expression to AAL string
(define (canvasl-expr-to-string expr)
  (if (string? expr)
      expr
      (if (list? expr)
          (let ((mnemonic (cdr (assq 'mnemonic expr)))
                (operands (cdr (assq 'operands expr))))
            (if mnemonic
                (let ((operand-strs
                       (map (lambda (op)
                              (cond
                               ((reg? op) (symbol->string op))
                               ((integer? op) (number->string op))
                               ((string? op) op)
                               (else "")))
                            operands)))
                  (string-append (symbol->string mnemonic) " "
                                  (string-join operand-strs ", ")))
                ""))
          "")))

;; Helper: string-prefix?
(define (string-prefix? str prefix)
  (if (and (string? str) (string? prefix))
      (let ((str-len (string-length str))
            (prefix-len (string-length prefix)))
        (if (>= str-len prefix-len)
            (string=? (substring str 0 prefix-len) prefix)
            #f))
      #f))

;; Helper: substring
(define (substring str start . rest)
  (if (not (string? str))
      (error "substring: expected string" str)
      (if (not (integer? start))
          (error "substring: expected integer" start)
          (let ((end (if (null? rest)
                         (string-length str)
                         (car rest))))
            (if (not (integer? end))
                (error "substring: expected integer" end)
                (let ((len (string-length str)))
                  (if (or (< start 0) (> start len) (< end start) (> end len))
                      (error "substring: index out of bounds" (list start end))
                      (let loop ((i start)
                                 (result '()))
                        (if (>= i end)
                            (list->string (reverse result))
                            (loop (+ i 1)
                                  (cons (string-ref str i) result)))))))))))

;; Helper: string-join
(define (string-join strings sep)
  (if (null? strings)
      ""
      (if (null? (cdr strings))
          (car strings)
          (string-append (car strings)
                         sep
                         (string-join (cdr strings) sep)))))

;; -----------------------------
;; AAL Backend for CanvasL Execution
;; -----------------------------

;; execute-canvasl-with-aal: Execute CanvasL with AAL backend
(define (execute-canvasl-with-aal canvasl-program)
  (if (not (list? canvasl-program))
      (error "execute-canvasl-with-aal: expected list" canvasl-program)
      (let ((aal-program (canvasl-to-aal canvasl-program))
            (result (interpret (if (program? aal-program)
                                   (program-to-string aal-program)
                                   ""))))
        result)))

;; program-to-string: Convert AAL program to string
(define (program-to-string prog)
  (if (not (program? prog))
      (error "program-to-string: expected Program" prog)
      (let ((instrs (program-instrs prog)))
        (string-join
         (map (lambda (instr)
                (let ((mnem (instr-mnem instr))
                      (ops (instr-operands instr)))
                  (string-append (symbol->string mnem) " "
                                  (string-join
                                   (map (lambda (op)
                                          (cond
                                           ((oreg? op) (symbol->string (oreg-reg op)))
                                           ((oimm? op) (string-append "#" (number->string (poly-to-nat (oimm-poly op)))))
                                           ((olabel? op) (olabel-label op))
                                           (else "")))
                                        ops)
                                   ", "))))
              instrs)
         "\n"))))

;; -----------------------------
;; AAL Verification in CanvasL
;; -----------------------------

;; verify-canvasl-with-aal: Verify CanvasL program using AAL
(define (verify-canvasl-with-aal canvasl-program)
  (if (not (list? canvasl-program))
      (error "verify-canvasl-with-aal: expected list" canvasl-program)
      (let ((aal-program (canvasl-to-aal canvasl-program)))
        (if (program? aal-program)
            (let ((wf-result (wf-program aal-program))
                  (type-result (typed-program aal-program)))
              (list 'VerificationResult
                    wf-result
                    (if type-result #t #f)
                    aal-program))
            (list 'VerificationResult #f #f #f)))))

;; -----------------------------
;; Integration with CanvasL Interpreter
;; -----------------------------

;; add-aal-backend: Add AAL backend option to CanvasL interpreter
(define (add-aal-backend canvasl-interpreter)
  (if (not (procedure? canvasl-interpreter))
      (error "add-aal-backend: expected procedure" canvasl-interpreter)
      (lambda (command . args)
        (case command
          ((execute-with-aal)
           (apply execute-canvasl-with-aal args))
          ((verify-with-aal)
           (apply verify-canvasl-with-aal args))
          ((transform-to-aal)
           (apply canvasl-to-aal args))
          (else
           (apply canvasl-interpreter (cons command args)))))))

;; ============================================================
;; End of CanvasL-AAL Bridge
;; ============================================================

