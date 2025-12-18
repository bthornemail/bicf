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
(canvasl1-load-relative "../clbc/compiler.scm")

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

;; -----------------------------
;; Canonical item bytes (for stableSecondaryKey)
;; -----------------------------

(define (alist? x)
  (and (list? x)
       (let loop ((xs x))
         (if (null? xs)
             #t
             (and (pair? (car xs))
                  (symbol? (car (car xs)))
                  (loop (cdr xs)))))))

(define (symbol<? a b) (string<? (symbol->string a) (symbol->string b)))

(define (sort-alist a)
  (sort a (lambda (p q) (symbol<? (car p) (car q)))))

(define (to-jsonable x)
  ;; Deterministic JSON encoding substrate:
  ;; - objects: alists with string keys, sorted
  ;; - arrays: vectors
  ;; - numbers: integers only (floats forbidden here)
  (cond
   ((alist? x)
    (map (lambda (p)
           (cons (symbol->string (car p)) (to-jsonable (cdr p))))
         (sort-alist x)))
   ((list? x)
    (list->vector (map to-jsonable x)))
   ((integer? x) x)
   ((number? x) (error "canvasl1: floating point forbidden in canonical item encoding" x))
   ((symbol? x) (symbol->string x))
   (else x)))

(define (canonical-item-bytes item)
  ;; bytes used only for stableSecondaryKey tie-break
  (let ((s (scm->json-string (to-jsonable item))))
    ;; hash-content expects string or bytes; string path uses UTF-8.
    s))

(define (stable-secondary-key item)
  (hash-content (canonical-item-bytes item)))

;; -----------------------------
;; Normalization (set-like fields with total ordering + dedupe)
;; -----------------------------

