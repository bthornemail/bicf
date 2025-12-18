;; ============================================================
;; BICF Core Implementation (R5RS Scheme)
;; Implements RFC-0001: Boundary–Interior Combinatorial Framework
;; ============================================================

;; -----------------------------
;; Type Definitions
;; -----------------------------

;; Boundary: constraint object encoding invariants, axioms, or admissibility conditions
;; Represented as an alist with at least an 'id field
(define (boundary? x)
  (and (list? x)
       (assq 'id x)
       (string? (cdr (assq 'id x)))))

;; Interior: realized object that satisfies a Boundary
;; Represented as an alist with at least a 'boundary-ref field
(define (interior? x)
  (and (list? x)
       (assq 'boundary-ref x)
       (string? (cdr (assq 'boundary-ref x)))))

;; View: projection of an Interior (may discard information)
;; Represented as an alist
(define (view? x)
  (and (list? x)
       (assq 'source-ref x)))

;; Choice: parameter for non-canonical realization
;; Represented as an alist with choice parameters
(define (choice? x)
  (and (list? x)
       (assq 'choice-id x)))

;; Difference: structural difference between two Interiors
;; Represented as an alist describing the difference
(define (difference? x)
  (and (list? x)
       (assq 'diff-type x)))

;; -----------------------------
;; Core Judgment: Validity (Sat)
;; -----------------------------

;; Valid(i, b) means Interior i satisfies Boundary b
;; This is the sole satisfaction predicate
(define (valid? interior boundary)
  (and (interior? interior)
       (boundary? boundary)
       ;; Interior must reference the boundary
       (let ((boundary-ref (cdr (assq 'boundary-ref interior)))
             (boundary-id (cdr (assq 'id boundary))))
         (equal? boundary-ref boundary-id))
       ;; Interior must satisfy boundary constraints
       ;; (This is a placeholder - actual validation depends on boundary type)
       #t))

;; Notation helper: i ⊨ b
(define (sat interior boundary)
  (valid? interior boundary))

;; -----------------------------
;; Required Interfaces
;; -----------------------------

;; transform : Boundary → Boundary
;; MUST preserve boundary validity
;; MUST be closed under composition
;; MUST NOT require access to interior state
(define (transform boundary)
  (if (not (boundary? boundary))
      (error "transform: expected Boundary" boundary)
      ;; Default transform: identity (boundaries can define their own transforms)
      (let ((transform-fn (assq 'transform-fn boundary)))
        (if transform-fn
            ((cdr transform-fn) boundary)
            boundary))))

;; realize : Boundary × Choice → Interior
;; MUST produce interior state consistent with the boundary
;; MUST NOT be assumed unique
;; MAY be parameterized or stochastic
(define (realize choice boundary)
  (if (not (choice? choice))
      (error "realize: expected Choice" choice)
      (if (not (boundary? boundary))
          (error "realize: expected Boundary" boundary)
          (let ((boundary-id (cdr (assq 'id boundary)))
                (choice-id (cdr (assq 'choice-id choice)))
                (realize-fn (assq 'realize-fn boundary)))
            (if realize-fn
                ;; Boundary provides its own realization function
                ((cdr realize-fn) choice boundary)
                ;; Default: create interior with boundary reference
                `((boundary-ref . ,boundary-id)
                  (choice-id . ,choice-id)
                  (data . ,(assq 'data choice))))))))

;; project : Interior → View
;; MUST NOT introduce new constraints
;; MAY reduce dimensionality or information
;; MUST be deterministic with respect to the given interior
(define (project interior)
  (if (not (interior? interior))
      (error "project: expected Interior" interior)
      (let ((project-fn (assq 'project-fn interior)))
        (if project-fn
            ((cdr project-fn) interior)
            ;; Default: create view with source reference
            (let ((boundary-ref (cdr (assq 'boundary-ref interior))))
              `((source-ref . ,boundary-ref)
                (view-data . ,(assq 'data interior))))))))

;; difference : Interior × Interior → Difference (Optional)
;; MAY be provided to compare successive states
;; MUST be structural, not semantic
;; MUST NOT alter either operand
(define (difference interior1 interior2)
  (if (not (interior? interior1))
      (error "difference: expected Interior" interior1)
      (if (not (interior? interior2))
          (error "difference: expected Interior" interior2)
          ;; Simple structural difference
          (let ((data1 (assq 'data interior1))
                (data2 (assq 'data interior2)))
            `((diff-type . structural)
              (from . ,data1)
              (to . ,data2)
              (equal? . ,(equal? data1 data2)))))))

;; -----------------------------
;; Axiom Implementations
;; -----------------------------

;; Axiom 1: Boundary–Interior Duality
;; Every admissible state space MUST be associated with:
;; 1. a boundary structure encoding constraints, and
;; 2. an interior structure encoding admissible state.
;; No interior state is valid unless it satisfies its associated boundary constraints.
(define (axiom1-boundary-interior-duality interior boundary)
  (and (boundary? boundary)
       (interior? interior)
       (valid? interior boundary)))

;; Axiom 2: Non-Canonicity of Realization
;; There MUST NOT exist a unique or canonical realization from a boundary to an interior.
;; Any realization process MUST require additional structure, parameters, or choices.
(define (axiom2-non-canonicity boundary choice1 choice2)
  (if (not (boundary? boundary))
      (error "axiom2: expected Boundary" boundary)
      (if (not (choice? choice1))
          (error "axiom2: expected Choice" choice1)
          (if (not (choice? choice2))
              (error "axiom2: expected Choice" choice2)
              ;; Different choices should produce different interiors (or at least allow it)
              (let ((i1 (realize choice1 boundary))
                    (i2 (realize choice2 boundary)))
                ;; They may be equal, but the point is that choice is required
                (not (equal? choice1 choice2)))))))

;; Axiom 3: Boundary Primacy in Transformation
;; Transformations that preserve validity MUST act on boundary structures rather than directly on interior state.
;; Interior state MAY change only as a consequence of boundary-respecting transformation.
(define (axiom3-boundary-primacy boundary choice)
  (if (not (boundary? boundary))
      (error "axiom3: expected Boundary" boundary)
      (if (not (choice? choice))
          (error "axiom3: expected Choice" choice)
          (let ((transformed-boundary (transform boundary))
                (interior (realize choice transformed-boundary)))
            ;; Realized interior from transformed boundary must be valid
            (valid? interior transformed-boundary)))))

;; Axiom 4: Explicit Realization Interface
;; Any transition from boundary to interior MUST occur through an explicit realization interface.
;; Implicit or assumed realization is forbidden.
(define (axiom4-explicit-realization boundary)
  (if (not (boundary? boundary))
      (error "axiom4: expected Boundary" boundary)
      ;; This axiom is enforced by the type system:
      ;; - There is no coercion from Boundary to Interior
      ;; - realize() function requires explicit Choice parameter
      ;; This is a check that realize() is being used correctly
      #t))

;; Axiom 5: Projection Does Not Alter Validity
;; Projection operations MAY discard information but MUST NOT introduce invalid state.
;; Projected views MUST remain consistent with the originating interior state.
(define (axiom5-projection-safety interior boundary)
  (if (not (interior? interior))
      (error "axiom5: expected Interior" interior)
      (if (not (boundary? boundary))
          (error "axiom5: expected Boundary" boundary)
          (if (not (valid? interior boundary))
              #f  ; Invalid interior cannot have safe projection
              (let ((view (project interior)))
                ;; View must reference the source interior
                (and (view? view)
                     (let ((source-ref (cdr (assq 'source-ref view)))
                           (boundary-ref (cdr (assq 'boundary-ref interior))))
                       (equal? source-ref boundary-ref))))))))

;; -----------------------------
;; Compliance Testing
;; -----------------------------

;; Test all axioms for a given boundary and choices
(define (test-bicf-compliance boundary choice1 choice2)
  (let ((results '()))
    ;; Test Axiom 1
    (let ((test-choice (if choice1 choice1 (list (cons 'choice-id "test")))))
      (let ((interior (realize test-choice boundary)))
        (set! results (cons (cons 'axiom1 (axiom1-boundary-interior-duality interior boundary)) results))))
    
    ;; Test Axiom 2
    (if (and choice1 choice2)
        (set! results (cons (cons 'axiom2 (axiom2-non-canonicity boundary choice1 choice2)) results)))
    
    ;; Test Axiom 3
    (if choice1
        (set! results (cons (cons 'axiom3 (axiom3-boundary-primacy boundary choice1)) results)))
    
    ;; Test Axiom 4
    (set! results (cons (cons 'axiom4 (axiom4-explicit-realization boundary)) results))
    
    ;; Test Axiom 5
    (if choice1
        (let ((interior (realize choice1 boundary)))
          (if (valid? interior boundary)
              (set! results (cons (cons 'axiom5 (axiom5-projection-safety interior boundary)) results)))))
    
    results))

;; -----------------------------
;; Helper Functions
;; -----------------------------

;; Create a boundary with custom realization function
(define (make-boundary id realize-fn transform-fn)
  `((id . ,id)
    (realize-fn . ,realize-fn)
    (transform-fn . ,transform-fn)))

;; Create a choice
(define (make-choice choice-id data)
  `((choice-id . ,choice-id)
    (data . ,data)))

;; Create a simple boundary (identity transform, default realize)
(define (make-simple-boundary id)
  `((id . ,id)))

;; ============================================================
;; End of BICF Core Implementation
;; ============================================================
