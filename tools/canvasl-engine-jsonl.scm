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
(use-modules (ice-9 rdelim))

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
(load-relative "src/viz/scene.scm")

(define (alist-ref a k) (let ((p (assq k a))) (if p (cdr p) #f)))

(define (json-object->alist obj)
  ;; obj is a guile-json "object" = alist of (string . value)
  (define (json-kv? x)
    (or (and (pair? x) (string? (car x)))      ; ("k" . v) or ("k" v1 v2 ...)
        (and (list? x) (pair? x) (string? (car x)))))
  (define (kv-key kv) (car kv))
  (define (kv-value kv)
    ;; guile-json may represent nested objects as: ("key" ("a" . 1) ("b" . 2))
    (cond
     ((pair? kv)
      (let ((tail (cdr kv)))
        (cond
         ((and (pair? tail) (null? (cdr tail))) (car tail)) ;; ("k" v)
         ((and (pair? tail) (pair? (car tail)) (string? (caar tail))) tail) ;; ("k" (("a" . 1) ...))
         (else tail))))
     (else (error "unexpected json kv" kv))))
  (define (canon x)
    (cond
     ((and (list? x) (every json-kv? x))
      (json-object->alist x))
     ((vector? x) (map canon (vector->list x)))
     ((list? x) (map canon x))
     (else x)))
  (define (every pred xs)
    (cond ((null? xs) #t)
          ((pred (car xs)) (every pred (cdr xs)))
          (else #f)))
  (map (lambda (kv)
         (cons (string->symbol (kv-key kv)) (canon (kv-value kv))))
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
                (loop (cons (cons (cons '_raw-line line) a) out))))))))))

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

(define (records->transcript-hash records)
  ;; Deterministic rolling hash over raw JSONL lines.
  ;; This is the canonical trace identity for the JSONL engine boundary.
  (let loop ((xs records) (h "hash:0"))
    (if (null? xs)
        h
        (let* ((raw (alist-ref (car xs) '_raw-line))
               (h2 (string-append "hash:" (hash-content (string-append h "|" raw)))))
          (loop (cdr xs) h2)))))

(define (normalize-scene scene)
  ;; src/viz/scene.scm returns: '((ContextRoot (ClosureEnvelope . ...) ...))
  ;; Normalize to an alist: '((ContextRoot . ((ClosureEnvelope . ...) ...))).
  (if (and (list? scene)
           (= (length scene) 1)
           (list? (car scene))
           (pair? (car scene))
           (symbol? (caar scene)))
      (list (cons (symbol->string (caar scene)) (cdar scene)))
      scene))

(define (alist? x)
  (and (list? x)
       (let loop ((xs x))
         (if (null? xs)
             #t
             (and (pair? (car xs))
                  (let ((k (car (car xs))))
                    (or (string? k) (symbol? k)))
                  (loop (cdr xs)))))))

(define (to-jsonable x)
  ;; Guile JSON expects:
  ;; - objects as alists of (string . value)
  ;; - arrays as vectors
  (cond
   ((eq? x 'none) "none")
   ((symbol? x) (symbol->string x))
   ((alist? x)
    (map (lambda (p)
           (cons (if (symbol? (car p)) (symbol->string (car p)) (car p))
                 (to-jsonable (cdr p))))
         x))
   ((list? x)
    (list->vector (map to-jsonable x)))
   (else x)))

(define (emit-json x)
  (display (scm->json-string (to-jsonable x)))
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
                (emit-json (normalize-scene (viz-make-scene k has-decision has-fano points lines))))
               ((eq? mode 'trace)
                (emit-json `((transcriptHash . ,(records->transcript-hash records)))))
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
