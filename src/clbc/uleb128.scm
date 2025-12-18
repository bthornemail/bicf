;; ============================================================
;; CLBC - ULEB128 helpers (Guile)
;; Deterministic integer encoding for bytecode container/opcodes.
;; ============================================================

(define (uleb128-encode n)
  (if (or (not (integer? n)) (< n 0))
      (error "uleb128-encode: expected non-negative integer" n)
      (let loop ((x n) (out '()))
        (let* ((byte (logand x #x7F))
               (x2 (ash x -7)))
          (if (= x2 0)
              (reverse (cons byte out))
              (loop x2 (cons (logior byte #x80) out)))))))

(define (uleb128-decode bytes)
  ;; bytes: list of u8 integers (0..255)
  ;; returns (value . rest-bytes)
  (if (not (list? bytes))
      (error "uleb128-decode: expected list of bytes" bytes)
      (let loop ((xs bytes) (shift 0) (acc 0))
        (if (null? xs)
            (error "uleb128-decode: truncated" bytes)
            (let* ((b (car xs))
                   (payload (logand b #x7F))
                   (acc2 (logior acc (ash payload shift))))
              (if (= 0 (logand b #x80))
                  (cons acc2 (cdr xs))
                  (loop (cdr xs) (+ shift 7) acc2)))))))


