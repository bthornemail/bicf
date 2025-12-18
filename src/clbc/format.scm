;; ============================================================
;; CLBC - container format encode/decode (MVP)
;; Spec reference:
;;   dev-docs/Inbox/Map CanvasL JSONL → ISA Bytecode (Deterministic, Emulator-Friendly).md
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
  ;; Prefer resolving relative to the currently loading file when possible.
  (let* ((cf (current-filename))
         (base (if (and cf (string? cf)) (clbc-dirname cf) (getcwd))))
    (load (string-append base "/" rel))))

(define (clbc-take xs n)
  (if (<= n 0)
      '()
      (if (null? xs) '()
          (cons (car xs) (clbc-take (cdr xs) (- n 1))))))

(define (clbc-drop xs n)
  (if (<= n 0)
      xs
      (if (null? xs) '()
          (clbc-drop (cdr xs) (- n 1)))))

(clbc-load-relative "bytes.scm")
(clbc-load-relative "uleb128.scm")

(define CLBC_MAGIC "CLBC")
(define CLBC_VERSION 1) ;; u8

(define (clbc-make-string-table strings)
  ;; strings: list of strings, possibly with duplicates
  ;; returns (alist (sid . string)) in canonical SID order, and lookup function.
  (if (not (list? strings))
      (error "clbc-make-string-table: expected list" strings)
      (let* ((uniq (let loop ((xs strings) (seen '()) (out '()))
                     (if (null? xs)
                         out
                         (let ((s (car xs)))
                           (if (not (string? s))
                               (error "clbc-make-string-table: expected string" s)
                               (if (member s seen)
                                   (loop (cdr xs) seen out)
                                   (loop (cdr xs) (cons s seen) (cons s out))))))))
             (sorted (sort uniq string<?)))
        (let loop2 ((sid 0) (xs sorted) (out '()))
          (if (null? xs)
              (reverse out)
              (loop2 (+ sid 1) (cdr xs) (cons (cons sid (car xs)) out)))))))

(define (clbc-string->sid table s)
  (let loop ((xs table))
    (if (null? xs)
        (error "clbc-string->sid: string not in table" s)
        (let ((p (car xs)))
          (if (string=? (cdr p) s) (car p) (loop (cdr xs)))))))

(define (clbc-encode-string-table table)
  ;; table: alist sid->string
  ;; returns bytes of string table (concatenated entries)
  (let loop ((xs table) (out '()))
    (if (null? xs)
        (apply bytes-append (reverse out))
        (let* ((s (cdr (car xs)))
               (bs (utf8-bytes s))
               (len (uleb128-encode (length bs))))
          (loop (cdr xs) (cons (bytes-append len bs) out))))))

(define (clbc-encode flags record-count strings record-stream-bytes)
  ;; flags: u8 integer
  ;; record-count: u32
  ;; strings: list of strings used
  ;; record-stream-bytes: list of u8
  (let* ((table (clbc-make-string-table strings))
         (st-bytes (clbc-encode-string-table table))
         (header (bytes-append
                  (string->bytes/latin1 CLBC_MAGIC)
                  (list CLBC_VERSION)
                  (list flags)
                  (u32le-encode record-count)
                  (u32le-encode (length st-bytes))))
         (all (bytes-append header st-bytes record-stream-bytes)))
    (cons table all)))

(define (clbc-decode bytes)
  ;; Minimal decoder for header + string table extraction.
  ;; returns alist: '((version . v) (flags . f) (record-count . n) (string-table . table) (record-stream . bytes))
  (if (or (not (list? bytes)) (< (length bytes) 10))
      (error "clbc-decode: expected byte list with header" bytes)
      (let* ((magic (bytes->string/latin1 (clbc-take bytes 4)))
             (version (list-ref bytes 4))
             (flags (list-ref bytes 5))
             (rc (let ((b (clbc-drop bytes 6)))
                   (+ (list-ref b 0)
                      (ash (list-ref b 1) 8)
                      (ash (list-ref b 2) 16)
                      (ash (list-ref b 3) 24))))
             (st-len (let ((b (clbc-drop bytes 10)))
                       (+ (list-ref b 0)
                          (ash (list-ref b 1) 8)
                          (ash (list-ref b 2) 16)
                          (ash (list-ref b 3) 24))))
             (st-start 14)
             (st-end (+ st-start st-len)))
        (if (not (string=? magic CLBC_MAGIC))
            (error "clbc-decode: bad magic" magic)
            (let* ((st-bytes (clbc-take (clbc-drop bytes st-start) st-len))
                   (rs (clbc-drop bytes st-end))
                   (table (clbc-decode-string-table st-bytes)))
              `((version . ,version)
                (flags . ,flags)
                (record-count . ,rc)
                (string-table . ,table)
                (record-stream . ,rs)))))))

(define (clbc-decode-string-table st-bytes)
  ;; Returns alist sid->string. SIDs are implicit in order.
  (let loop ((sid 0) (xs st-bytes) (out '()))
    (if (null? xs)
        (reverse out)
        (let* ((p (uleb128-decode xs))
               (len (car p))
               (rest (cdr p))
               (payload (clbc-take rest len))
               (rest2 (clbc-drop rest len))
               (s (bytes->utf8 payload)))
          (loop (+ sid 1) rest2 (cons (cons sid s) out))))))


