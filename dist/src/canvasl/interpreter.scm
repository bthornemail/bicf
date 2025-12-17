;; ============================================================
;; CanvasL-POLY Reference Interpreter (R5RS)
;; - Deterministic
;; - Spec-aligned ops: define_encoder, apply_encoder, decode_and_validate
;; - Input format: each line/record is an S-expression alist:
;;   '((id . "step-1") (phase . 1) (boundary . "FANO-v1") (anchor . "commit:abc")
;;     (op . "apply_encoder") (inputs . (...)) (outputs . (...)) ...)
;; ============================================================

;; -----------------------------
;; Utilities: alist access
;; -----------------------------
(define (alist-ref a k)
  (let ((p (assq k a)))
    (if p (cdr p) #f)))

(define (alist-ref/req a k)
  (let ((v (alist-ref a k)))
    (if v v (error "missing required field" k))))

(define (string->symbol-safe s)
  (if (symbol? s) s
      (if (string? s) (string->symbol s)
          (error "expected string/symbol" s))))

(define (ensure pred msg x)
  (if (pred x) x (error msg x)))

(define (list-of-strings? xs)
  (and (list? xs)
       (let loop ((xs xs))
         (if (null? xs) #t
             (and (string? (car xs)) (loop (cdr xs)))))))

;; -----------------------------
;; Environment: refs -> values
;; -----------------------------
(define (env-empty) '())

(define (env-get env ref)
  (let ((p (assoc ref env)))
    (if p (cdr p) #f)))

(define (env-get/req env ref)
  (let ((v (env-get env ref)))
    (if v v (error "unresolved reference" ref))))

(define (env-set env ref val)
  (cons (cons ref val) env))

;; -----------------------------
;; Boundary registry
;; -----------------------------
(define (boundary-reg-empty) '())

(define (boundary-reg-add reg id boundary-obj)
  (cons (cons id boundary-obj) reg))

(define (boundary-reg-get/req reg id)
  (let ((p (assoc id reg)))
    (if p (cdr p) (error "unknown boundary id" id))))

;; -----------------------------
;; Minimal linear algebra (lists)
;; vector: (x0 x1 ... x(k-1))
;; matrix: list of rows, each row is list length k
;; -----------------------------
(define (vec? v) (and (list? v) (let loop ((v v)) (if (null? v) #t (and (number? (car v)) (loop (cdr v)))))))
(define (mat? m) (and (list? m) (let loop ((m m)) (if (null? m) #t (and (vec? (car m)) (loop (cdr m)))))))

(define (dot a b)
  (let loop ((a a) (b b) (acc 0))
    (cond
      ((and (null? a) (null? b)) acc)
      ((or (null? a) (null? b)) (error "dot length mismatch"))
      (else (loop (cdr a) (cdr b) (+ acc (* (car a) (car b))))))))

(define (mat-vec-mul A x)
  (map (lambda (row) (dot row x)) A))

(define (vec-add a b)
  (let loop ((a a) (b b))
    (cond
      ((and (null? a) (null? b)) '())
      ((or (null? a) (null? b)) (error "vec-add length mismatch"))
      (else (cons (+ (car a) (car b))
                  (loop (cdr a) (cdr b)))))))

;; -----------------------------
;; Encoder representation
;; For reference, we only implement affine:
;;  E(x) = A*x + b
;; encoder object:
;;   '((kind . affine) (ring . "Z") (basis_dim . 8) (A-ref . "...") (b-ref . "..."))
;; -----------------------------
(define (make-encoder-affine ring basis-dim A-ref b-ref)
  `((kind . affine)
    (ring . ,ring)
    (basis_dim . ,basis-dim)
    (A_ref . ,A-ref)
    (b_ref . ,b-ref)))

(define (encoder-kind enc) (alist-ref/req enc 'kind))

;; -----------------------------
;; Boundary hooks (FANO/PCG etc.)
;; Boundary object is implementation-defined.
;; For reference, define shape:
;; '((id . "FANO-v1")
;;   (automorphism . "pgl3-2:std")
;;   (fano . <incidence-structure>)
;;   (pcg . <pcg-params>))
;; -----------------------------

;; Load validation modules
(load "../fano/fano-checker.scm")
(load "../consensus/pcg-validator.scm")

(define (check-schema step) #t)

(define (check-boundary-id-match step boundary-id)
  (let ((b (alist-ref/req step 'boundary)))
    (if (equal? b boundary-id) #t (error "boundary_id_mismatch" (list b boundary-id)))))

(define (check-automorphism-match step boundary)
  ;; Reference: accept always unless boundary includes required tag.
  ;; Replace with your real selection enforcement.
  #t)

;; Use actual FANO validation from fano-checker.scm
;; (check-fano-incidence is already defined in fano-checker.scm)

;; Use actual PCG validation from pcg-validator.scm
;; (check-pcg-pair-cover is already defined in pcg-validator.scm)

;; -----------------------------
;; Decoder (boundary-relative)
;; Reference decoder:
;; - "decoding" can be identity or canonicalization under boundary
;; - returns (decoded . proof)
;; -----------------------------
(define (decode-under-boundary encoded boundary)
  ;; Reference: decoded = encoded, proof = 'ok
  (cons encoded 'ok))

;; -----------------------------
;; Step execution
;; -----------------------------
(define (require-common-fields step)
  (alist-ref/req step 'id)
  (alist-ref/req step 'phase)
  (alist-ref/req step 'boundary)
  (alist-ref/req step 'anchor)
  (alist-ref/req step 'op)
  (let ((ins (alist-ref/req step 'inputs))
        (outs (alist-ref/req step 'outputs)))
    (ensure list? "inputs must be list" ins)
    (ensure list? "outputs must be list" outs)
    #t))

(define (strict-phase-check prev-phase step)
  (let ((p (alist-ref/req step 'phase)))
    (if (<= prev-phase p)
        p
        (error "phase_not_monotone" (list prev-phase p)))))

(define (no-forward-refs-check env step)
  (let ((ins (alist-ref/req step 'inputs)))
    (ensure list? "inputs must be list" ins)
    (for-each (lambda (r)
                (ensure string? "input ref must be string" r)
                (if (env-get env r) #t (error "unresolved input ref" r)))
              ins)
    #t))

;; Apply a step; returns (new-env . outputs-produced)
(define (exec-step env boundary-reg step)
  (require-common-fields step)

  (let* ((op (alist-ref/req step 'op))
         (boundary-id (alist-ref/req step 'boundary))
         (boundary (boundary-reg-get/req boundary-reg boundary-id)))

    (cond
      ;; -------------------------
      ;; define_encoder
      ;; -------------------------
      ((equal? op "define_encoder")
       (let* ((encoder-id (alist-ref/req step 'encoder_id))
              (ring (alist-ref/req step 'ring))
              (basis-dim (alist-ref/req step 'basis_dim))
              (poly-form (alist-ref/req step 'poly_form))
              (coeffs (alist-ref/req step 'coeffs))
              (outs (alist-ref/req step 'outputs)))

         (ensure string? "encoder_id must be string" encoder-id)
         (ensure string? "ring must be string" ring)
         (ensure integer? "basis_dim must be integer" basis-dim)
         (ensure string? "poly_form must be string" poly-form)
         (ensure list? "coeffs must be alist" coeffs)
         (ensure (lambda (x) (and (list? x) (not (null? x)))) "outputs must be nonempty" outs)

         (if (not (equal? poly-form "affine"))
             (error "reference interpreter supports only affine poly_form" poly-form)
             (let* ((A-ref (alist-ref/req coeffs 'A))
                    (b-ref (alist-ref/req coeffs 'b))
                    (enc (make-encoder-affine ring basis-dim A-ref b-ref))
                    (enc-ref (car outs)))
               (cons (env-set env enc-ref enc) outs)))))

      ;; -------------------------
      ;; apply_encoder
      ;; -------------------------
      ((equal? op "apply_encoder")
       (let* ((enc-ref (alist-ref/req step 'encoder_ref))
              (vars (alist-ref/req step 'vars))
              (outs (alist-ref/req step 'outputs)))

         (ensure string? "encoder_ref must be string" enc-ref)
         (ensure list? "vars must be alist" vars)
         (ensure (lambda (x) (and (list? x) (not (null? x)))) "outputs must be nonempty" outs)

         (let* ((enc (env-get/req env enc-ref))
                (kind (encoder-kind enc)))
           (cond
             ((eq? kind 'affine)
              (let* ((x-ref (alist-ref/req vars 'x))
                     (A-ref (alist-ref/req enc 'A_ref))
                     (b-ref (alist-ref/req enc 'b_ref))
                     (A (env-get/req env A-ref))
                     (b (env-get/req env b-ref))
                     (x (env-get/req env x-ref)))
                (ensure mat? "A must be matrix (list of vectors)" A)
                (ensure vec? "b must be vector" b)
                (ensure vec? "x must be vector" x)
                (let* ((Ax (mat-vec-mul A x))
                       (y (vec-add Ax b))
                       (out-ref (car outs)))
                  (cons (env-set env out-ref y) outs))))
             (else
              (error "unknown encoder kind" kind))))))

      ;; -------------------------
      ;; decode_and_validate
      ;; -------------------------
      ((equal? op "decode_and_validate")
       (let* ((target (alist-ref/req step 'target))
              (decoder (alist-ref/req step 'decoder))
              (checks (alist-ref/req step 'checks))
              (outs (alist-ref/req step 'outputs)))

         (ensure string? "target must be string ref" target)
         (ensure list? "decoder must be object/alist" decoder)
         (ensure list? "checks must be list" checks)
         (ensure (lambda (x) (>= (length x) 2)) "outputs must include decoded and proof" outs)

         (let* ((encoded (env-get/req env target))
                (dp (decode-under-boundary encoded boundary))
                (decoded (car dp))
                (proof (cdr dp)))

           ;; execute checks (order matters)
           (for-each
            (lambda (c)
              (cond
                ((equal? c "schema") (check-schema step))
                ((equal? c "boundary_id_match") (check-boundary-id-match step (alist-ref/req boundary 'id)))
                ((equal? c "automorphism_match") (check-automorphism-match step boundary))
                ((equal? c "fano_incidence") (check-fano-incidence decoded boundary))
                ((equal? c "pcg_pair_cover") (check-pcg-pair-cover decoded boundary))
                (else (error "unknown check" c))))
            checks)

           (let ((decoded-ref (car outs))
                 (proof-ref (cadr outs)))
             (cons (env-set (env-set env decoded-ref decoded) proof-ref proof)
                   outs)))))

      (else
       (error "unknown op" op)))))

;; -----------------------------
;; Trace execution
;; steps: list of alist records
;; returns final env
;; -----------------------------
(define (run-trace steps boundary-reg initial-env)
  (let loop ((steps steps) (env initial-env) (prev-phase -1) (boundary-id #f))
    (if (null? steps)
        env
        (let* ((step (car steps))
               (p (strict-phase-check prev-phase step))
               (b (alist-ref/req step 'boundary)))
          ;; single-boundary rule (reference default)
          (if (and boundary-id (not (equal? boundary-id b)))
              (error "multiple boundaries in one trace (reference mode)" (list boundary-id b))
              (begin
                (no-forward-refs-check env step)
                (let* ((r (exec-step env boundary-reg step))
                       (env2 (car r)))
                  (loop (cdr steps) env2 p (or boundary-id b)))))))))

;; ============================================================
;; Example: minimal 3-line trace (S-expr equivalent of JSONL)
;; ============================================================

;; boundary registry example
(define (make-fano-boundary id)
  `((id . ,id)
    (automorphism . "pgl3-2:std")
    (fano . placeholder)
    (pcg . placeholder)))

;; Example initial env with referenced A0, b0, and x(t1)
(define example-initial-env
  (let ((env (env-empty)))
    (let* ((A0 '((1 0 0 0 0 0 0 0)
                 (0 1 0 0 0 0 0 0)
                 (0 0 1 0 0 0 0 0)
                 (0 0 0 1 0 0 0 0)
                 (0 0 0 0 1 0 0 0)
                 (0 0 0 0 0 1 0 0)
                 (0 0 0 0 0 0 1 0)
                 (0 0 0 0 0 0 0 1)))
           (b0 '(1 1 1 1 1 1 1 1))
           (x1 '(2 0 0 0 0 0 0 0)))
      (env-set (env-set (env-set env "ref:matrix:A0" A0)
                        "ref:vector:b0" b0)
               "ref:state_vector:t1" x1))))

(define example-boundary-reg
  (boundary-reg-add (boundary-reg-empty) "FANO-v1" (make-fano-boundary "FANO-v1")))

(define example-steps
  (list
   '((id . "enc-0") (phase . 0) (boundary . "FANO-v1") (anchor . "commit:abc123")
     (op . "define_encoder")
     (encoder_id . "E.local.1")
     (ring . "Z") (basis_dim . 8) (poly_form . "affine")
     (coeffs . ((A . "ref:matrix:A0") (b . "ref:vector:b0")))
     (inputs . ()) (outputs . ("enc:E.local.1")))
   '((id . "step-1") (phase . 1) (boundary . "FANO-v1") (anchor . "commit:abc123")
     (op . "apply_encoder")
     (encoder_ref . "enc:E.local.1")
     (vars . ((x . "ref:state_vector:t1")))
     (inputs . ("enc:E.local.1" "ref:state_vector:t1")) (outputs . ("state:encoded:t1")))
   '((id . "step-2") (phase . 2) (boundary . "FANO-v1") (anchor . "commit:abc123")
     (op . "decode_and_validate")
     (decoder . ((mode . "boundary_relative") (strategy . "canonical_under_automorphism")))
     (target . "state:encoded:t1")
     (checks . ("schema" "boundary_id_match" "automorphism_match" "fano_incidence" "pcg_pair_cover"))
     (inputs . ("state:encoded:t1")) (outputs . ("state:decoded:t1" "proof:valid:t1")))))

;; Run example:
;; (define final-env (run-trace example-steps example-boundary-reg example-initial-env))
;; (env-get final-env "state:decoded:t1")
;; (env-get final-env "proof:valid:t1")

