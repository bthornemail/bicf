;; ============================================================
;; NRR Log Entry Structure (R5RS Scheme)
;; Binary-compatible log entry format
;; ============================================================

(load "hash.scm")

;; -----------------------------
;; Log Entry Types
;; -----------------------------

(define *log-entry-types* '(boundary interior guarantee))

(define (log-entry-type? x)
  (memq x *log-entry-types*))

;; Type codes (for binary format)
(define *type-codes*
  '((boundary . 0)
    (interior . 1)
    (guarantee . 2)))

(define (type-to-code type)
  (let ((entry (assq type *type-codes*)))
    (if entry
        (cdr entry)
        (error "type-to-code: unknown type" type))))

(define (code-to-type code)
  (let loop ((codes *type-codes*))
    (if (null? codes)
        (error "code-to-type: unknown code" code)
        (if (= (cdar codes) code)
            (caar codes)
            (loop (cdr codes))))))

;; -----------------------------
;; Log Entry Structure
;; -----------------------------

;; Log entry: (phase, type, ref)
;; Binary format: [phase:uint32][type:uint8][ref:hash_string]
(define (make-log-entry phase type ref)
  (if (not (integer? phase))
      (error "make-log-entry: expected integer" phase)
      (if (not (log-entry-type? type))
          (error "make-log-entry: expected log entry type" type)
          (if (not (string? ref))
              (error "make-log-entry: expected string" ref)
              (list 'LogEntry phase type ref)))))

(define (log-entry? x)
  (and (list? x)
       (= (length x) 4)
       (eq? (car x) 'LogEntry)
       (integer? (cadr x))
       (log-entry-type? (caddr x))
       (string? (cadddr x))))

(define (log-entry-phase entry)
  (if (log-entry? entry)
      (cadr entry)
      (error "log-entry-phase: expected LogEntry" entry)))

(define (log-entry-type entry)
  (if (log-entry? entry)
      (caddr entry)
      (error "log-entry-type: expected LogEntry" entry)))

(define (log-entry-ref entry)
  (if (log-entry? entry)
      (cadddr entry)
      (error "log-entry-ref: expected LogEntry" entry)))

;; -----------------------------
;; Binary Serialization
;; -----------------------------

;; serialize-log-entry: Convert log entry to binary format
;; Format: phase (4 bytes) + type (1 byte) + ref (variable, null-terminated)
(define (serialize-log-entry entry)
  (if (not (log-entry? entry))
      (error "serialize-log-entry: expected LogEntry" entry)
      (let ((phase (log-entry-phase entry))
            (type-code (type-to-code (log-entry-type entry)))
            (ref (log-entry-ref entry)))
        ;; For R5RS, we'll use a text-based format
        ;; In production, would use proper binary serialization
        (string-append (number->string phase) ":"
                       (number->string type-code) ":"
                       ref "\n"))))

;; deserialize-log-entry: Parse log entry from binary format
(define (deserialize-log-entry data)
  (if (not (string? data))
      (error "deserialize-log-entry: expected string" data)
      (let ((parts (string-split data ":")))
        (if (< (length parts) 3)
            (error "deserialize-log-entry: invalid format" data)
            (let ((phase (string->number (car parts)))
                  (type-code (string->number (cadr parts)))
                  (ref (string-join (cddr parts) ":")))
              (if (and (integer? phase) (integer? type-code))
                  (make-log-entry phase (code-to-type type-code) ref)
                  (error "deserialize-log-entry: invalid phase/type" data)))))))

;; Helper: string-split
(define (string-split str delim)
  (if (not (string? str))
      (error "string-split: expected string" str)
      (if (not (string? delim))
          (error "string-split: expected string delimiter" delim)
          (let ((delim-len (string-length delim)))
            (let loop ((str str)
                       (result '())
                       (current '()))
              (if (= (string-length str) 0)
                  (reverse (cons (list->string (reverse current)) result))
                  (if (and (>= (string-length str) delim-len)
                           (string=? (substring str 0 delim-len) delim))
                      (loop (substring str delim-len)
                            (cons (list->string (reverse current)) result)
                            '())
                      (loop (substring str 1)
                            result
                            (cons (string-ref str 0) current)))))))))

;; Helper: string-join (already defined elsewhere, but include for completeness)
(define (string-join strings sep)
  (if (null? strings)
      ""
      (if (null? (cdr strings))
          (car strings)
          (string-append (car strings)
                         sep
                         (string-join (cdr strings) sep)))))

;; ============================================================
;; End of Log Entry Structure
;; ============================================================

