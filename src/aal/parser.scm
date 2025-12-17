;; ============================================================
;; AAL Parser (R5RS Scheme)
;; LL(1) recursive descent parser for EBNF grammar
;; Source: AAL Spec Section 3 (EBNF Grammar)
;; ============================================================

(load "ast.scm")

;; -----------------------------
;; Token Definitions
;; -----------------------------

;; Token types
(define (token? x)
  (and (list? x)
       (>= (length x) 1)
       (symbol? (car x))))

(define (make-token type value)
  (list type value))

(define (token-type token)
  (car token))

(define (token-value token)
  (cadr token))

;; Token types
(define *TOKEN-MNEMONIC* 'MNEMONIC)
(define *TOKEN-REGISTER* 'REGISTER)
(define *TOKEN-NUMBER* 'NUMBER)
(define *TOKEN-HEX* 'HEX)
(define *TOKEN-IDENTIFIER* 'IDENTIFIER)
(define *TOKEN-STRING* 'STRING)
(define *TOKEN-COMMA* 'COMMA)
(define *TOKEN-COLON* 'COLON)
(define *TOKEN-LBRACKET* 'LBRACKET)
(define *TOKEN-RBRACKET* 'RBRACKET)
(define *TOKEN-HASH* 'HASH)
(define *TOKEN-PLUS* 'PLUS)
(define *TOKEN-NEWLINE* 'NEWLINE)
(define *TOKEN-COMMENT* 'COMMENT)
(define *TOKEN-DIRECTIVE* 'DIRECTIVE)
(define *TOKEN-EOF* 'EOF)

;; -----------------------------
;; Lexer
;; -----------------------------

;; lex: Tokenize input string
(define (lex input)
  (if (not (string? input))
      (error "lex: expected string" input)
      (let ((chars (string->list input))
            (tokens '())
            (line 1)
            (col 1))
        (let loop ((remaining chars)
                   (current '())
                   (in-comment #f))
          (if (null? remaining)
              (if (not (null? current))
                  (reverse (cons (make-token *TOKEN-EOF* #f) tokens))
                  (reverse (cons (make-token *TOKEN-EOF* #f) tokens)))
              (let ((ch (car remaining)))
                (cond
                 ;; Comment
                 ((char=? ch #\;)
                  (let comment-loop ((rem (cdr remaining)))
                    (if (or (null? rem) (char=? (car rem) #\newline))
                        (loop (if (null? rem) '() (cdr rem))
                              '()
                              #f)
                        (comment-loop (cdr rem)))))
                 ;; Whitespace
                 ((or (char=? ch #\space) (char=? ch #\tab))
                  (loop (cdr remaining) '() #f))
                 ;; Newline
                 ((char=? ch #\newline)
                  (loop (cdr remaining)
                        '()
                        #f))
                 ;; Colon
                 ((char=? ch #\:)
                  (loop (cdr remaining)
                        '()
                        #f)
                  (cons (make-token *TOKEN-COLON* #\:) tokens))
                 ;; Comma
                 ((char=? ch #\,)
                  (loop (cdr remaining)
                        '()
                        #f)
                  (cons (make-token *TOKEN-COMMA* #\,) tokens))
                 ;; Hash (immediate)
                 ((char=? ch #\#)
                  (loop (cdr remaining)
                        '()
                        #f)
                  (cons (make-token *TOKEN-HASH* #\#) tokens))
                 ;; Left bracket
                 ((char=? ch #\[)
                  (loop (cdr remaining)
                        '()
                        #f)
                  (cons (make-token *TOKEN-LBRACKET* #\[) tokens))
                 ;; Right bracket
                 ((char=? ch #\])
                  (loop (cdr remaining)
                        '()
                        #f)
                  (cons (make-token *TOKEN-RBRACKET* #\]) tokens))
                 ;; Plus
                 ((char=? ch #\+)
                  (loop (cdr remaining)
                        '()
                        #f)
                  (cons (make-token *TOKEN-PLUS* #\+) tokens))
                 ;; Dot (directive)
                 ((char=? ch #\.)
                  (let directive-loop ((rem (cdr remaining))
                                      (dir-chars '()))
                    (if (or (null? rem)
                            (char-whitespace? (car rem))
                            (char=? (car rem) #\newline))
                        (let ((dir-name (list->string (reverse dir-chars))))
                          (loop rem
                                '()
                                #f)
                          (cons (make-token *TOKEN-DIRECTIVE* dir-name) tokens))
                        (directive-loop (cdr rem)
                                        (cons (car rem) dir-chars)))))
                 ;; Hex number
                 ((and (char=? ch #\0)
                       (not (null? (cdr remaining)))
                       (char-ci=? (cadr remaining) #\x))
                  (let hex-loop ((rem (cddr remaining))
                                 (hex-chars '()))
                    (if (or (null? rem)
                            (not (or (char-numeric? (car rem))
                                     (char-ci-between? (car rem) #\a #\f))))
                        (let ((hex-str (list->string (reverse hex-chars))))
                          (loop rem
                                '()
                                #f)
                          (cons (make-token *TOKEN-HEX* (string->number hex-str 16)) tokens))
                        (hex-loop (cdr rem)
                                  (cons (char-downcase (car rem)) hex-chars)))))
                 ;; Number
                 ((char-numeric? ch)
                  (let num-loop ((rem (cdr remaining))
                                 (num-chars (list ch)))
                    (if (or (null? rem)
                            (not (char-numeric? (car rem))))
                        (let ((num-str (list->string (reverse num-chars))))
                          (loop rem
                                '()
                                #f)
                          (cons (make-token *TOKEN-NUMBER* (string->number num-str)) tokens))
                        (num-loop (cdr rem)
                                  (cons (car rem) num-chars)))))
                 ;; Identifier or mnemonic or register
                 ((or (char-alphabetic? ch)
                      (char=? ch #\_))
                  (let id-loop ((rem (cdr remaining))
                                (id-chars (list ch)))
                    (if (or (null? rem)
                            (not (or (char-alphabetic? (car rem))
                                     (char-numeric? (car rem))
                                     (char=? (car rem) #\_))))
                        (let ((id-str (list->string (reverse id-chars))))
                          (loop rem
                                '()
                                #f)
                          (cond
                           ;; Check if mnemonic
                           ((mnemonic? (string->symbol (string-upcase id-str)))
                            (cons (make-token *TOKEN-MNEMONIC* (string->symbol (string-upcase id-str))) tokens))
                           ;; Check if register
                           ((reg? (string->symbol (string-upcase id-str)))
                            (cons (make-token *TOKEN-REGISTER* (string->symbol (string-upcase id-str))) tokens))
                           ;; Otherwise identifier
                           (else
                            (cons (make-token *TOKEN-IDENTIFIER* id-str) tokens))))
                        (id-loop (cdr rem)
                                 (cons (char-downcase (car rem)) id-chars)))))
                 (else
                  (error "lex: unexpected character" ch)))))))))

;; Helper functions (simplified versions)
(define (char-whitespace? ch)
  (or (char=? ch #\space) (char=? ch #\tab) (char=? ch #\newline)))

(define (char-numeric? ch)
  (char<=? #\0 ch #\9))

(define (char-alphabetic? ch)
  (or (char-ci<=? #\a ch #\z)))

(define (char-ci-between? ch low high)
  (and (char-ci>=? ch low) (char-ci<=? ch high)))

(define (char-downcase ch)
  (if (char-upper-case? ch)
      (integer->char (+ (char->integer ch) 32))
      ch))

(define (char-upper-case? ch)
  (char<=? #\A ch #\Z))

(define (string-upcase str)
  (list->string (map char-upcase (string->list str))))

(define (char-upcase ch)
  (if (char-lower-case? ch)
      (integer->char (- (char->integer ch) 32))
      ch))

(define (char-lower-case? ch)
  (char<=? #\a ch #\z))

;; -----------------------------
;; Parser
;; -----------------------------

;; parse-aal: Parse AAL program from string
(define (parse-aal input)
  (if (not (string? input))
      (error "parse-aal: expected string" input)
      (let ((tokens (lex input)))
        (parse-program tokens))))

;; parse-program: Parse program (list of lines)
(define (parse-program tokens)
  (let loop ((remaining tokens)
             (program '())
             (instr-index 0))
    (if (null? remaining)
        (reverse program)
        (let ((token (car remaining)))
          (cond
           ((eq? (token-type token) *TOKEN-EOF*)
            (reverse program))
           ((eq? (token-type token) *TOKEN-NEWLINE*)
            (loop (cdr remaining) program instr-index))
           ((eq? (token-type token) *TOKEN-COMMENT*)
            (loop (cdr remaining) program instr-index))
           ((eq? (token-type token) *TOKEN-DIRECTIVE*)
            ;; Skip directives for now
            (loop (cdr remaining) program instr-index))
           ((eq? (token-type token) *TOKEN-IDENTIFIER*)
            ;; Could be label or instruction
            (let ((next-tokens (cdr remaining)))
              (if (and (not (null? next-tokens))
                       (eq? (token-type (car next-tokens)) *TOKEN-COLON*))
                  ;; Label declaration
                  (let ((label-name (token-value token)))
                    (loop (cdr next-tokens)
                          (cons (cons label-name instr-index) program)
                          instr-index))
                  ;; Try to parse as instruction
                  (let ((instr-result (parse-instruction-line remaining instr-index)))
                    (if instr-result
                        (let ((instr (car instr-result))
                              (new-tokens (cdr instr-result)))
                          (loop new-tokens
                                (cons instr program)
                                (+ instr-index 1)))
                        (error "parse-program: parse error" token))))))
           ((eq? (token-type token) *TOKEN-MNEMONIC*)
            ;; Instruction without label
            (let ((instr-result (parse-instruction-line remaining instr-index)))
              (if instr-result
                  (let ((instr (car instr-result))
                        (new-tokens (cdr instr-result)))
                    (loop new-tokens
                          (cons instr program)
                          (+ instr-index 1)))
                  (error "parse-program: parse error" token))))
           (else
            (error "parse-program: unexpected token" token)))))))

;; parse-instruction-line: Parse instruction line
(define (parse-instruction-line tokens instr-index)
  (if (null? tokens)
      #f
      (let ((token (car tokens)))
        (cond
         ((eq? (token-type token) *TOKEN-MNEMONIC*)
          (let ((mnem (token-value token))
                (operands-result (parse-operand-list (cdr tokens))))
            (if operands-result
                (let ((operands (car operands-result))
                      (new-tokens (cdr operands-result)))
                  (cons (make-instr mnem operands) new-tokens))
                #f)))
         (else #f)))))

;; parse-operand-list: Parse comma-separated operand list
(define (parse-operand-list tokens)
  (if (null? tokens)
      (cons '() tokens)
      (let ((first-op (parse-operand tokens)))
        (if (not first-op)
            (cons '() tokens)
            (let ((op (car first-op))
                  (remaining (cdr first-op)))
              (if (and (not (null? remaining))
                       (eq? (token-type (car remaining)) *TOKEN-COMMA*))
                  (let ((rest-result (parse-operand-list (cdr remaining))))
                    (cons (cons op (car rest-result))
                          (cdr rest-result)))
                  (cons (list op) remaining)))))))

;; parse-operand: Parse single operand
(define (parse-operand tokens)
  (if (null? tokens)
      #f
      (let ((token (car tokens)))
        (cond
         ;; Register
         ((eq? (token-type token) *TOKEN-REGISTER*)
          (cons (make-oreg (token-value token)) (cdr tokens)))
         ;; Immediate
         ((eq? (token-type token) *TOKEN-HASH*)
          (if (null? (cdr tokens))
              #f
              (let ((num-token (cadr tokens)))
                (if (or (eq? (token-type num-token) *TOKEN-NUMBER*)
                        (eq? (token-type num-token) *TOKEN-HEX*))
                    (cons (make-oimm (nat-to-poly (token-value num-token)))
                          (cddr tokens))
                    #f))))
         ;; Number (immediate without #)
         ((or (eq? (token-type token) *TOKEN-NUMBER*)
              (eq? (token-type token) *TOKEN-HEX*))
          (cons (make-oimm (nat-to-poly (token-value token)))
                (cdr tokens)))
         ;; Memory reference
         ((eq? (token-type token) *TOKEN-LBRACKET*)
          (let ((addr-result (parse-address-expr (cdr tokens))))
            (if (and addr-result
                     (not (null? (cdr addr-result)))
                     (eq? (token-type (cadr addr-result)) *TOKEN-RBRACKET*))
                (cons (make-omem (car addr-result) 0)
                      (cddr addr-result))
                #f)))
         ;; Label reference
         ((eq? (token-type token) *TOKEN-IDENTIFIER*)
          (cons (make-olabel (token-value token))
                (cdr tokens)))
         (else #f)))))

;; parse-address-expr: Parse address expression
(define (parse-address-expr tokens)
  (if (null? tokens)
      #f
      (let ((token (car tokens)))
        (cond
         ((eq? (token-type token) *TOKEN-REGISTER*)
          (let ((reg (token-value token)))
            (if (and (not (null? (cdr tokens)))
                     (eq? (token-type (cadr tokens)) *TOKEN-PLUS*))
                (if (and (not (null? (cddr tokens)))
                         (or (eq? (token-type (caddr tokens)) *TOKEN-NUMBER*)
                             (eq? (token-type (caddr tokens)) *TOKEN-HEX*)))
                    (cons reg (cdddr tokens))
                    #f)
                (cons reg (cdr tokens)))))
         ((or (eq? (token-type token) *TOKEN-NUMBER*)
              (eq? (token-type token) *TOKEN-HEX*))
          (let ((num (token-value token)))
            (if (and (not (null? (cdr tokens)))
                     (eq? (token-type (cadr tokens)) *TOKEN-PLUS*)
                     (not (null? (cddr tokens)))
                     (eq? (token-type (caddr tokens)) *TOKEN-REGISTER*))
                (cons (token-value (caddr tokens)) (cdddr tokens))
                #f)))
         (else #f)))))

;; ============================================================
;; End of Parser
;; ============================================================

