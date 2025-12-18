;; ============================================================
;; CanvasL record (alist) → CLBC bytecode compiler (MVP)
;; Notes:
;; - Existing repo uses CanvasL records as S-expression alists.
;; - This compiler targets the CLBC mapping doc, but ingests alists for now.
;; ============================================================

(define (clbc-dirname path)
  (if (not (string? path))
      (error "clbc-dirname: expected string" path)
      (let loop ((i (- (string-length path) 1)))
        (if (< i 0)
            "."
            (if (char=? (string-ref path i) #\/)
                (if (= i 0) "/" (substring path 0 i))
                (loop (- i 1)))))))

(define (clbc-load-relative rel)
  (let* ((cf (current-filename))
         (base (if (and cf (string? cf)) (clbc-dirname cf) (getcwd))))
    (load (string-append base "/" rel))))

(clbc-load-relative "bytes.scm")
(clbc-load-relative "uleb128.scm")
(clbc-load-relative "opcodes.scm")
(clbc-load-relative "format.scm")

(define (alist-ref a k)
  (let ((p (assq k a))) (if p (cdr p) #f)))

(define (require-field a k)
  (let ((v (alist-ref a k)))
    (if v v (error "missing required field" k a))))

(define (string-or-symbol->string x)
  (cond ((string? x) x)
        ((symbol? x) (symbol->string x))
        (else (error "expected string/symbol" x))))

(define (encode-begin-record kind phase)
  (bytes-append (list OP_BEGIN_RECORD)
                (list kind)
                (uleb128-encode phase)))

(define (encode-end-record) (list OP_END_RECORD))

(define (encode-result b) (list OP_RESULT (if b 1 0)))

(define (encode-checks check-ids)
  (bytes-append (list OP_CHECKS)
                (uleb128-encode (length check-ids))
                (map (lambda (x) (if (u8? x) x (error "check-id must be u8" x))) check-ids)))

(define (compile-record record string-table)
  ;; Returns (strings-used . record-bytes)
  (let* ((phase (require-field record 'phase))
         (op (alist-ref record 'op))
         (kind (cond
                ((and op (string=? (string-or-symbol->string op) "context")) KIND_CONTEXT)
                ((and op (string=? (string-or-symbol->string op) "transition")) KIND_TRANSITION)
                ((and op (string=? (string-or-symbol->string op) "validation")) KIND_VALIDATION)
                ((and op (string=? (string-or-symbol->string op) "projection")) KIND_PROJECTION)
                ((and op (string=? (string-or-symbol->string op) "commit")) KIND_COMMIT)
                ;; Fallback: treat unknown as validation for MVP
                (else KIND_VALIDATION)))
         (strings '())
         (emit (lambda (bs) bs)))
    (cons strings
          (bytes-append
           (encode-begin-record kind phase)
           ;; MVP record bodies:
           (cond
            ((= kind KIND_VALIDATION)
             ;; Optional: (checks . (0 1 2)) and (result . #t/#f) and (hash . "...")
             (let* ((checks (alist-ref record 'checks))
                    (result (alist-ref record 'result))
                    (hash (alist-ref record 'hash))
                    (out '()))
               (if (and checks (list? checks))
                   (set! out (cons (encode-checks checks) out)))
               (if (boolean? result)
                   (set! out (cons (encode-result result) out)))
               (if (string? hash)
                   (begin
                     (set! strings (cons hash strings))
                     (set! out (cons (bytes-append (list OP_HASH)
                                                   (uleb128-encode (clbc-string->sid string-table hash)))
                                     out))))
               (apply bytes-append (reverse out))))
            (else
             ;; For other kinds in MVP: encode empty record body.
             '()))
           (encode-end-record)))))

(define (canvasl-records->clbc records)
  ;; Two-pass: collect strings, build canonical string table, compile record stream.
  (let* ((strings (let loop ((xs records) (out '()))
                    (if (null? xs)
                        out
                        (let* ((r (car xs))
                               (h (alist-ref r 'hash)))
                          (loop (cdr xs) (if (string? h) (cons h out) out))))))
         (table (clbc-make-string-table strings))
         (compiled (let loop2 ((xs records) (out '()))
                     (if (null? xs)
                         (reverse out)
                         (let* ((pair (compile-record (car xs) table))
                                (bytes (cdr pair)))
                           (loop2 (cdr xs) (cons bytes out))))))
         (record-stream (apply bytes-append compiled))
         (enc (clbc-encode 0 (length records) strings record-stream)))
    ;; enc: (table . bytes)
    enc))

(define (read-records-from-port port)
  ;; Reads one Scheme datum per line (CanvasL alist record).
  (let loop ((out '()))
    (let ((x (read port)))
      (if (eof-object? x)
          (reverse out)
          (loop (cons x out))))))


