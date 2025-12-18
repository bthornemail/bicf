;; ============================================================
;; CanvasL v1.0 JSONL Engine CLI (deterministic, tool boundary)
;; - Validates minimal CanvasL 1.0 record structure deterministically
;; - Appends accepted records to NRR log (file backend) and persists the log
;; - Produces:
;;   - RFC-VIZ-001 scene snapshot (JSON)
;;   - CLBC VM transcript hash (JSON)
;;   - Fano incidence payload (JSON) derived from projection records
;;
;; Usage:
;;   guile tools/canvasl-engine-jsonl.scm --repo .nrr --jsonl trace.jsonl --getScene
;;   guile tools/canvasl-engine-jsonl.scm --repo .nrr --jsonl trace.jsonl --getTrace
;;   guile tools/canvasl-engine-jsonl.scm --repo .nrr --jsonl trace.jsonl --getIncidence
;;
;; Notes:
;; - This file intentionally does not import engine internals into Node/LSP.
;; ============================================================

(use-modules (json))

(define (dirname path)
  (if (not (string? path)) (error "dirname: expected string" path)
      (let loop ((i (- (string-length path) 1)))
        (if (< i 0) "."
            (if (char=? (string-ref path i) #\/)
                (if (= i 0) "/" (substring path 0 i))
                (loop (- i 1)))))))

(define (load-relative rel)
  (let* ((cf (current-filename))
         (base (if (and cf (string? cf)) (dirname cf) (getcwd))))
    (load (string-append base "/../" rel))))

;; NRR + CLBC + VM + VIZ
(load-relative "src/nrr/storage.scm")
(load-relative "src/nrr/log.scm")
(load-relative "src/nrr/log-entry.scm")
(load-relative "src/clbc/compiler.scm")
(load-relative "src/vm/clbc-vm.scm")
(load-relative "src/viz/scene.scm")

(define (alist-ref a k) (let ((p (assq k a))) (if p (cdr p) #f)))

(define (json-object->alist obj)
  ;; obj is a guile-json "object" = alist of (string . value)
  (map (lambda (p)
         (cons (string->symbol (car p)) (json->scheme (cdr p))))
       obj))

(define (read-jsonl path)
  (let ((port (open-input-file path)))
    (if (not port) (error "cannot open jsonl" path)
        (let loop ((out '()))
          (let ((line (read-line port)))
            (cond
             ((eof-object? line)
              (close-input-port port)
              (reverse out))
             ((or (not (string? line)) (= (string-length line) 0))
              (loop out))
             (else
              (let* ((j (call-with-input-string line json->scm))
                     (a (if (and (list? j) (pair? j) (string? (caar j)))
                            (json-object->alist j)
                            (error "expected json object per line" line))))
                (loop (cons (cons '(_raw-line . line) a) out))))))))))

(define (read-line port)
  (let loop ((chars '())
             (ch (read-char port)))
    (if (eof-object? ch)
        (if (null? chars) (eof-object) (list->string (reverse chars)))
        (if (char=? ch #\newline)
            (list->string (reverse chars))
            (loop (cons ch chars) (read-char port))))))

(define (ensure pred msg x) (if (pred x) x (error msg x)))

(define (kind->string k)
  (cond ((string? k) k)
        ((symbol? k) (symbol->string k))
        (else (error "kind must be string/symbol" k))))

(define (validate-canvasl-1-record! r)
  ;; Minimal deterministic validator aligned with schemas/canvasl-1.0.schema.json
  (let ((schema (alist-ref r 'schema))
        (phase (alist-ref r 'phase))
        (kind (alist-ref r 'kind)))
    (ensure string? "schema must be string" schema)
    (if (not (string=? schema "canvasl-1.0")) (error "schema must be canvasl-1.0" schema))
    (ensure integer? "phase must be integer" phase)
    (ensure (lambda (x) (>= x 0)) "phase must be >=0" phase)
    (set! kind (kind->string kind))
    (if (not (member kind '("context" "transition" "validation" "projection" "commit")))
        (error "invalid kind" kind))
    ;; required body fields by kind
    (cond
     ((string=? kind "context")
      (ensure (lambda (x) (and x (list? x))) "context must be object" (alist-ref r 'context)))
     ((string=? kind "transition")
      (ensure (lambda (x) (and x (list? x))) "apply must be object" (alist-ref r 'apply)))
     ((string=? kind "validation")
      (ensure list? "checks must be array" (alist-ref r 'checks))
      (ensure boolean? "result must be boolean" (alist-ref r 'result)))
     ((string=? kind "projection")
      (ensure string? "type must be string" (alist-ref r 'type))
      (ensure string? "input_context must be string" (alist-ref r 'input_context))
      (ensure list? "points must be array" (alist-ref r 'points))
      (ensure list? "lines must be array" (alist-ref r 'lines)))
     ((string=? kind "commit")
      (ensure string? "state_hash must be string" (alist-ref r 'state_hash))
      (ensure string? "previous must be string" (alist-ref r 'previous))
      (ensure string? "device must be string" (alist-ref r 'device))
      (ensure integer? "timestamp must be integer" (alist-ref r 'timestamp))))
    r))

(define (check-phase-monotone! records)
  (let loop ((xs records) (prev -1))
    (if (null? xs) #t
        (let ((p (alist-ref (car xs) 'phase)))
          (if (< p prev) (error "phase monotonicity violated" (list prev p))
              (loop (cdr xs) p))))))

(define (append-records-to-nrr! repo-path records)
  (init-nrr 'file repo-path)
  (nrr-log-clear)
  (let ((log-path (string-append repo-path "/log.txt")))
    ;; Load existing log if present; ignore if missing.
    (catch #t
      (lambda () (load-log log-path))
      (lambda (key . args) #t))
    (let loop ((xs records))
      (if (null? xs)
          (begin (save-log log-path) #t)
          (let* ((r (car xs))
                 (phase (alist-ref r 'phase))
                 (raw (alist-ref r '_raw-line))
                 (ref (nrr-put raw))
                 (e (make-log-entry phase 'interior ref)))
            (nrr-append e)
            (loop (cdr xs)))))))

(define (derive-k records)
  ;; Prefer last context.context.complexity if present, else count vertices, else 0
  (let loop ((xs (reverse records)))
    (if (null? xs) 0
        (let* ((r (car xs))
               (k (kind->string (alist-ref r 'kind))))
          (if (string=? k "context")
              (let* ((ctx (alist-ref r 'context))
                     (c (and (list? ctx) (alist-ref ctx 'complexity))))
                (if (integer? c) c 0))
              (loop (cdr xs)))))))

(define (derive-fano records)
  ;; Use last projection record of type fano if present
  (let loop ((xs (reverse records)))
    (if (null? xs)
        (list #f '() '())
        (let* ((r (car xs))
               (k (kind->string (alist-ref r 'kind))))
          (if (string=? k "projection")
              (let ((t (alist-ref r 'type)))
                (if (and (string? t) (string=? t "fano"))
                    (list #t (alist-ref r 'points) (alist-ref r 'lines))
                    (loop (cdr xs))))
              (loop (cdr xs)))))))

(define (derive-has-decision? records)
  (let loop ((xs records))
    (if (null? xs) #f
        (let ((k (kind->string (alist-ref (car xs) 'kind))))
          (if (string=? k "commit") #t (loop (cdr xs)))))))

(define (records->clbc-vm-hash records)
  ;; Convert JSON-derived records to the alist model expected by CLBC compiler:
  ;; - ensure kind is a string
  ;; - remove internal _raw-line
  (let* ((records2 (map (lambda (r)
                          (let ((k (kind->string (alist-ref r 'kind))))
                            (cons (cons 'kind k)
                                  (filter (lambda (p) (not (eq? (car p) '_raw-line))) r))))
                        records))
         (enc (canvasl-records->clbc records2))
         (bytes (cdr enc))
         (res (vm-run-clbc-bytes bytes)))
    (alist-ref res 'transcript-hash)))

(define (emit-json x)
  (display (scm->json-string x))
  (newline))

(define (usage!)
  (display "usage: guile tools/canvasl-engine-jsonl.scm --repo PATH --jsonl FILE (--getScene|--getTrace|--getIncidence)\n")
  (exit 2))

(define (main argv)
  (let loop ((args (cdr argv)) (repo #f) (jsonl #f) (mode #f))
    (cond
     ((null? args)
      (if (and repo jsonl mode)
          (let* ((records (read-jsonl jsonl)))
            (for-each validate-canvasl-1-record! records)
            (check-phase-monotone! records)
            (append-records-to-nrr! repo records)
            (let* ((k (derive-k records))
                   (has-decision (derive-has-decision? records))
                   (f (derive-fano records))
                   (has-fano (car f))
                   (points (cadr f))
                   (lines (caddr f)))
              (cond
               ((eq? mode 'scene)
                (emit-json (viz-make-scene k has-decision has-fano points lines)))
               ((eq? mode 'trace)
                (emit-json `((transcriptHash . ,(records->clbc-vm-hash records)))))
               ((eq? mode 'incidence)
                (emit-json `((type . "fano")
                             (present . ,(if has-fano #t #f))
                             (points . ,points)
                             (lines . ,lines))))
               (else (usage!)))))
          (usage!)))
     ((string=? (car args) "--repo")
      (if (null? (cdr args)) (usage!)
          (loop (cddr args) (cadr args) jsonl mode)))
     ((string=? (car args) "--jsonl")
      (if (null? (cdr args)) (usage!)
          (loop (cddr args) repo (cadr args) mode)))
     ((string=? (car args) "--getScene") (loop (cdr args) repo jsonl 'scene))
     ((string=? (car args) "--getTrace") (loop (cdr args) repo jsonl 'trace))
     ((string=? (car args) "--getIncidence") (loop (cdr args) repo jsonl 'incidence))
     (else (usage!)))))

(main (command-line))


