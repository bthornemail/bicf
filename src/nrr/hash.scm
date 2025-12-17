;; ============================================================
;; NRR Content Addressing (R5RS Scheme)
;; Hash function abstraction and reference generation
;; ============================================================

;; -----------------------------
;; Hash Function Types
;; -----------------------------

(define *hash-types* '(sha256 blake3 crc32))

(define (hash-type? x)
  (memq x *hash-types*))

;; Current hash function (default: SHA-256)
(define *current-hash-type* 'sha256)

(define (set-hash-type hash-type)
  (if (not (hash-type? hash-type))
      (error "set-hash-type: expected hash type" hash-type)
      (set! *current-hash-type* hash-type)))

(define (get-hash-type)
  *current-hash-type*)

;; -----------------------------
;; Hash Function Interface
;; -----------------------------

;; hash-content: Hash content bytes, return hex string
(define (hash-content content)
  (if (not (hash-type? *current-hash-type*))
      (error "hash-content: invalid hash type" *current-hash-type*)
      (case *current-hash-type*
        ((sha256)
         (hash-sha256 content))
        ((blake3)
         (hash-blake3 content))
        ((crc32)
         (hash-crc32 content))
        (else
         (error "hash-content: unsupported hash type" *current-hash-type*)))))

;; -----------------------------
;; Hash Implementations
;; -----------------------------

;; hash-sha256: SHA-256 hash (simplified - would use external library in production)
(define (hash-sha256 content)
  (if (not (string? content))
      (error "hash-sha256: expected string" content)
      ;; For R5RS, we'll use a simple hash function
      ;; In production, would call external SHA-256 library
      (let ((bytes (string->bytes content)))
        (simple-hash bytes))))

;; hash-blake3: BLAKE3 hash (placeholder)
(define (hash-blake3 content)
  (if (not (string? content))
      (error "hash-blake3: expected string" content)
      ;; Placeholder - would use BLAKE3 library
      (string-append "blake3:" (hash-sha256 content))))

;; hash-crc32: CRC32 hash (for ultra-low resource)
(define (hash-crc32 content)
  (if (not (string? content))
      (error "hash-crc32: expected string" content)
      ;; Placeholder - would use CRC32 implementation
      (string-append "crc32:" (number->string (string-hash content)))))

;; -----------------------------
;; Simple Hash (Fallback)
;; -----------------------------

;; simple-hash: Simple hash function for R5RS (not cryptographically secure)
;; In production, use proper SHA-256 implementation
(define (simple-hash bytes)
  (if (not (list? bytes))
      (error "simple-hash: expected list of bytes" bytes)
      (let loop ((bytes bytes)
                 (hash 0))
        (if (null? bytes)
            (number->hex-string hash)
            (loop (cdr bytes)
                  (bitwise-xor hash
                               (bitwise-arithmetic-shift-left (car bytes)
                                                              (modulo hash 32))))))))

;; Helper: string->bytes (convert string to list of byte values)
(define (string->bytes str)
  (if (not (string? str))
      (error "string->bytes: expected string" str)
      (let loop ((chars (string->list str))
                 (bytes '()))
        (if (null? chars)
            (reverse bytes)
            (loop (cdr chars)
                  (cons (char->integer (car chars)) bytes))))))

;; Helper: number->hex-string
(define (number->hex-string n)
  (if (not (integer? n))
      (error "number->hex-string: expected integer" n)
      (let ((hex-chars "0123456789abcdef"))
        (if (= n 0)
            "0"
            (let loop ((n (abs n))
                       (result '()))
              (if (= n 0)
                  (list->string (reverse result))
                  (let ((digit (modulo n 16)))
                    (loop (quotient n 16)
                          (cons (string-ref hex-chars digit) result)))))))))

;; Helper: string-hash (simple string hash)
(define (string-hash str)
  (if (not (string? str))
      (error "string-hash: expected string" str)
      (let loop ((chars (string->list str))
                 (hash 0))
        (if (null? chars)
            hash
            (loop (cdr chars)
                  (+ hash (* (char->integer (car chars))
                             (expt 31 (- (length chars) 1)))))))))

;; Helper: bitwise operations (if not available in R5RS)
(define (bitwise-xor a b)
  (if (and (integer? a) (integer? b))
      (let loop ((a a) (b b) (result 0) (shift 0))
        (if (and (= a 0) (= b 0))
            result
            (loop (quotient a 2)
                  (quotient b 2)
                  (+ result (* (modulo (bitwise-xor-bit (modulo a 2) (modulo b 2)) 2)
                               (expt 2 shift)))
                  (+ shift 1))))
      (error "bitwise-xor: expected integers" (list a b))))

(define (bitwise-xor-bit a b)
  (if (= a b) 0 1))

(define (bitwise-arithmetic-shift-left n k)
  (if (and (integer? n) (integer? k))
      (* n (expt 2 k))
      (error "bitwise-arithmetic-shift-left: expected integers" (list n k))))

;; -----------------------------
;; Content Reference Generation
;; -----------------------------

;; make-nrr-ref: Generate NRR content reference
;; Format: "nrr:<hash>"
(define (make-nrr-ref content)
  (if (not (string? content))
      (error "make-nrr-ref: expected string" content)
      (let ((hash (hash-content content)))
        (string-append "nrr:" hash))))

;; nrr-ref?: Check if string is an NRR reference
(define (nrr-ref? ref)
  (if (not (string? ref))
      #f
      (let ((prefix "nrr:"))
        (and (>= (string-length ref) (string-length prefix))
             (string=? (substring ref 0 (string-length prefix)) prefix)))))

;; extract-hash-from-ref: Extract hash from NRR reference
(define (extract-hash-from-ref ref)
  (if (not (nrr-ref? ref))
      (error "extract-hash-from-ref: expected NRR reference" ref)
      (substring ref 4)))  ;; Skip "nrr:" prefix

;; -----------------------------
;; Reference Validation
;; -----------------------------

;; validate-ref: Validate reference format
(define (validate-ref ref)
  (if (not (string? ref))
      (error "validate-ref: expected string" ref)
      (or (nrr-ref? ref)
          (git-ref? ref)
          (local-ref? ref))))

;; git-ref?: Check if reference is Git format
(define (git-ref? ref)
  (if (not (string? ref))
      #f
      (let ((prefix "commit:"))
        (and (>= (string-length ref) (string-length prefix))
             (string=? (substring ref 0 (string-length prefix)) prefix)))))

;; local-ref?: Check if reference is local (in-memory)
(define (local-ref? ref)
  (if (not (string? ref))
      #f
      (let ((prefix "ref:"))
        (and (>= (string-length ref) (string-length prefix))
             (string=? (substring ref 0 (string-length prefix)) prefix)))))

;; -----------------------------
;; Reference Format Conversion
;; -----------------------------

;; normalize-ref: Normalize reference to NRR format
(define (normalize-ref ref)
  (if (not (string? ref))
      (error "normalize-ref: expected string" ref)
      (cond
       ((nrr-ref? ref) ref)
       ((git-ref? ref)
        ;; Convert Git reference to NRR format
        (let ((git-hash (substring ref 7)))  ;; Skip "commit:" prefix
          (string-append "nrr:" git-hash)))
       ((local-ref? ref) ref)  ;; Keep local refs as-is
       (else
        (error "normalize-ref: unknown reference format" ref)))))

;; ============================================================
;; End of Content Addressing
;; ============================================================