(define (lex<? a b)
  (cond
   ((and (null? a) (null? b)) #f)
   ((null? a) #t)
   ((null? b) #f)
   ((< (car a) (car b)) #t)
   ((> (car a) (car b)) #f)
   (else (lex<? (cdr a) (cdr b)))))

(define (dedupe-by-key xs key-fn)
  (let loop ((ys xs) (seen '()) (out '()))
    (if (null? ys)
        (reverse out)
        (let* ((x (car ys))
               (k (key-fn x)))
          (if (member k seen)
              (loop (cdr ys) seen out)
              (loop (cdr ys) (cons k seen) (cons x out)))))))

(define (normalize-projection rec)
  (let* ((pts (alist-ref/req rec 'points))
         (lines (alist-ref/req rec 'lines))
         (pts2 (sort (dedupe-by-key pts (lambda (x) x)) <))
         (norm-triad (lambda (t)
                       (let* ((t2 (sort (map (lambda (x) (ensure integer? "canvasl1: triad must be integers" x)) t) <)))
                         t2)))
         (lines2 (map norm-triad lines))
         (lines3 (sort (dedupe-by-key lines2 (lambda (t) (string-append (number->string (car t)) "," (number->string (cadr t)) "," (number->string (caddr t)))))
                       (lambda (a b) (lex<? a b)))))
    (cons (cons 'points pts2)
          (cons (cons 'lines lines3)
                (filter (lambda (p) (and (pair? p) (not (eq? (car p) 'points)) (not (eq? (car p) 'lines)))) rec)))))

(define (vertex-kind v)
  ;; Spec text says (id, kind, stableSecondaryKey); interpret kind as role.
  (let ((r (alist-ref v 'role)))
    (cond ((string? r) r) ((symbol? r) (symbol->string r)) (else ""))))

(define (normalize-context ctx)
  (let* ((verts (alist-ref/req ctx 'vertices))
         (edges (alist-ref ctx 'edges))
         (faces (alist-ref ctx 'faces))
         (verts2 (map (lambda (v) (cons (cons 'stableSecondaryKey (stable-secondary-key v)) v)) verts))
         (verts3 (sort verts2
                       (lambda (a b)
                         (let* ((ida (alist-ref/req a 'id)) (idb (alist-ref/req b 'id))
                                (ka (vertex-kind a)) (kb (vertex-kind b))
                                (sa (alist-ref/req a 'stableSecondaryKey)) (sb (alist-ref/req b 'stableSecondaryKey)))
                           (cond
                            ((string<? ida idb) #t)
                            ((string<? idb ida) #f)
                            ((string<? ka kb) #t)
                            ((string<? kb ka) #f)
                            (else (string<? sa sb)))))))
         (verts4 (dedupe-by-key verts3 (lambda (v) (alist-ref/req v 'id))))
         (edges2 (if (and edges (list? edges))
                     (let* ((edgesA (map (lambda (e) (cons (cons 'stableSecondaryKey (stable-secondary-key e)) e)) edges))
                            (edgesB (sort edgesA
                                          (lambda (a b)
                                            (let* ((fa (alist-ref/req a 'from)) (fb (alist-ref/req b 'from))
                                                   (ta (alist-ref/req a 'to)) (tb (alist-ref/req b 'to))
                                                   (tya (alist-ref/req a 'type)) (tyb (alist-ref/req b 'type))
                                                   (wa (alist-ref a 'weight)) (wb (alist-ref b 'weight))
                                                   (wa2 (if (or (not wa) (eq? wa 'null)) 0 wa))
                                                   (wb2 (if (or (not wb) (eq? wb 'null)) 0 wb))
                                                   (sa (alist-ref/req a 'stableSecondaryKey)) (sb (alist-ref/req b 'stableSecondaryKey)))
                                              (cond
                                               ((string<? fa fb) #t) ((string<? fb fa) #f)
                                               ((string<? ta tb) #t) ((string<? tb ta) #f)
                                               ((string<? tya tyb) #t) ((string<? tyb tya) #f)
                                               ((< wa2 wb2) #t) ((< wb2 wa2) #f)
                                               (else (string<? sa sb))))))))
                       (dedupe-by-key edgesB (lambda (e)
                                               (let ((w (alist-ref e 'weight)))
                                                 (list (alist-ref/req e 'from) (alist-ref/req e 'to) (alist-ref/req e 'type)
                                                       (if (or (not w) (eq? w 'null)) 0 w))))))
                     '()))
         (faces2 (if (and faces (list? faces))
                     (let* ((facesA (map (lambda (f) (cons (cons 'stableSecondaryKey (stable-secondary-key f)) f)) faces))
                            (facesB (sort facesA
                                          (lambda (a b)
                                            (let* ((va (sort (alist-ref/req a 'vertices) string<?))
                                                   (vb (sort (alist-ref/req b 'vertices) string<?))
                                                   (ca (alist-ref a 'constraint)) (cb (alist-ref b 'constraint))
                                                   (ca2 (if (or (not ca) (eq? ca 'null)) "" ca))
                                                   (cb2 (if (or (not cb) (eq? cb 'null)) "" cb))
                                                   (sa (alist-ref/req a 'stableSecondaryKey)) (sb (alist-ref/req b 'stableSecondaryKey)))
                                              (cond
                                               ((string<? (string-join va ",") (string-join vb ",")) #t)
                                               ((string<? (string-join vb ",") (string-join va ",")) #f)
                                               ((string<? ca2 cb2) #t)
                                               ((string<? cb2 ca2) #f)
                                               (else (string<? sa sb))))))))
                       (dedupe-by-key facesB (lambda (f)
                                               (let ((vs (sort (alist-ref/req f 'vertices) string<?))
                                                     (c (alist-ref f 'constraint)))
                                                 (list (string-join vs ",") (if (or (not c) (eq? c 'null)) "" c))))))
                     '())))
    (let ((ctx2 (cons (cons 'vertices verts4)
                      (cons (cons 'edges edges2)
                            (cons (cons 'faces faces2)
                                  (filter (lambda (p) (and (pair? p)
                                                           (not (eq? (car p) 'vertices))
                                                           (not (eq? (car p) 'edges))
                                                           (not (eq? (car p) 'faces))))
                                          ctx))))))
      ctx2)))

(define (normalize-record rec)
  (let ((kind (alist-ref/req rec 'kind)))
    (cond
     ((string=? kind "projection") (normalize-projection rec))
     ((string=? kind "context")
      (let* ((ctx (alist-ref/req rec 'context))
             (ctx2 (normalize-context ctx)))
        (cons (cons 'context ctx2)
              (filter (lambda (p) (and (pair? p) (not (eq? (car p) 'context)))) rec))))
     (else rec))))

;; Convert Guile JSON result into deterministic alists with symbol keys.
;; - Objects become alists sorted by key lexicographically.
;; - Arrays become lists.
;; - Numbers remain numbers; booleans remain booleans; null -> 'null
(define (json->canon x)
  (cond
   ;; guile-json may decode objects as (("k" . v) ...) lists rather than hash tables
   ((and (list? x)
         (let loop ((xs x))
           (if (null? xs) #t
               (and (pair? (car xs))
                    (string? (car (car xs)))
                    (loop (cdr xs))))))
    (let* ((keys (map car x))
           (skeys (sort-strings keys)))
      (let loop2 ((ks skeys) (out '()))
        (if (null? ks)
            (reverse out)
            (let* ((kstr (car ks))
                   (v (cdr (assoc kstr x))))
              (loop2 (cdr ks)
                     (cons (cons (string->symbol kstr) (json->canon v)) out)))))))
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
    ;; records: list of normalized CanvasL v1 records (alist)
    (records . ())
    ;; trace_id: canonical identity of the current trace prefix:
    ;;   sha256(CLBC_container_bytes(records))
    (trace_id . #f)))

(define (state-get state k) (alist-ref state k))
(define (state-set state k v) (cons (cons k v) state))

(define (assoc-set al k v)
  (cons (cons k v) al))

(define (assoc-get al k)
  (let ((p (assoc k al))) (if p (cdr p) #f)))

(define (trace-id-for-records records)
  (let* ((enc (canvasl-records->clbc (map canvasl1-record->clbc-record records)))
         (clbc-bytes (cdr enc))
         (hex (hash-content clbc-bytes)))
    (string-append "sha256:" hex)))

;; -----------------------------
;; Adapter: CanvasL v1 JSON record -> CLBC compiler record (alist dialect)
;; -----------------------------

(define (face->abc face)
  (let* ((vs (sort (alist-ref/req face 'vertices) string<?)))
    (if (not (= (length vs) 3))
        (error "canvasl1: face must have 3 vertices" face)
        `((a . ,(list-ref vs 0))
          (b . ,(list-ref vs 1))
          (c . ,(list-ref vs 2))
          (constraint . ,(alist-ref/req face 'constraint))))))

(define (canvasl1-record->clbc-record rec)
  ;; rec is normalized CanvasL v1 record.
  (let* ((kind (alist-ref/req rec 'kind))
         (phase (alist-ref/req rec 'phase)))
    (cond
     ((string=? kind "context")
      (let* ((ctx (alist-ref/req rec 'context)))
        `((kind . "context")
          (phase . ,phase)
          (ctx-id . ,(alist-ref/req ctx 'id))
          (complexity . ,(alist-ref/req ctx 'complexity))
          (shape . ,(alist-ref/req ctx 'shape))
          (vertices . ,(alist-ref/req ctx 'vertices))
          (edges . ,(or (alist-ref ctx 'edges) '()))
          (faces . ,(map face->abc (or (alist-ref ctx 'faces) '())))
          (key . ,(alist-ref ctx 'key)))))
     ((string=? kind "projection")
      `((kind . "projection")
        (phase . ,phase)
        (type . ,(alist-ref/req rec 'type))
        (input_context . ,(alist-ref/req rec 'input_context))
        (points . ,(alist-ref/req rec 'points))
        (lines . ,(alist-ref/req rec 'lines))))
     ((string=? kind "validation")
      `((kind . "validation")
        (phase . ,phase)
        (checks . ,(alist-ref/req rec 'checks))
        (result . ,(alist-ref/req rec 'result))
        (hash . ,(alist-ref rec 'hash))))
     ((string=? kind "transition")
      ;; Minimal mapping: flatten apply.operator to operator; pass through optional fields.
      (let* ((apply (alist-ref/req rec 'apply)))
        `((kind . "transition")
          (phase . ,phase)
          (operator . ,(alist-ref/req apply 'operator))
          (coefficients_ref . ,(alist-ref apply 'coefficients_ref))
          (variables . ,(or (alist-ref apply 'variables) '()))
          (output . ,(alist-ref apply 'output)))))
     ((string=? kind "commit")
      `((kind . "commit")
        (phase . ,phase)
        (state_hash . ,(alist-ref/req rec 'state_hash))
        (previous . ,(alist-ref/req rec 'previous))
        (device . ,(alist-ref/req rec 'device))
        (timestamp . ,(alist-ref/req rec 'timestamp))))
     (else
      (error "canvasl1: cannot map kind to CLBC" kind)))))

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

(define (nrr-append-clbc-trace phase kind records json-line)
  ;; Canonical storage: store CLBC container bytes as authoritative payload.
  ;; JSONL MAY be stored as a supplemental blob, but MUST NOT participate in hashing/replay.
  (let* ((enc (canvasl-records->clbc records))
         (clbc-bytes (cdr enc))
         (ref (nrr-put clbc-bytes))
         (entry (make-log-entry phase (kind->log-type kind) ref)))
    (nrr-append entry)
    ;; supplemental JSONL (best-effort)
    (catch #t
      (lambda () (nrr-put json-line))
      (lambda (key . args) #t))
    ref))

;; -----------------------------
;; Execution semantics (MVP but deterministic)
;; -----------------------------

(define (apply-record state rec json-line)
  (let* ((recN (normalize-record rec)))
    (validate-canvasl1-record recN)
  (let* ((prev-phase (alist-ref/req state 'phase))
         (phase (alist-ref/req recN 'phase))
         (kind (alist-ref/req recN 'kind)))
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
          (let* ((ptype (alist-ref/req recN 'type)))
            (if (not (string=? ptype "fano"))
                (error "canvasl1: unsupported projection type" ptype)
                (let* ((points (alist-ref/req recN 'points))
                       (lines (alist-ref/req recN 'lines))
                       (decoded (fano-norm-structure points lines)))
                  (check-fano-incidence decoded '())
                  #t)))))
       ((string=? kind "transition")
        (let ((apply (alist-ref/req recN 'apply)))
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

    ;; Update record list and canonical trace id
    (let* ((records0 (alist-ref/req state 'records))
           (trace0 (alist-ref state 'trace_id))
           (trace0* (if trace0 trace0 (trace-id-for-records records0))))
      ;; Commit record seals the *pre-commit* trace identity.
      (if (string=? kind "commit")
          (let ((state-hash (alist-ref/req recN 'state_hash)))
            (if (not (string=? state-hash trace0*))
                (error "canvasl1: commit state_hash mismatch" (list state-hash trace0*))
                #t))
          #t)

      (let* ((records1 (append records0 (list recN)))
             (trace1 (trace-id-for-records records1)))
        ;; NRR append-only log (if initialized): store canonical CLBC bytes
        (if (and (defined? 'get-storage-backend) (get-storage-backend))
            (nrr-append-clbc-trace phase kind records1 json-line)
            #t)

        ;; Apply state updates
        (let ((state2 (cons (cons 'phase phase)
                            (cons (cons 'records records1)
                                  (cons (cons 'trace_id trace1)
                                        (filter (lambda (p)
                                                  (and (pair? p)
                                                       (not (eq? (car p) 'phase))
                                                       (not (eq? (car p) 'records))
                                                       (not (eq? (car p) 'trace_id))))
                                                state))))))
        (cond
         ((string=? kind "context")
          (let* ((ctx (alist-ref/req recN 'context))
                 (id (alist-ref/req ctx 'id)))
            (let* ((contexts0 (alist-ref/req state 'contexts))
                   (contexts2 (assoc-set contexts0 id recN)))
              (cons (cons 'contexts contexts2)
                    (cons (cons 'current_context id)
                          (filter (lambda (p) (and (pair? p) (not (eq? (car p) 'contexts)) (not (eq? (car p) 'current_context)))) state2))))))
         (else state2))))))
  ))

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
