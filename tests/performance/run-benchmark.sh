#!/bin/bash
# BICF Production System Performance Benchmarks

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "BICF Production System Benchmarks"
echo "=========================================="
echo ""
echo "System Information:"
echo "  OS: $(uname -s) $(uname -r)"
echo "  CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs || echo 'Unknown')"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  Guile: $(guile --version 2>&1 | head -1)"
echo ""

# Create benchmark script in project root
cat > "$PROJECT_ROOT/tests/performance/benchmark-run.scm" << 'BENCHMARK_EOF'
;; BICF Production System Performance Benchmarks
(use-modules (ice-9 time))

;; Load modules (use absolute paths from PROJECT_ROOT)
(display "Loading modules...\n")
(load (string-append (getcwd) "/src/aal/polynomials.scm"))
(load (string-append (getcwd) "/src/aal/ast.scm"))
(load (string-append (getcwd) "/src/core/bicf-core.scm"))
(display "Modules loaded.\n\n")

;; Timing helper with proper output
(define (time-op name iterations op)
  (let ((start (get-internal-real-time)))
    (let ((result (op))
          (end (get-internal-real-time)))
      (let ((elapsed-ms (* 1000.0 (/ (- end start) internal-time-units-per-second))))
        (display (string-append "  " name ": "))
        (display (number->string elapsed-ms))
        (display "ms (")
        (display (number->string iterations))
        (display " iterations, ")
        (display (number->string (/ elapsed-ms iterations)))
        (display "ms/op)\n")
        result))))

;; Benchmark 1: Polynomial Operations
(display "=== 1. Polynomial Operations ===\n")
(let ((p '(#t #f #t #f #t #f #t #t))
      (q '(#f #t #f #t #f #t #f #t)))
  (time-op "poly-add" 10000 (lambda () (let loop ((i 0)) (if (< i 10000) (begin (poly-add p q) (loop (+ i 1))) #t))))
  (time-op "poly-mul" 1000 (lambda () (let loop ((i 0)) (if (< i 1000) (begin (poly-mul p q) (loop (+ i 1))) #t))))
  (time-op "poly-gcd" 100 (lambda () (let loop ((i 0)) (if (< i 100) (begin (poly-gcd p q) (loop (+ i 1))) #t))))
  (time-op "poly-lcm" 100 (lambda () (let loop ((i 0)) (if (< i 100) (begin (poly-lcm p q) (loop (+ i 1))) #t))))
  (time-op "poly-divmod" 100 (lambda () (let loop ((i 0)) (if (< i 100) (begin (poly-divmod p q) (loop (+ i 1))) #t)))))

;; Benchmark 2: BICF Core Operations
(display "\n=== 2. BICF Core Operations ===\n")
(let ((boundary '((id . "test-boundary")))
      (choice '((choice-id . "default"))))
  (time-op "realize" 10000 (lambda () (let loop ((i 0)) (if (< i 10000) (begin (realize choice boundary) (loop (+ i 1))) #t))))
  (time-op "valid?" 10000 (lambda () (let loop ((i 0)) (if (< i 10000) (begin (valid? (realize choice boundary) boundary) (loop (+ i 1))) #t))))
  (time-op "boundary?" 10000 (lambda () (let loop ((i 0)) (if (< i 10000) (begin (boundary? boundary) (loop (+ i 1))) #t))))
  (time-op "interior?" 10000 (lambda () (let loop ((i 0)) (if (< i 10000) (begin (interior? (realize choice boundary)) (loop (+ i 1))) #t)))))

;; Benchmark 3: Memory Allocation
(display "\n=== 3. Memory Allocation ===\n")
(time-op "Create 1000 boundaries" 1 (lambda () (let loop ((i 0) (acc '())) (if (< i 1000) (loop (+ i 1) (cons (list (cons 'id (number->string i))) acc)) (length acc)))))

;; Benchmark 4: Polynomial Complexity
(display "\n=== 4. Polynomial Complexity Tests ===\n")
(let ((small-p '(#t #f))
      (small-q '(#f #t))
      (medium-p '(#t #f #t #f #t #f #t #f #t #f))
      (medium-q '(#f #t #f #t #f #t #f #t #f #t))
      (large-p (let loop ((i 0) (acc '())) (if (< i 50) (loop (+ i 1) (cons (even? i) acc)) acc)))
      (large-q (let loop ((i 0) (acc '())) (if (< i 50) (loop (+ i 1) (cons (odd? i) acc)) acc))))
  (time-op "poly-add (small, 1000x)" 1000 (lambda () (let loop ((i 0)) (if (< i 1000) (begin (poly-add small-p small-q) (loop (+ i 1))) #t))))
  (time-op "poly-add (medium, 1000x)" 1000 (lambda () (let loop ((i 0)) (if (< i 1000) (begin (poly-add medium-p medium-q) (loop (+ i 1))) #t))))
  (time-op "poly-add (large, 100x)" 100 (lambda () (let loop ((i 0)) (if (< i 100) (begin (poly-add large-p large-q) (loop (+ i 1))) #t))))
  (time-op "poly-mul (small, 100x)" 100 (lambda () (let loop ((i 0)) (if (< i 100) (begin (poly-mul small-p small-q) (loop (+ i 1))) #t))))
  (time-op "poly-mul (medium, 100x)" 100 (lambda () (let loop ((i 0)) (if (< i 100) (begin (poly-mul medium-p medium-q) (loop (+ i 1))) #t))))
  (time-op "poly-mul (large, 10x)" 10 (lambda () (let loop ((i 0)) (if (< i 10) (begin (poly-mul large-p large-q) (loop (+ i 1))) #t)))))

(display "\n=== Benchmark Suite Complete ===\n")
BENCHMARK_EOF

# Run benchmarks
echo "Running benchmarks..."
echo ""
cd "$PROJECT_ROOT"
guile -s tests/performance/benchmark-run.scm 2>&1

echo ""
echo "=========================================="
echo "Benchmarks completed successfully"
echo "=========================================="

