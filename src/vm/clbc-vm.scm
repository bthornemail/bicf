;; ============================================================
;; CLBC reference VM (MVP)
;; - Deterministic execution
;; - Produces transcript hash via src/nrr/hash.scm (currently simple-hash)
;; ============================================================

(define (vm-dirname path)
  (let loop ((i (- (string-length path) 1)))
    (if (< i 0) "."
        (if (char=? (string-ref path i) #\/)
            (if (= i 0) "/" (substring path 0 i))
            (loop (- i 1))))))

(define (vm-load-relative rel)
  (let* ((cf (current-filename))
         (base (if (and cf (string? cf)) (vm-dirname cf) (getcwd))))
    (load (string-append base "/" rel))))

(vm-load-relative "../clbc/format.scm")
(vm-load-relative "../clbc/opcodes.scm")
(vm-load-relative "../nrr/hash.scm")

(use-modules (rnrs io ports))

(define (bytes->latin1 bs)
  (list->string (map integer->char bs)))

(define (vm-hash-step prev-hash chunk-bytes)
  ;; rolling hash: hash(prev || '|' || chunk)
  (hash-content (string-append prev-hash "|" (bytes->latin1 chunk-bytes))))

(define (vm-run-clbc-bytes clbc-bytes)
  ;; returns alist: '((ok? . bool) (transcript-hash . string) (events . n) (errors . (..)))
  (let* ((decoded (clbc-decode clbc-bytes))
         (rs (cdr (assq 'record-stream decoded)))
         (errors '())
         (events 0)
         (hash "nrr:0")
         (idx 0))
    (define (fail msg)
      (set! errors (cons msg errors)))

    (define (consume n)
      (let ((chunk (let loop ((i 0) (xs (clbc-drop rs idx)) (out '()))
                     (if (= i n) (reverse out)
                         (loop (+ i 1) (cdr xs) (cons (car xs) out))))))
        (set! idx (+ idx n))
        chunk))

    ;; Walk the record stream; MVP supports validation records and framing.
    (let loop ()
      (if (>= idx (length rs))
          `((ok? . ,(null? errors))
            (transcript-hash . ,hash)
            (events . ,events)
            (errors . ,(reverse errors)))
          (let ((op (list-ref rs idx)))
            (cond
             ((= op OP_BEGIN_RECORD)
              ;; BEGIN_RECORD kind phase
              (let ((hdr (consume 2))) ;; op + kind; phase is uleb128 next
                (let* ((kind (cadr hdr))
                       (p (uleb128-decode (clbc-drop rs idx)))
                       (phase (car p))
                       (rest (cdr p))
                       (consumed (- (length (clbc-drop rs idx)) (length rest))))
                  (set! idx (+ idx consumed))
                  (set! events (+ events 1))
                  (set! hash (vm-hash-step hash (bytes-append hdr (uleb128-encode phase))))
                  (loop))))
             ((= op OP_END_RECORD)
              (set! events (+ events 1))
              (set! hash (vm-hash-step hash (consume 1)))
              (loop))
             ((= op OP_CHECKS)
              (consume 1) ;; opcode
              (let* ((p (uleb128-decode (clbc-drop rs idx)))
                     (n (car p))
                     (rest (cdr p))
                     (consumed (- (length (clbc-drop rs idx)) (length rest))))
                (set! idx (+ idx consumed))
                (let ((ids (consume n)))
                  (set! events (+ events 1))
                  (set! hash (vm-hash-step hash (bytes-append (list OP_CHECKS) (uleb128-encode n) ids)))
                  (loop))))
             ((= op OP_RESULT)
              (let ((chunk (consume 2)))
                (set! events (+ events 1))
                (set! hash (vm-hash-step hash chunk))
                (loop)))
             ((= op OP_HASH)
              (consume 1)
              (let* ((p (uleb128-decode (clbc-drop rs idx)))
                     (sid (car p))
                     (rest (cdr p))
                     (consumed (- (length (clbc-drop rs idx)) (length rest))))
                (set! idx (+ idx consumed))
                (set! events (+ events 1))
                (set! hash (vm-hash-step hash (bytes-append (list OP_HASH) (uleb128-encode sid))))
                (loop)))
             (else
              ;; Unknown op: deterministic fail and stop.
              (fail (string-append "unknown opcode: " (number->string op)))
              `((ok? . #f)
                (transcript-hash . ,hash)
                (events . ,events)
                (errors . ,(reverse errors))))))))))

(define (read-file-bytes path)
  (call-with-input-file path
    (lambda (port)
      (let loop ((out '()))
        (let ((b (get-u8 port)))
          (if (eof-object? b)
              (reverse out)
              (loop (cons b out))))))))


