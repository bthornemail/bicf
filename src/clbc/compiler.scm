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
  (let ((p (assq k a)))
    (if p
        (cdr p) ;; allow #f as a valid value (e.g., optional=false)
        (error "missing required field" k a))))

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

(define (u8-const label n)
  (if (u8? n) n (error label n)))

(define (bool->u8 b)
  (if (eq? b #t) 1 (if (eq? b #f) 0 (error "expected boolean" b))))

(define (shape->u8 s)
  ;; From mapping doc: 0=point,1=line,2=face,3=tetrahedron,4=5-cell,5=octahedron,6=cube,7=envelope
  (let ((x (string-or-symbol->string s)))
    (cond
     ((string=? x "point") 0)
     ((string=? x "line") 1)
     ((string=? x "face") 2)
     ((string=? x "tetrahedron") 3)
     ((or (string=? x "5-cell") (string=? x "5cell")) 4)
     ((string=? x "octahedron") 5)
     ((string=? x "cube") 6)
     ((string=? x "envelope") 7)
     (else (error "unknown shape" s)))))

(define (role->u8 r)
  ;; From mapping doc: 0=Q, 1=Σ, 2=L, 3=R, 4=δ, 5=s, 6=t, 7=r
  (let ((x (string-or-symbol->string r)))
    (cond
     ((string=? x "Q") 0)
     ((or (string=? x "Σ") (string-ci=? x "sigma")) 1)
     ((string=? x "L") 2)
     ((string=? x "R") 3)
     ((or (string=? x "δ") (string-ci=? x "delta")) 4)
     ((string=? x "s") 5)
     ((string=? x "t") 6)
     ((string=? x "r") 7)
     (else (error "unknown role" r)))))

(define (basis->u8 b)
  (let ((x (string-or-symbol->string b)))
    (if (and (>= (string-length x) 2) (char=? (string-ref x 0) #\e))
        (let ((n (string->number (substring x 1 (string-length x)))))
          (if (and (integer? n) (<= 0 n) (<= n 7)) n (error "basis must be e0..e7" b)))
        (error "basis must be e0..e7" b))))

(define (operator->u8 op)
  ;; 0=poly,1=rewrite,2=map
  (let ((x (string-or-symbol->string op)))
    (cond
     ((string=? x "poly") 0)
     ((string=? x "rewrite") 1)
     ((string=? x "map") 2)
     (else (error "unknown operator" op)))))

(define (proj-type->u8 t)
  ;; only 0=fano in v1 mapping
  (let ((x (string-or-symbol->string t)))
    (cond
     ((string=? x "fano") 0)
     (else (error "unknown projection type" t)))))

(define (build-id-map ids)
  ;; ids: list of strings; returns alist string->uleb128-id based on lexicographic unique order.
  (let* ((uniq (let loop ((xs ids) (seen '()) (out '()))
                 (if (null? xs)
                     out
                     (let ((s (car xs)))
                       (if (member s seen)
                           (loop (cdr xs) seen out)
                           (loop (cdr xs) (cons s seen) (cons s out)))))))
         (sorted (sort uniq string<?)))
    (let loop2 ((n 0) (xs sorted) (out '()))
      (if (null? xs) out
          (loop2 (+ n 1) (cdr xs) (cons (cons (car xs) n) out))))))

(define (id-map-ref m s)
  (let ((p (assoc s m)))
    (if p (cdr p) (error "id not in map" s))))

(define (encode-value string-table v)
  ;; Returns (strings-used . bytes) for value_type/value_payload.
  ;; Mapping doc types supported here:
  ;; 0=null, 1=bool(u8), 3=u64(uleb128), 4=str(sid uleb128), 5=bytes(len uleb128 + raw), 6=fixed32(4 bytes)
  (cond
   ((or (eq? v #f) (eq? v #t))
    (cons '() (list 1 (bool->u8 v))))
   ((eq? v 'null)
    (cons '() (list 0)))
   ((and (integer? v) (>= v 0))
    (cons '() (bytes-append (list 3) (uleb128-encode v))))
   ((string? v)
    (cons (list v) (bytes-append (list 4) (uleb128-encode (clbc-string->sid string-table v)))))
   ((and (list? v) (eq? (car v) 'bytes) (list? (cdr v)))
    (let ((payload (cdr v)))
      (cons '() (bytes-append (list 5) (uleb128-encode (length payload)) payload))))
   (else
    ;; fallback: stringify deterministically and treat as str
    (let ((s (call-with-output-string (lambda (p) (write v p)))))
      (cons (list s) (bytes-append (list 4) (uleb128-encode (clbc-string->sid string-table s))))))))

(define (encode-ctx-body record string-table)
  ;; Expects fields:
  ;; - (ctx-id . "ctx-...") (complexity . n) (shape . "tetrahedron")
  ;; - (vertices . ( ( (id . "v1") (role . "Q") (basis . "e0") (optional . #f) (value . 3) ) ...))
  ;; - (edges . ( ((from . "v1") (to . "v2") (type . "transition") (weight . 1)) ...)) optional
  ;; - (faces . ( ((a . "v1") (b . "v2") (c . "v3") (constraint . "fano")) ...)) optional
  ;; - (key . ((id . "k1") (authority . "local") (mutable . #f))) optional
  (let* ((ctx-id (string-or-symbol->string (require-field record 'ctx-id)))
         (complexity (require-field record 'complexity))
         (shape (alist-ref record 'shape))
         (vertices (or (alist-ref record 'vertices) '()))
         (edges (or (alist-ref record 'edges) '()))
         (faces (or (alist-ref record 'faces) '()))
         (key (alist-ref record 'key))
         (vtx-ids (map (lambda (v) (string-or-symbol->string (require-field v 'id))) vertices))
         (ctx-map (build-id-map (list ctx-id)))
         (vtx-map (build-id-map vtx-ids))
         (key-id (if key (string-or-symbol->string (require-field key 'id)) #f))
         (key-map (if key (build-id-map (list key-id)) '()))
         (strings '())
         (out '()))
    (set! out (cons (bytes-append (list OP_CTX_BEGIN) (uleb128-encode (id-map-ref ctx-map ctx-id))) out))
    (set! out (cons (bytes-append (list OP_CTX_META)
                                  (uleb128-encode (if (integer? complexity) complexity (error "complexity must be integer" complexity)))
                                  (list (shape->u8 (if shape shape (error "missing shape" record)))))
                    out))
    ;; VTX_DEF vtx_id role basis optional value_type value_payload
    (for-each
     (lambda (v)
       (let* ((vid (string-or-symbol->string (require-field v 'id)))
              (role (require-field v 'role))
              (basis (require-field v 'basis))
              (optional (require-field v 'optional))
              (value (alist-ref v 'value))
              (val-pair (encode-value string-table value)))
         (set! strings (append (car val-pair) strings))
         (set! out (cons (bytes-append (list OP_VTX_DEF)
                                       (uleb128-encode (id-map-ref vtx-map vid))
                                       (list (role->u8 role))
                                       (list (basis->u8 basis))
                                       (list (bool->u8 optional))
                                       (cdr val-pair))
                         out))))
     vertices)
    ;; EDGE_DEF from_vtx_id to_vtx_id edge_type_sid weight_type weight_payload
    (for-each
     (lambda (e)
       (let* ((from (string-or-symbol->string (require-field e 'from)))
              (to (string-or-symbol->string (require-field e 'to)))
              (etype (string-or-symbol->string (require-field e 'type)))
              (w (alist-ref e 'weight))
              (etype-sid (clbc-string->sid string-table etype))
              (w-pair (encode-value string-table w)))
         (set! strings (append (car w-pair) strings))
         (set! strings (cons etype strings))
         (set! out (cons (bytes-append (list OP_EDGE_DEF)
                                       (uleb128-encode (id-map-ref vtx-map from))
                                       (uleb128-encode (id-map-ref vtx-map to))
                                       (uleb128-encode etype-sid)
                                       (cdr w-pair))
                         out))))
     edges)
    ;; FACE_DEF a b c constraint_sid
    (for-each
     (lambda (f)
       (let* ((a (string-or-symbol->string (require-field f 'a)))
              (b (string-or-symbol->string (require-field f 'b)))
              (c (string-or-symbol->string (require-field f 'c)))
              (constraint (string-or-symbol->string (require-field f 'constraint)))
              (sid (clbc-string->sid string-table constraint)))
         (set! strings (cons constraint strings))
         (set! out (cons (bytes-append (list OP_FACE_DEF)
                                       (uleb128-encode (id-map-ref vtx-map a))
                                       (uleb128-encode (id-map-ref vtx-map b))
                                       (uleb128-encode (id-map-ref vtx-map c))
                                       (uleb128-encode sid))
                         out))))
     faces)
    ;; KEY_DEF key_id authority mutable
    (if key
        (let* ((auth (string-or-symbol->string (require-field key 'authority)))
               (auth-u8 (cond ((string=? auth "local") 0) ((string=? auth "shared") 1) (else (error "authority must be local/shared" auth))))
               (mut (require-field key 'mutable)))
          (set! out (cons (bytes-append (list OP_KEY_DEF)
                                        (uleb128-encode (id-map-ref key-map key-id))
                                        (list auth-u8)
                                        (list (bool->u8 mut)))
                          out))))
    (set! out (cons (list OP_CTX_END) out))
    (cons strings (apply bytes-append (reverse out)))))

(define (encode-transition-body record string-table)
  ;; Expects (operator . "poly") (coeff-ref . "sha256:...") (vars . ("v1" ...)) (out . "v2")
  (let* ((op (require-field record 'operator))
         (coeff (alist-ref record 'coeff-ref))
         (vars (or (alist-ref record 'vars) '()))
         (outv (require-field record 'out))
         (vmap (build-id-map (map string-or-symbol->string (append vars (list outv)))))
         (strings '())
         (out '()))
    (set! out (cons (bytes-append (list OP_APPLY_BEGIN) (list (operator->u8 op))) out))
    (if (string? coeff)
        (begin
          (set! strings (cons coeff strings))
          (set! out (cons (bytes-append (list OP_APPLY_COEFF_REF)
                                        (uleb128-encode (clbc-string->sid string-table coeff)))
                          out))))
    (let ((ids (map (lambda (s) (id-map-ref vmap (string-or-symbol->string s))) vars)))
      (set! out (cons (bytes-append (list OP_APPLY_VARS) (uleb128-encode (length ids))
                                    (apply bytes-append (map uleb128-encode ids)))
                      out)))
    (set! out (cons (bytes-append (list OP_APPLY_OUT) (uleb128-encode (id-map-ref vmap (string-or-symbol->string outv)))) out))
    (set! out (cons (list OP_APPLY_END) out))
    (cons strings (apply bytes-append (reverse out)))))

(define (encode-projection-body record string-table)
  ;; Expects (proj-type . "fano") (input-ctx . "ctx-...") (points . (0..)) (lines . ((0 1 3) ...))
  (let* ((ptype (require-field record 'proj-type))
         (ctx (string-or-symbol->string (require-field record 'input-ctx)))
         (ctx-map (build-id-map (list ctx)))
         (points (or (alist-ref record 'points) '()))
         (lines (or (alist-ref record 'lines) '())))
    (cons '()
          (bytes-append
           (bytes-append (list OP_PROJ_BEGIN) (list (proj-type->u8 ptype)))
           (bytes-append (list OP_PROJ_INPUT) (uleb128-encode (id-map-ref ctx-map ctx)))
           (bytes-append (list OP_PROJ_POINTS) (uleb128-encode (length points)) (map (lambda (x) (u8-const "point must be u8" x)) points))
           (bytes-append (list OP_PROJ_LINES)
                         (uleb128-encode (length lines))
                         (apply bytes-append
                                (map (lambda (tri)
                                       (if (and (list? tri) (= (length tri) 3))
                                           (map (lambda (x) (u8-const "line point must be u8" x)) tri)
                                           (error "line must be triad" tri)))
                                     lines)))
           (list OP_PROJ_END)))))

(define (encode-commit-body record string-table)
  ;; Expects (state-hash . "sha256:...") (prev-hash . "sha256:...") (device . "esp32") (timestamp . n)
  (let* ((state (string-or-symbol->string (require-field record 'state-hash)))
         (prev (string-or-symbol->string (require-field record 'prev-hash)))
         (device (string-or-symbol->string (require-field record 'device)))
         (ts (require-field record 'timestamp)))
    (cons (list state prev device)
          (bytes-append (list OP_COMMIT)
                        (uleb128-encode (clbc-string->sid string-table state))
                        (uleb128-encode (clbc-string->sid string-table prev))
                        (uleb128-encode (clbc-string->sid string-table device))
                        (u64le-encode (if (and (integer? ts) (>= ts 0)) ts (error "timestamp must be non-negative integer" ts)))))))

(define (compile-record record string-table)
  ;; Returns (strings-used . record-bytes)
  (let* ((phase (require-field record 'phase))
         (op (or (alist-ref record 'kind) (alist-ref record 'op)))
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
            ((= kind KIND_CONTEXT)
             (let ((p (encode-ctx-body record string-table)))
               (set! strings (append (car p) strings))
               (cdr p)))
            ((= kind KIND_TRANSITION)
             (let ((p (encode-transition-body record string-table)))
               (set! strings (append (car p) strings))
               (cdr p)))
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
            ((= kind KIND_PROJECTION)
             (let ((p (encode-projection-body record string-table)))
               (set! strings (append (car p) strings))
               (cdr p)))
            ((= kind KIND_COMMIT)
             (let ((p (encode-commit-body record string-table)))
               (set! strings (append (car p) strings))
               (cdr p)))
            (else
             ;; For other kinds in MVP: encode empty record body.
             '()))
           (encode-end-record)))))

(define (canvasl-records->clbc records)
  ;; Two-pass: collect strings, build canonical string table, compile record stream.
  (define (collect-strings-record r)
    (let ((kind (or (alist-ref r 'kind) (alist-ref r 'op))))
      (cond
       ((or (not kind) (not (or (string? kind) (symbol? kind)))) '())
       ((string=? (string-or-symbol->string kind) "context")
        (let* ((edges (or (alist-ref r 'edges) '()))
               (faces (or (alist-ref r 'faces) '())))
          (append
           ;; edge types are interned strings
           (let loop ((es edges) (out '()))
             (if (null? es) out
                 (let ((t (alist-ref (car es) 'type)))
                   (loop (cdr es) (if (string? t) (cons t out) out)))))
           ;; face constraints are interned strings (e.g. "fano")
           (let loop ((fs faces) (out '()))
             (if (null? fs) out
                 (let ((c (alist-ref (car fs) 'constraint)))
                   (loop (cdr fs) (if (string? c) (cons c out) out))))))))
       ((string=? (string-or-symbol->string kind) "projection")
        ;; no additional strings beyond possible constraints handled elsewhere
        '())
       ((string=? (string-or-symbol->string kind) "transition")
        (let ((cr (alist-ref r 'coefficients_ref)))
          (if (string? cr) (list cr) '())))
       ((string=? (string-or-symbol->string kind) "validation")
        (let ((h (alist-ref r 'hash)))
          (if (string? h) (list h) '())))
       ((string=? (string-or-symbol->string kind) "commit")
        (let ((sh (alist-ref r 'state_hash))
              (ph (alist-ref r 'previous))
              (dev (alist-ref r 'device)))
          (append (if (string? sh) (list sh) '())
                  (if (string? ph) (list ph) '())
                  (if (string? dev) (list dev) '()))))
       (else '()))))

  (let* ((strings (let loop ((xs records) (out '()))
                    (if (null? xs)
                        out
                        (loop (cdr xs) (append (collect-strings-record (car xs)) out)))))
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


