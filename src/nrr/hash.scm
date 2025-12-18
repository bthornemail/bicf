;; ============================================================
;; NRR Content Addressing (R5RS Scheme)
;; Hash function abstraction and reference generation
;; ============================================================

;; For CLBC canonical bytes, we must be able to hash byte lists deterministically.
;; This file implements SHA-256 in-repo (no external crypto dependency).

(use-modules (rnrs bytevectors))

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

;; -----------------------------
;; SHA-256 (in-repo implementation)
;; -----------------------------

(define (u8? x) (and (integer? x) (<= 0 x) (<= x 255)))

(define (bytes? xs)
  (and (list? xs)
       (let loop ((ys xs))
         (if (null? ys) #t
             (and (u8? (car ys)) (loop (cdr ys)))))))

(define (hex2 n)
  (let* ((hex "0123456789abcdef")
         (hi (quotient n 16))
         (lo (modulo n 16)))
    (string (string-ref hex hi) (string-ref hex lo))))

(define (bytes->hex bs)
  (if (not (bytes? bs))
      (error "bytes->hex: expected bytes" bs)
      (let loop ((xs bs) (out '()))
        (if (null? xs)
            (apply string-append (reverse out))
            (loop (cdr xs) (cons (hex2 (car xs)) out))))))

(define (u32 x) (logand x #xffffffff))
;; rotate-right: (x >>> n) | (x << (32-n))
(define (rotr32 x n) (u32 (logior (ash x (- n)) (ash x (- 32 n)))))
(define (shr32 x n) (u32 (ash x (- n))))

(define (ch x y z) (u32 (logxor (logand x y) (logand (lognot x) z))))
(define (maj x y z) (u32 (logxor (logxor (logand x y) (logand x z)) (logand y z))))
(define (Sigma0 x) (u32 (logxor (logxor (rotr32 x 2) (rotr32 x 13)) (rotr32 x 22))))
(define (Sigma1 x) (u32 (logxor (logxor (rotr32 x 6) (rotr32 x 11)) (rotr32 x 25))))
(define (sigma0 x) (u32 (logxor (logxor (rotr32 x 7) (rotr32 x 18)) (shr32 x 3))))
(define (sigma1 x) (u32 (logxor (logxor (rotr32 x 17) (rotr32 x 19)) (shr32 x 10))))

(define K256
  '(#x428a2f98 #x71374491 #xb5c0fbcf #xe9b5dba5 #x3956c25b #x59f111f1 #x923f82a4 #xab1c5ed5
    #xd807aa98 #x12835b01 #x243185be #x550c7dc3 #x72be5d74 #x80deb1fe #x9bdc06a7 #xc19bf174
    #xe49b69c1 #xefbe4786 #x0fc19dc6 #x240ca1cc #x2de92c6f #x4a7484aa #x5cb0a9dc #x76f988da
    #x983e5152 #xa831c66d #xb00327c8 #xbf597fc7 #xc6e00bf3 #xd5a79147 #x06ca6351 #x14292967
    #x27b70a85 #x2e1b2138 #x4d2c6dfc #x53380d13 #x650a7354 #x766a0abb #x81c2c92e #x92722c85
    #xa2bfe8a1 #xa81a664b #xc24b8b70 #xc76c51a3 #xd192e819 #xd6990624 #xf40e3585 #x106aa070
    #x19a4c116 #x1e376c08 #x2748774c #x34b0bcb5 #x391c0cb3 #x4ed8aa4a #x5b9cca4f #x682e6ff3
    #x748f82ee #x78a5636f #x84c87814 #x8cc70208 #x90befffa #xa4506ceb #xbef9a3f7 #xc67178f2))

(define (u32be->bytes w)
  (list (logand (ash w -24) #xff)
        (logand (ash w -16) #xff)
        (logand (ash w -8) #xff)
        (logand w #xff)))

(define (bytes->u32be bs i)
  (let ((b0 (list-ref bs i))
        (b1 (list-ref bs (+ i 1)))
        (b2 (list-ref bs (+ i 2)))
        (b3 (list-ref bs (+ i 3))))
    (u32 (logior (ash b0 24) (ash b1 16) (ash b2 8) b3))))

(define (pad-sha256 msg)
  ;; msg: list of u8
  ;; pad so that (len(msg)+1+pad+8) mod 64 == 0, and length field is 64-bit big-endian.
  (let* ((ml-bits (* 8 (length msg)))
         (one (append msg (list #x80)))
         (padlen (modulo (- 56 (modulo (length one) 64)) 64))
         (zeros (make-list padlen 0))
         (hi (u32 (ash ml-bits -32)))
         (lo (u32 ml-bits))
         (len-bytes (append (u32be->bytes hi) (u32be->bytes lo))))
    (append one zeros len-bytes)))

(define (sha256-bytes msg)
  (if (not (bytes? msg))
      (error "sha256-bytes: expected bytes" msg)
      (let* ((padded (pad-sha256 msg))
             (h0 #x6a09e667) (h1 #xbb67ae85) (h2 #x3c6ef372) (h3 #xa54ff53a)
             (h4 #x510e527f) (h5 #x9b05688c) (h6 #x1f83d9ab) (h7 #x5be0cd19))
        (let loop-blocks ((off 0) (a h0) (b h1) (c h2) (d h3) (e h4) (f h5) (g h6) (h h7))
          (if (>= off (length padded))
              (append (u32be->bytes a) (u32be->bytes b) (u32be->bytes c) (u32be->bytes d)
                      (u32be->bytes e) (u32be->bytes f) (u32be->bytes g) (u32be->bytes h))
              (let* ((w (make-vector 64 0)))
                ;; init w[0..15]
                (let init ((t 0))
                  (if (< t 16)
                      (begin
                        (vector-set! w t (bytes->u32be padded (+ off (* 4 t))))
                        (init (+ t 1)))
                      #t))
                ;; expand w[16..63]
                (let expand ((t 16))
                  (if (< t 64)
                      (let* ((v (u32 (+ (sigma1 (vector-ref w (- t 2)))
                                        (vector-ref w (- t 7))
                                        (sigma0 (vector-ref w (- t 15)))
                                        (vector-ref w (- t 16))))))
                        (vector-set! w t v)
                        (expand (+ t 1)))
                      #t))
                ;; rounds
                (let loop-rounds ((t 0)
                                  (aa a) (bb b) (cc c) (dd d)
                                  (ee e) (ff f) (gg g) (hh h))
                  (if (= t 64)
                      (loop-blocks (+ off 64)
                                   (u32 (+ a aa)) (u32 (+ b bb)) (u32 (+ c cc)) (u32 (+ d dd))
                                   (u32 (+ e ee)) (u32 (+ f ff)) (u32 (+ g gg)) (u32 (+ h hh)))
                      (let* ((t1 (u32 (+ hh (Sigma1 ee) (ch ee ff gg) (list-ref K256 t) (vector-ref w t))))
                             (t2 (u32 (+ (Sigma0 aa) (maj aa bb cc)))))
                        (loop-rounds (+ t 1)
                                     (u32 (+ t1 t2))
                                     aa
                                     bb
                                     cc
                                     (u32 (+ dd t1))
                                     ee
                                     ff
                                     gg))))))))))

;; hash-sha256: SHA-256 hash hex string for content (string or bytes)
(define (hash-sha256 content)
  (cond
   ((string? content)
    ;; Treat string as UTF-8 bytes for hashing (deterministic, cross-runtime).
    ;; We avoid relying on locale by encoding explicitly via Guile's string->utf8 when available.
    (let* ((bv (string->utf8 content))
           (n (bytevector-length bv))
           (bs (let loop ((i 0) (out '()))
                 (if (= i n) (reverse out)
                     (loop (+ i 1) (cons (bytevector-u8-ref bv i) out))))))
      (bytes->hex (sha256-bytes bs))))
   ((bytes? content)
    (bytes->hex (sha256-bytes content)))
   (else
    (error "hash-sha256: expected string or bytes" content))))

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
  (let ((hash (hash-content content)))
    (string-append "nrr:" hash)))

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

