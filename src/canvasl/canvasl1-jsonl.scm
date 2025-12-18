;; ============================================================
;; CanvasL v1.0 JSONL Engine (Guile Scheme)
;; Canonical record model:
;;   schema="canvasl-1.0"
;;   kind ∈ {context, transition, validation, projection, commit}
;;
;; Determinism goals:
;; - Sequential by phase (monotone)
;; - No forward references (context ids / last-known context)
;; - Boundary checks are explicit and deterministic
;; - NRR append-only logging and replay support
;;
;; Notes:
;; - Uses Guile's (json) module for JSON parsing.
;; - Keeps runtime semantics deterministic: no clocks, no RNG, no network.
;; ============================================================

(use-modules (rnrs io ports))
(use-modules (ice-9 rdelim))
(use-modules (json))

(define (canvasl1-load-relative rel)
  (let* ((cf (current-filename))
         (base (if (and cf (string? cf))
                   (let loop ((i (- (string-length cf) 1)))
                     (if (< i 0) "."
                         (if (char=? (string-ref cf i) #\/)
                             (if (= i 0) "/" (substring cf 0 i))
                             (loop (- i 1)))))
                   (getcwd))))
    (load (string-append base "/" rel))))

(canvasl1-load-relative "../nrr/hash.scm")
(canvasl1-load-relative "../nrr/storage.scm")
(canvasl1-load-relative "../nrr/log-entry.scm")
(canvasl1-load-relative "../nrr/log.scm")
(canvasl1-load-relative "../fano/fano-checker.scm")

;; -----------------------------
;; Deterministic helpers
;; -----------------------------

(define (alist-ref a k)
  (let ((p (assq k a))) (if p (cdr p) #f)))

(define (alist-ref/req a k)
  (let ((v (alist-ref a k)))
    (if v v (error "canvasl1: missing required field" k a))))

(define (ensure pred msg x)
  (if (pred x) x (error msg x)))

(define (string-trim-both s)
  (ensure string? "canvasl1: expected string" s)
  (let* ((n (string-length s)))
    (let loop-left ((i 0))
      (if (>= i n)
          ""
          (if (char-whitespace? (string-ref s i))
              (loop-left (+ i 1))
              (let loop-right ((j (- n 1)))
                (if (< j i)
                    ""
                    (if (char-whitespace? (string-ref s j))
                        (loop-right (- j 1))
                        (substring s i (+ j 1))))))))))

(define (string->symbol-safe s)
  (cond
   ((symbol? s) s)
   ((string? s) (string->symbol s))
   (else (error "expected string/symbol" s))))

(define (sort-strings xs)
  (sort xs string<?))

;; Convert Guile JSON result into deterministic alists with symbol keys.
;; - Objects become alists sorted by key lexicographically.
;; - Arrays become lists.
;; - Numbers remain numbers; booleans remain booleans; null -> 'null
(define (json->canon x)
  (cond
   ((hash-table? x)
    (let* ((keys (hash-map->list (lambda (k v) k) x))
           (skeys (sort-strings (map (lambda (k) (if (string? k) k (format #f "~a" k))) keys))))
      (let loop ((ks skeys) (out '()))
        (if (null? ks)
            (reverse out)
            (let* ((kstr (car ks))
                   (v (hash-ref x kstr)))
              (loop (cdr ks)
                    (cons (cons (string->symbol kstr) (json->canon v)) out)))))))
   ((vector? x)
    (map json->canon (vector->list x)))
   ((list? x)
    (map json->canon x))
   ((eq? x #nil) 'null)
   (else x)))

(define (parse-json-line s)
  (ensure string? "canvasl1: expected JSON string" s)
  (json->canon (json-string->scm s)))

;; -----------------------------
;; Record validation (structural)
;; -----------------------------

(define *canvasl1-kinds* '("context" "transition" "validation" "projection" "commit"))

(define (kind-valid? k)
  (and (string? k) (member k *canvasl1-kinds*)))

(define (validate-canvasl1-record rec)
  (let ((schema (alist-ref/req rec 'schema))
        (phase (alist-ref/req rec 'phase))
        (kind (alist-ref/req rec 'kind)))
    (ensure string? "canvasl1: schema must be string" schema)
    (if (not (string=? schema "canvasl-1.0"))
        (error "canvasl1: unsupported schema" schema)
        #t)
    (ensure integer? "canvasl1: phase must be integer" phase)
    (if (< phase 0) (error "canvasl1: phase must be >= 0" phase) #t)
    (ensure kind-valid? "canvasl1: invalid kind" kind)
    ;; kind-specific required fields
    (cond
     ((string=? kind "context")
      (let ((ctx (alist-ref/req rec 'context)))
        (ensure list? "canvasl1: context must be object" ctx)
        (ensure string? "canvasl1: context.id must be string" (alist-ref/req ctx 'id))
        (ensure integer? "canvasl1: context.complexity must be integer" (alist-ref/req ctx 'complexity))
        (ensure string? "canvasl1: context.shape must be string" (alist-ref/req ctx 'shape))
        (ensure list? "canvasl1: context.vertices must be array" (alist-ref/req ctx 'vertices))
        #t))
     ((string=? kind "transition")
      (let ((apply (alist-ref/req rec 'apply)))
        (ensure list? "canvasl1: apply must be object" apply)
        (ensure string? "canvasl1: apply.operator must be string" (alist-ref/req apply 'operator))
        #t))
     ((string=? kind "validation")
      (begin
        (ensure list? "canvasl1: checks must be array" (alist-ref/req rec 'checks))
        (ensure boolean? "canvasl1: result must be boolean" (alist-ref/req rec 'result))
        #t))
     ((string=? kind "projection")
      (begin
        (ensure string? "canvasl1: projection.type must be string" (alist-ref/req rec 'type))
        (ensure string? "canvasl1: input_context must be string" (alist-ref/req rec 'input_context))
        (ensure list? "canvasl1: points must be array" (alist-ref/req rec 'points))
        (ensure list? "canvasl1: lines must be array" (alist-ref/req rec 'lines))
        #t))
     ((string=? kind "commit")
      (begin
        (ensure string? "canvasl1: state_hash must be string" (alist-ref/req rec 'state_hash))
        (ensure string? "canvasl1: previous must be string" (alist-ref/req rec 'previous))
        (ensure string? "canvasl1: device must be string" (alist-ref/req rec 'device))
        (ensure integer? "canvasl1: timestamp must be integer" (alist-ref/req rec 'timestamp))
        #t))
     (else #t))))

;; -----------------------------
;; Phase monotonicity + forward refs
;; -----------------------------

(define (phase-monotone? prev-phase phase)
  (<= prev-phase phase))

(define (state-empty)
  `((phase . -1)
    (contexts . ())
    (current_context . #f)
    (transcript . "hash:0")))

(define (state-get state k) (alist-ref state k))
(define (state-set state k v) (cons (cons k v) state))

(define (assoc-set al k v)
  (cons (cons k v) al))

(define (assoc-get al k)
  (let ((p (assoc k al))) (if p (cdr p) #f)))

;; Transcript hash: hash(prev || "|" || record_json_bytes)
(define (transcript-step prev-hash record-json)
  (string-append "hash:" (hash-content (string-append prev-hash "|" record-json))))

;; Normalize Fano points: accept 0..6 or 1..7. Returns 0..6.
(define (fano-norm-point p)
  (cond
   ((and (integer? p) (<= 0 p) (<= p 6)) p)
   ((and (integer? p) (<= 1 p) (<= p 7)) (- p 1))
   (else (error "canvasl1: invalid fano point id" p))))

(define (fano-norm-line line)
  (ensure list? "canvasl1: fano line must be array" line)
  (if (not (= (length line) 3))
      (error "canvasl1: fano line must have 3 points" line)
      (map fano-norm-point line)))

(define (fano-norm-structure points lines)
  `((points . ,(map fano-norm-point points))
    (lines . ,(map fano-norm-line lines))))

;; -----------------------------
;; NRR logging (append-only)
;; -----------------------------

(define (kind->log-type kind)
  (cond
   ((or (string=? kind "validation") (string=? kind "commit")) 'guarantee)
   (else 'interior)))

(define (nrr-append-json-record phase kind json-line)
  ;; Store the raw JSON line bytes as a string in NRR storage.
  ;; Deterministic: caller provides json-line as the exact bytes to log.
  (let* ((ref (nrr-put json-line))
         (entry (make-log-entry phase (kind->log-type kind) ref)))
    (nrr-append entry)
    ref))

;; -----------------------------
;; Execution semantics (MVP but deterministic)
;; -----------------------------

(define (apply-record state rec json-line)
  (validate-canvasl1-record rec)
  (let* ((prev-phase (alist-ref/req state 'phase))
         (phase (alist-ref/req rec 'phase))
         (kind (alist-ref/req rec 'kind)))
    (if (not (phase-monotone? prev-phase phase))
        (error "canvasl1: phase monotonicity violation" (list prev-phase phase))
        #t)

    ;; Forward ref checks:
    ;; - projection.input_context must exist
    ;; - transition variables must refer to known vertices in current context (if present)
    (let* ((contexts (alist-ref/req state 'contexts))
           (current (alist-ref state 'current_context)))
      (cond
       ((string=? kind "projection")
        (let* ((ctx-id (alist-ref/req rec 'input_context))
               (ctx (assoc-get contexts ctx-id)))
          (if (not ctx)
              (error "canvasl1: forward reference to unknown context" ctx-id)
              #t)
          ;; Validate Fano structure deterministically.
          (let* ((ptype (alist-ref/req rec 'type)))
            (if (not (string=? ptype "fano"))
                (error "canvasl1: unsupported projection type" ptype)
                (let* ((points (alist-ref/req rec 'points))
                       (lines (alist-ref/req rec 'lines))
                       (decoded (fano-norm-structure points lines)))
                  (check-fano-incidence decoded '())
                  #t)))))
       ((string=? kind "transition")
        (let ((apply (alist-ref/req rec 'apply)))
          (let ((vars (alist-ref apply 'variables)))
            (if (and vars (list? vars) current)
                (let* ((ctx (assoc-get contexts current))
                       (ctxobj (alist-ref/req ctx 'context))
                       (verts (alist-ref/req ctxobj 'vertices))
                       (vids (map (lambda (v) (alist-ref/req v 'id)) verts)))
                  (for-each
                   (lambda (v)
                     (if (not (member v vids))
                         (error "canvasl1: forward reference to unknown vertex" v)
                         #t))
                   vars))
                #t))))
       (else #t)))

    ;; NRR append-only log (if initialized)
    (if (and (defined? 'get-storage-backend) (get-storage-backend))
        (nrr-append-json-record phase kind json-line)
        #t)

    ;; Update transcript
    (let* ((prev-t (alist-ref/req state 'transcript))
           (t2 (transcript-step prev-t json-line)))
      ;; Commit records: verify state_hash matches transcript (deterministic)
      (if (string=? kind "commit")
          (let ((state-hash (alist-ref/req rec 'state_hash)))
            ;; Commit seals the pre-commit transcript hash.
            (if (not (string=? state-hash prev-t))
                (error "canvasl1: commit state_hash mismatch" (list state-hash prev-t))
                #t))
          #t)

      ;; Apply state updates
      (let ((state2 (cons (cons 'phase phase)
                          (cons (cons 'transcript t2)
                                (filter (lambda (p) (and (pair? p) (not (eq? (car p) 'phase)) (not (eq? (car p) 'transcript)))) state))))))
        (cond
         ((string=? kind "context")
          (let* ((ctx (alist-ref/req rec 'context))
                 (id (alist-ref/req ctx 'id)))
            (let ((contexts2 (assoc-set contexts id rec)))
              (cons (cons 'contexts contexts2)
                    (cons (cons 'current_context id)
                          (filter (lambda (p) (and (pair? p) (not (eq? (car p) 'contexts)) (not (eq? (car p) 'current_context)))) state2))))))
         (else state2))))))

;; Filter helper (pure)
(define (filter pred xs)
  (cond
   ((null? xs) '())
   ((pred (car xs)) (cons (car xs) (filter pred (cdr xs))))
   (else (filter pred (cdr xs)))))

;; Execute a JSONL file. Returns final state alist.
(define (execute-canvasl1-jsonl path)
  (ensure string? "canvasl1: path must be string" path)
  (call-with-input-file path
    (lambda (port)
      (let loop ((state (state-empty)))
        (let ((line (read-line port)))
          (if (eof-object? line)
              state
              (let ((trimmed (string-trim-both line)))
                (if (or (string=? trimmed "") (char=? (string-ref trimmed 0) #\#))
                    (loop state)
                    (let* ((rec (parse-json-line trimmed))
                           (state2 (apply-record state rec trimmed)))
                      (loop state2))))))))))

;; Replay from NRR log: read JSON record strings and execute in order.
(define (replay-canvasl1-from-nrr)
  (let ((entries (nrr-log)))
    (let loop ((xs entries) (state (state-empty)))
      (if (null? xs)
          state
          (let* ((entry (car xs))
                 (phase (log-entry-phase entry))
                 (json-line (nrr-get (log-entry-ref entry)))
                 (rec (parse-json-line (string-trim-both json-line)))
                 ;; Force phase from entry for replay consistency (must match record)
                 (state2 (apply-record state (cons (cons 'phase phase) (filter (lambda (p) (not (eq? (car p) 'phase))) rec)) (string-trim-both json-line))))
            (loop (cdr xs) state2))))))
