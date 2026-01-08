;; CAN-ISA v1.0 VM (MVP, deterministic)
;;
;; IMPORTANT: This VM currently implements a minimal F₂[x] backend using AAL polynomials:
;; - state is a univariate polynomial over F₂ represented as (list of booleans) little-endian.
;; - term handles are also polynomials.
;; - STATE_ADD is polynomial XOR.
;; - STATE_GCD/STATE_LCM use poly-gcd/poly-lcm from src/aal/polynomials.scm.
;;
;; This is an intentional vertical slice for RFC-0001/0004/009:
;; deterministic normalization + meet/join + hashable canonical state.

(use-modules (rnrs bytevectors))

(load (string-append (getcwd) "/src/aal/polynomials.scm"))
(load (string-append (getcwd) "/src/nrr/hash.scm"))

;; -----------------------------
;; Byte reading helpers
;; -----------------------------

(define (u8? x) (and (integer? x) (<= 0 x) (<= x 255)))

(define (bytes? xs)
  (and (list? xs)
       (let loop ((ys xs))
         (if (null? ys) #t
             (and (u8? (car ys)) (loop (cdr ys)))))))

(define (read-u8 bs idx)
  (if (>= idx (length bs))
      (cons #f idx)
      (cons (list-ref bs idx) (+ idx 1))))

(define (read-u16le bs idx)
  (let* ((a (read-u8 bs idx))
         (b (read-u8 bs (cdr a))))
    (if (or (not (car a)) (not (car b)))
        (cons #f idx)
        (cons (+ (car a) (ash (car b) 8)) (cdr b)))))

(define (read-u32le bs idx)
  (let* ((a (read-u8 bs idx))
         (b (read-u8 bs (cdr a)))
         (c (read-u8 bs (cdr b)))
         (d (read-u8 bs (cdr c))))
    (if (or (not (car a)) (not (car b)) (not (car c)) (not (car d)))
        (cons #f idx)
        (cons (+ (car a)
                 (ash (car b) 8)
                 (ash (car c) 16)
                 (ash (car d) 24))
              (cdr d)))))

(define (read-i16le bs idx)
  (let ((r (read-u16le bs idx)))
    (if (not (car r))
        r
        (let ((n (car r)))
          (cons (if (>= n 32768) (- n 65536) n) (cdr r))))))

(define (read-i32le bs idx)
  (let ((r (read-u32le bs idx)))
    (if (not (car r))
        r
        (let ((n (car r)))
          (cons (if (>= n 2147483648) (- n 4294967296) n) (cdr r))))))

(define (take bs idx n)
  (if (> (+ idx n) (length bs))
      (cons #f idx)
      (cons (list-head (list-tail bs idx) n) (+ idx n))))

;; -----------------------------
;; CANBC container parsing
;; -----------------------------

(define (parse-canbc bytes)
  (if (not (bytes? bytes))
      (error "canisa: expected bytes" bytes)
      (let* ((magic (take bytes 0 6))
             (m (car magic)))
        (if (not (and m
                      (= (list-ref m 0) (char->integer #\C))
                      (= (list-ref m 1) (char->integer #\A))
                      (= (list-ref m 2) (char->integer #\N))
                      (= (list-ref m 3) (char->integer #\B))
                      (= (list-ref m 4) (char->integer #\C))
                      (= (list-ref m 5) 0)))
            (error "canisa: invalid CANBC magic")
            (let* ((v (read-u16le bytes 6))
                   (ver (car v))
                   (lenr (read-u32le bytes (cdr v)))
                   (payload-len (car lenr))
                   (payload (take bytes (cdr lenr) payload-len)))
              (if (not (and ver payload-len (car payload)))
                  (error "canisa: truncated CANBC")
                  (if (not (= ver 1))
                      (error "canisa: unsupported CANBC version" ver)
                      (car payload))))))))

;; -----------------------------
;; VM state
;; -----------------------------

(define (make-heap)
  ;; assoc list: (handle . value)
  '())

(define (heap-get heap h)
  (let ((p (assoc h heap)))
    (if p (cdr p) #f)))

(define (heap-put heap h v)
  (cons (cons h v) (let loop ((xs heap) (out '()))
                     (if (null? xs) (reverse out)
                         (if (= (caar xs) h)
                             (loop (cdr xs) out)
                             (loop (cdr xs) (cons (car xs) out)))))))

(define (poly-xor p q) (poly-add p q))

(define (poly-shift poly exp2)
  (cond
   ((= exp2 0) poly)
   ((> exp2 0) (shift-left poly exp2))
   (else (shift-right poly (- exp2)))))

(define (poly-from-coeff coeff)
  ;; coeff is i32; for F2 we only care about parity.
  (if (odd? (abs coeff)) (list #t) '()))

(define (poly-set-degree poly deg)
  ;; Set coefficient at x^deg to #t (idempotent).
  (if (or (not (integer? deg)) (< deg 0))
      (error "canisa: invalid degree" deg)
      (let* ((t (trim poly))
             (need (+ deg 1))
             (padded (append t (make-list (max 0 (- need (length t))) #f))))
        (let loop ((i 0) (xs padded) (out '()))
          (if (null? xs)
              (trim (reverse out))
              (loop (+ i 1) (cdr xs) (cons (if (= i deg) #t (car xs)) out)))))))

(define (poly-clear-degree poly deg)
  (if (or (not (integer? deg)) (< deg 0))
      (error "canisa: invalid degree" deg)
      (let* ((t (trim poly)))
        (let loop ((i 0) (xs t) (out '()))
          (if (null? xs)
              (trim (reverse out))
              (loop (+ i 1) (cdr xs) (cons (if (= i deg) #f (car xs)) out)))))))

(define (poly->canonical-bytes poly)
  ;; Deterministic but simple (not compact):
  ;; u16le length, then length bytes (0 or 1) for each coefficient.
  (let* ((t (trim poly))
         (n (length t))
         (hdr (list (logand n #xff) (logand (ash n -8) #xff))))
    (append hdr (map (lambda (b) (if b 1 0)) t))))

(define (hash-poly-sha256 poly)
  (let* ((bytes (poly->canonical-bytes poly))
         (hex (hash-sha256 bytes)))
    (string-append "sha256:" hex)))

(define fano-lines
  ;; Fixed Fano plane incidence (7 lines of 3 points).
  '((0 1 2)
    (0 3 4)
    (0 5 6)
    (1 3 5)
    (1 4 6)
    (2 3 6)
    (2 4 5)))

(define (poly-coeff poly deg)
  (let* ((t (trim poly)))
    (if (and (integer? deg) (<= 0 deg) (< deg (length t)))
        (list-ref t deg)
        #f)))

(define (poly->fano-pointmask poly)
  ;; Points 0..6 correspond to coefficients c0..c6.
  (let loop ((i 0) (mask 0))
    (if (>= i 7)
        mask
        (loop (+ i 1)
              (if (poly-coeff poly i)
                  (logior mask (ash 1 i))
                  mask)))))

(define (fano-linemask pointmask)
  (let loop ((ls fano-lines) (i 0) (mask 0))
    (if (null? ls)
        mask
        (let* ((tri (car ls))
               (a (car tri))
               (b (cadr tri))
               (c (caddr tri))
               (active (and (not (= 0 (logand pointmask (ash 1 a))))
                            (not (= 0 (logand pointmask (ash 1 b))))
                            (not (= 0 (logand pointmask (ash 1 c)))))))
          (loop (cdr ls) (+ i 1)
                (if active
                    (logior mask (ash 1 i))
                    mask))))))

(define (hash-fano-sha256 pointmask linemask)
  ;; Canonical projection bytes: [pointmask, linemask] (both u8).
  (string-append "sha256:" (hash-sha256 (list (logand pointmask #xff) (logand linemask #xff)))))

;; -----------------------------
;; VM execution (subset)
;; -----------------------------

(define (vm-run-canbc-bytes canbc-bytes)
  (let* ((payload (parse-canbc canbc-bytes))
         (idx 0)
         (events 0)
         (ok? #t)
         (errors '())
	         (mode #f)   ;; arithmetic mode
	         (state0 '()) ;; current state poly
	         (heap (make-heap)) ;; both term and state handles stored as polynomials
	         (outputs (make-heap)) ;; out-handle -> value (string)
	         (fano-hash #f))

    (define (trap msg)
      (set! ok? #f)
      (set! errors (cons msg errors)))

    (define (need pred msg)
      (if pred #t (begin (trap msg) #f)))

    (define (step-opcode op)
      (set! events (+ events 1))
      (cond
       ((= op #x00) ;; NOP
        #t)
       ((= op #x01) ;; HALT
        'halt)
       ((= op #x02) ;; TRAP u16
        (let* ((r (read-u16le payload idx))
               (code (car r)))
          (set! idx (cdr r))
          (trap (string-append "TRAP:" (number->string (if code code 0))))
          'halt))

       ((= op #x10) ;; DEF_MOD u8 mode, u32 p
        (let* ((rm (read-u8 payload idx))
               (m (car rm))
               (rp (read-u32le payload (cdr rm)))
               (p (car rp)))
          (set! idx (cdr rp))
          (if (need (and m p) "DEF_MOD: truncated")
              (begin
                (set! mode m)
                (if (not (= mode 0))
                    (trap "DEF_MOD: only mode 0 (F2) supported in MVP")
                    #t))
              #f)))

       ((= op #x20) ;; TERM_NEW u16 dst, i32 coeff, i16 exp2
        (let* ((rd (read-u16le payload idx))
               (dst (car rd))
               (rc (read-i32le payload (cdr rd)))
               (coeff (car rc))
               (re (read-i16le payload (cdr rc)))
               (exp2 (car re)))
          (set! idx (cdr re))
          (if (need (and dst coeff exp2) "TERM_NEW: truncated")
              (let ((base (poly-from-coeff coeff)))
                (set! heap (heap-put heap dst (poly-shift base exp2)))
                #t)
              #f)))

       ((= op #x21) ;; TERM_SET_VAR u16 term, u16 feat_id
        (let* ((rt (read-u16le payload idx))
               (term (car rt))
               (rf (read-u16le payload (cdr rt)))
               (fid (car rf)))
          (set! idx (cdr rf))
          (if (need (and term fid) "TERM_SET_VAR: truncated")
              (let ((t (heap-get heap term)))
                (if (need t "TERM_SET_VAR: unknown term handle")
                    (begin
                      (set! heap (heap-put heap term (poly-set-degree t fid)))
                      #t)
                    #f))
              #f)))

       ((= op #x22) ;; TERM_CLR_VAR u16 term, u16 feat_id
        (let* ((rt (read-u16le payload idx))
               (term (car rt))
               (rf (read-u16le payload (cdr rt)))
               (fid (car rf)))
          (set! idx (cdr rf))
          (if (need (and term fid) "TERM_CLR_VAR: truncated")
              (let ((t (heap-get heap term)))
                (if (need t "TERM_CLR_VAR: unknown term handle")
                    (begin
                      (set! heap (heap-put heap term (poly-clear-degree t fid)))
                      #t)
                    #f))
              #f)))

       ((= op #x25) ;; TERM_ZERO u16 term
        (let* ((rt (read-u16le payload idx))
               (term (car rt)))
          (set! idx (cdr rt))
          (if (need term "TERM_ZERO: truncated")
              (begin
                (set! heap (heap-put heap term '()))
                #t)
              #f)))

       ((= op #x30) ;; STATE_ADD u16 term
        (let* ((rt (read-u16le payload idx))
               (term (car rt)))
          (set! idx (cdr rt))
          (if (need term "STATE_ADD: truncated")
              (let ((t (heap-get heap term)))
                (if (need t "STATE_ADD: unknown term handle")
                    (begin
                      (set! state0 (poly-xor state0 t))
                      #t)
                    #f))
              #f)))

       ((= op #x33) ;; STATE_CLEAR
        (set! state0 '())
        #t)

       ((= op #x34) ;; STATE_COPY u16 dst, u16 src
        (let* ((rd (read-u16le payload idx))
               (dst (car rd))
               (rs (read-u16le payload (cdr rd)))
               (src (car rs)))
          (set! idx (cdr rs))
          (if (need (and dst src) "STATE_COPY: truncated")
              (cond
               ((= src 0)
                (set! heap (heap-put heap dst state0))
                #t)
               ((= dst 0)
                (let ((s (heap-get heap src)))
                  (if (need s "STATE_COPY: unknown state handle")
                      (begin (set! state0 s) #t)
                      #f)))
               (else
                (let ((s (heap-get heap src)))
                  (if (need s "STATE_COPY: unknown state handle")
                      (begin (set! heap (heap-put heap dst s)) #t)
                      #f))))
              #f)))

       ((= op #x40) ;; STATE_NORM u8 mode
        (let* ((rm (read-u8 payload idx))
               (m (car rm)))
          (set! idx (cdr rm))
          (if (need m "STATE_NORM: truncated")
              (begin
                (set! state0 (trim state0))
                #t)
              #f)))

       ((= op #x52) ;; STATE_GCD u16 src
        (let* ((rs (read-u16le payload idx))
               (src (car rs)))
          (set! idx (cdr rs))
          (if (need src "STATE_GCD: truncated")
              (let ((s (heap-get heap src)))
                (if (need s "STATE_GCD: unknown state handle")
                    (begin
                      (set! state0 (poly-gcd state0 s))
                      #t)
                    #f))
              #f)))

       ((= op #x53) ;; STATE_LCM u16 src
        (let* ((rs (read-u16le payload idx))
               (src (car rs)))
          (set! idx (cdr rs))
          (if (need src "STATE_LCM: truncated")
              (let ((s (heap-get heap src)))
                (if (need s "STATE_LCM: unknown state handle")
                    (begin
                      (set! state0 (poly-lcm state0 s))
                      #t)
                    #f))
              #f)))

       ((= op #x61) ;; STATE_HASH u8 algo, u16 out
        (let* ((ra (read-u8 payload idx))
               (algo (car ra))
               (ro (read-u16le payload (cdr ra)))
               (out-h (car ro)))
          (set! idx (cdr ro))
          (if (need (and algo out-h) "STATE_HASH: truncated")
              (if (not (= algo 1))
                  (trap "STATE_HASH: only algo=1 (SHA-256) supported in MVP")
                  (set! outputs (heap-put outputs out-h (hash-poly-sha256 state0))))
              #f)))

       ((= op #x93) ;; PROJ_FANO u16 out
        (let* ((ro (read-u16le payload idx))
               (out-h (car ro)))
          (set! idx (cdr ro))
          (if (need out-h "PROJ_FANO: truncated")
              (let* ((pm (poly->fano-pointmask state0))
                     (lm (fano-linemask pm))
                     (h (hash-fano-sha256 pm lm)))
                (set! fano-hash h)
                (set! outputs (heap-put outputs out-h h))
                #t)
              #f)))

       (else
        (trap (string-append "unknown opcode: " (number->string op)))
        'halt)))

    ;; main loop
    (let loop ()
      (if (or (not ok?) (>= idx (length payload)))
          #t
          (let* ((r (read-u8 payload idx))
                 (op (car r)))
            (if (not op)
                (trap "truncated bytecode")
                (begin
                  (set! idx (cdr r))
                  (let ((res (step-opcode op)))
                    (if (eq? res 'halt)
                        #t
                        (loop))))))))

    ;; pick the smallest out-handle hash if any, else hash current state for reporting
    (let* ((outs outputs)
           (out-keys (map car outs))
           (chosen (if (null? out-keys) #f (apply min out-keys)))
           (hash (if chosen (heap-get outputs chosen) (hash-poly-sha256 state0))))
      `((ok? . ,ok?)
        (events . ,events)
        (state_hash . ,hash)
        (fano_hash . ,fano-hash)
        (errors . ,(reverse errors))))))
