;; ============================================================
;; RFC-VIZ-001 - deterministic scene model generator (MVP)
;; Produces a pure data scene graph (alist) for downstream renderers.
;; ============================================================

(define (viz-shape-for-k k has-global-decision?)
  ;; RFC-VIZ-001 core states: ball / polytope / sphere.
  (if has-global-decision?
      'sphere
      (cond
       ((<= k 0) 'empty)
       ((= k 1) 'point)
       ((= k 2) 'line)
       ((= k 3) 'triangle)
       ((= k 4) 'tetrahedron)
       (else 'polytope))))

(define (viz-make-scene k has-global-decision? include-fano? fano-points fano-lines)
  ;; Returns a deterministic scene graph matching RFC-VIZ-001 logical contract.
  ;; The scene is pure data: downstream can render with Three.js/R3F, etc.
  (let* ((shape (viz-shape-for-k k has-global-decision?))
         (envelope (if (eq? shape 'sphere) 'sphere 'none))
         (structure (cond
                     ((eq? shape 'sphere) 'polytope) ;; sphere implies closure, structure is explanatory
                     (else shape)))
         (incidence (if include-fano?
                        `((type . fano)
                          (points . ,fano-points)
                          (lines . ,fano-lines))
                        'none)))
    `((ContextRoot
       (ClosureEnvelope . ,envelope)
       (StructureProxy . ,structure)
       (IncidenceOverlay . ,incidence)
       (TraceLayer . none)))))


