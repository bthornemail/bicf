;; ============================================================
;; CLBC - byte helpers (Guile)
;; Represent byte streams as lists of integers 0..255 for R5RS-ish code.
;; ============================================================

(use-modules (rnrs bytevectors))

(define (u8? x) (and (integer? x) (<= 0 x) (<= x 255)))

(define (bytes-append . chunks)
  (let loop ((xs chunks) (out '()))
    (if (null? xs)
        (apply append (reverse out))
        (let ((c (car xs)))
          (if (not (list? c))
              (error "bytes-append: expected list of bytes" c)
              (loop (cdr xs) (cons c out)))))))

(define (u32le-encode n)
  (if (or (not (integer? n)) (< n 0) (> n #xFFFFFFFF))
      (error "u32le-encode: expected u32" n)
      (list (logand n #xFF)
            (logand (ash n -8) #xFF)
            (logand (ash n -16) #xFF)
            (logand (ash n -24) #xFF))))

(define (bytes->string/latin1 bs)
  (list->string (map integer->char bs)))

(define (string->bytes/latin1 s)
  (map char->integer (string->list s)))

(define (utf8-bytes s)
  ;; Guile provides utf8 encoding via string->utf8
  (if (not (string? s))
      (error "utf8-bytes: expected string" s)
      (let ((bv (string->utf8 s)))
        (let loop ((i 0) (n (bytevector-length bv)) (out '()))
          (if (= i n)
              (reverse out)
              (loop (+ i 1) n (cons (bytevector-u8-ref bv i) out)))))))

(define (bytes->utf8 bs)
  (if (not (list? bs))
      (error "bytes->utf8: expected list of bytes" bs)
      (let* ((bv (make-bytevector (length bs) 0)))
        (let loop ((i 0) (xs bs))
          (if (null? xs)
              (utf8->string bv)
              (begin
                (bytevector-u8-set! bv i (car xs))
                (loop (+ i 1) (cdr xs))))))))


