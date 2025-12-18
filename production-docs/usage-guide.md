# BICF Production System - Usage Guide

**Version:** 1.0.0  
**Last Updated:** 2024-12-19

This guide provides step-by-step instructions for using the BICF Production System, including installation, basic usage, advanced patterns, and integration examples.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Installation](#installation)
3. [Basic Usage](#basic-usage)
4. [Advanced Usage](#advanced-usage)
5. [CLI Usage](#cli-usage)
6. [Docker Usage](#docker-usage)
7. [Integration Examples](#integration-examples)

---

## Getting Started

### Prerequisites

- **Scheme Interpreter:** Guile 3.0+ (recommended) or any R5RS-compliant Scheme
- **Python 3:** For JSON schema validation (optional)
- **Node.js:** For package management (optional)
- **Docker:** For containerized deployment (optional)

### Quick Start

```bash
# Clone repository
git clone https://github.com/bthornemail/bicf.git
cd bicf-production

# Run build script
./scripts/build.sh

# Run tests
./scripts/test.sh

# Initialize system
guile -s src/index.scm init
```

---

## Installation

### Local Installation

#### Step 1: Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install guile-3.0 python3 nodejs npm
```

**macOS:**
```bash
brew install guile python3 node
```

#### Step 2: Clone Repository

```bash
git clone https://github.com/bthornemail/bicf.git
cd bicf-production
```

#### Step 3: Verify Installation

```bash
# Check Guile version
guile --version

# Validate schemas
python3 -m json.tool schemas/canvasl-schema.json

# Run build script
./scripts/build.sh
```

### Docker Installation

#### Step 1: Build Docker Image

```bash
docker build -t bicf/production:latest .
```

#### Step 2: Verify Installation

```bash
docker run bicf/production:latest help
```

#### Step 3: Run Container

```bash
# Development mode
docker-compose up

# Production mode
docker-compose -f docker-compose.prod.yml up
```

---

## Basic Usage

### Loading the System

#### Method 1: Via Integration Layer

```scheme
(load "src/integration/bicf-system.scm")
(init-bicf-system)
```

#### Method 2: Direct Module Loading

```scheme
(load "src/core/bicf-core.scm")
(load "src/fano/fano-checker.scm")
(load "src/consensus/pcg-validator.scm")
```

### Creating Boundaries

#### Simple Boundary

```scheme
(load "src/core/bicf-core.scm")

(define boundary (make-simple-boundary "my-boundary"))
```

#### Custom Boundary

```scheme
(define realize-fn
  (lambda (choice boundary)
    `((boundary-ref . ,(cdr (assq 'id boundary)))
      (choice-id . ,(cdr (assq 'choice-id choice)))
      (data . "custom-data"))))

(define transform-fn
  (lambda (boundary)
    boundary))  ; Identity transform

(define boundary (make-boundary "custom-boundary" realize-fn transform-fn))
```

### Creating Choices

```scheme
(define choice (make-choice "choice-1" '((data . "some-data"))))
```

### Realizing Interiors

```scheme
(define boundary (make-simple-boundary "test-boundary"))
(define choice (make-choice "choice-1" '((data . "data1"))))
(define interior (realize choice boundary))
```

### Validating Interiors

```scheme
(define valid (valid? interior boundary))
(if valid
    (display "Interior is valid\n")
    (display "Interior is invalid\n"))
```

### Transforming Boundaries

```scheme
(define transformed (transform boundary))
```

### Projecting Views

```scheme
(define view (project interior))
```

---

## Advanced Usage

### FANO Boundary Validation

```scheme
(load "src/fano/fano-checker.scm")

;; Standard Fano plane
(define decoded '((points . (0 1 2 3 4 5 6))
                  (lines . ((0 1 3) (0 2 6) (0 4 5) 
                           (1 2 4) (1 5 6) (2 3 5) (3 4 6)))))
(define boundary '((id . "FANO-v1")))

(check-fano-incidence decoded boundary)  ; => #t
```

### PCG Validation

```scheme
(load "src/consensus/pcg-validator.scm")

;; Standard 14-point universe with 14 lines
(define decoded '((universe . (0 1 2 3 4 5 6 7 8 9 10 11 12 13))))
(define boundary '((id . "FANO-v1")))

(check-pcg-pair-cover decoded boundary)  ; => #t
```

### CanvasL Execution

#### Step 1: Prepare Input

Create a JSONL file or S-expression list:

```scheme
(define steps
  (list
   '((id . "enc-0") (phase . 0) (boundary . "FANO-v1") 
     (anchor . "commit:abc123") (op . "define_encoder")
     (encoder_id . "E.local.1") (ring . "Z") (basis_dim . 8)
     (poly_form . "affine")
     (coeffs . ((A . "ref:matrix:A0") (b . "ref:vector:b0")))
     (inputs . ()) (outputs . ("enc:E.local.1")))
   '((id . "step-1") (phase . 1) (boundary . "FANO-v1")
     (anchor . "commit:abc123") (op . "apply_encoder")
     (encoder_ref . "enc:E.local.1")
     (vars . ((x . "ref:state_vector:t1")))
     (inputs . ("enc:E.local.1" "ref:state_vector:t1"))
     (outputs . ("state:encoded:t1")))))
```

#### Step 2: Set Up Environment

```scheme
(load "src/canvasl/interpreter.scm")

(define initial-env
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

(define boundary-reg
  (boundary-reg-add (boundary-reg-empty) "FANO-v1"
                    '((id . "FANO-v1")
                      (automorphism . "pgl3-2:std")
                      (fano . placeholder)
                      (pcg . placeholder))))
```

#### Step 3: Execute Trace

```scheme
(define final-env (run-trace steps boundary-reg initial-env))
(env-get final-env "state:encoded:t1")
```

### Axiom Compliance Testing

```scheme
(load "src/core/bicf-core.scm")

(define boundary (make-simple-boundary "test"))
(define choice1 (make-choice "c1" '((data . "d1"))))
(define choice2 (make-choice "c2" '((data . "d2"))))

(define results (test-bicf-compliance boundary choice1 choice2))
;; => ((axiom5 . #t) (axiom4 . #t) (axiom3 . #t) (axiom2 . #t) (axiom1 . #t))
```

---

## CLI Usage

### Command-Line Interface

#### Help

```bash
guile -s src/index.scm help
```

Output:
```
BICF System CLI
Usage: bicf <command> [args...]
Commands: help, init, register, get, realize, transform, project, valid
```

#### Initialize System

```bash
guile -s src/index.scm init
```

#### Register Boundary

```scheme
;; In Scheme REPL
(load "src/integration/bicf-system.scm")
(define boundary '((id . "my-boundary")))
(register-boundary boundary)
```

#### Get Boundary

```scheme
(get-boundary "my-boundary")
```

### Docker CLI

#### Help

```bash
docker run bicf/production:latest help
```

#### Run Interpreter

```bash
docker run -v $(pwd)/examples:/app/examples \
  bicf/production:latest interpreter /app/examples/trace.jsonl
```

#### Run Tests

```bash
docker run bicf/production:latest test
```

---

## Docker Usage

### Development Mode

#### Start Services

```bash
docker-compose up
```

#### Run Commands

```bash
# In another terminal
docker exec -it bicf-core guile -s /app/src/index.scm help
```

### Production Mode

#### Start Production Container

```bash
docker-compose -f docker-compose.prod.yml up -d
```

#### View Logs

```bash
docker-compose -f docker-compose.prod.yml logs -f
```

#### Stop Container

```bash
docker-compose -f docker-compose.prod.yml down
```

### Custom Docker Image

#### Build with Custom Configuration

```dockerfile
FROM bicf/production:latest

# Add custom modules
COPY custom-modules/ /app/src/custom/

# Set environment variables
ENV BICF_ENV=production
ENV BICF_LOG_LEVEL=info
```

#### Build and Run

```bash
docker build -t my-bicf:latest .
docker run my-bicf:latest help
```

---

## Integration Examples

### Example 1: Basic BICF Workflow

```scheme
;; Load system
(load "src/integration/bicf-system.scm")
(init-bicf-system)

;; Create boundary and choice
(define boundary (make-simple-boundary "example-boundary"))
(define choice (make-choice "example-choice" '((data . "example-data"))))

;; Realize interior
(define interior (realize choice boundary))

;; Validate
(if (valid? interior boundary)
    (display "Interior is valid\n")
    (display "Interior is invalid\n"))

;; Transform boundary
(define transformed (transform boundary))

;; Project view
(define view (project interior))
```

### Example 2: FANO Validation

```scheme
;; Load FANO checker
(load "src/fano/fano-checker.scm")

;; Create FANO structure
(define fano-structure
  '((points . (0 1 2 3 4 5 6))
    (lines . ((0 1 3) (0 2 6) (0 4 5)
             (1 2 4) (1 5 6) (2 3 5) (3 4 6)))))

;; Validate
(define boundary '((id . "FANO-v1")))
(check-fano-incidence fano-structure boundary)
```

### Example 3: PCG Validation

```scheme
;; Load PCG validator
(load "src/consensus/pcg-validator.scm")

;; Create PCG structure (standard 14-point universe)
(define pcg-structure
  '((universe . (0 1 2 3 4 5 6 7 8 9 10 11 12 13))))

;; Validate
(define boundary '((id . "FANO-v1")))
(check-pcg-pair-cover pcg-structure boundary)
```

### Example 4: CanvasL Trace Execution

```scheme
;; Load interpreter
(load "src/canvasl/interpreter.scm")

;; Define steps
(define steps
  (list
   '((id . "step-1") (phase . 1) (boundary . "FANO-v1")
     (anchor . "commit:abc") (op . "define_encoder")
     (encoder_id . "E1") (ring . "Z") (basis_dim . 8)
     (poly_form . "affine")
     (coeffs . ((A . "ref:A") (b . "ref:b")))
     (inputs . ()) (outputs . ("enc:E1")))))

;; Set up environment
(define env (env-empty))
(define env (env-set env "ref:A" '((1 0) (0 1))))
(define env (env-set env "ref:b" '(0 0)))

;; Set up boundary registry
(define reg (boundary-reg-empty))
(define reg (boundary-reg-add reg "FANO-v1"
                              '((id . "FANO-v1"))))

;; Execute
(define final-env (run-trace steps reg env))
```

### Example 5: Complete Workflow

```scheme
;; Initialize system
(load "src/integration/bicf-system.scm")
(init-bicf-system)

;; Register FANO boundary
(define fano-boundary
  '((id . "FANO-v1")
    (automorphism . "pgl3-2:std")
    (fano . ((points . (0 1 2 3 4 5 6))
             (lines . ((0 1 3) (0 2 6) (0 4 5)
                      (1 2 4) (1 5 6) (2 3 5) (3 4 6)))))
    (pcg . ((universe . (0 1 2 3 4 5 6 7 8 9 10 11 12 13))))))

(register-boundary fano-boundary)

;; Create choice and realize
(define choice (make-choice "choice-1" '((data . "data1"))))
(define interior (realize choice fano-boundary))

;; Validate
(if (valid? interior fano-boundary)
    (begin
      (display "Interior is valid\n")
      
      ;; Validate FANO structure
      (let ((decoded (cdr (assq 'fano fano-boundary))))
        (check-fano-incidence decoded fano-boundary))
      
      ;; Validate PCG
      (let ((decoded (cdr (assq 'pcg fano-boundary))))
        (check-pcg-pair-cover decoded fano-boundary))
      
      (display "All validations passed\n"))
    (display "Interior is invalid\n"))
```

---

## Troubleshooting

### Common Issues

#### Issue: "Module not found"

**Solution:**
```scheme
;; Ensure you're loading from correct directory
(cd "src/integration")
(load "module-loader.scm")
```

#### Issue: "Boundary not found"

**Solution:**
```scheme
;; Register boundary first
(register-boundary boundary)
;; Then use it
(get-boundary "boundary-id")
```

#### Issue: "Unresolved reference"

**Solution:**
```scheme
;; Ensure all input references are in environment
(define env (env-set env "ref:name" value))
```

#### Issue: "Phase not monotone"

**Solution:**
```scheme
;; Ensure phases are non-decreasing
'((phase . 0) ...)  ; First step
'((phase . 1) ...)  ; Second step
'((phase . 2) ...)  ; Third step
```

### Debugging Tips

1. **Enable Verbose Output:**
   ```scheme
   (define *verbose* #t)
   ```

2. **Check Environment:**
   ```scheme
   (display env)
   ```

3. **Validate Step Structure:**
   ```scheme
   (require-common-fields step)
   ```

4. **Test Individual Components:**
   ```scheme
   (load "src/fano/fano-checker.scm")
   (check-fano-incidence decoded boundary)
   ```

---

## Best Practices

### 1. Always Validate Inputs

```scheme
(if (boundary? boundary)
    (realize choice boundary)
    (error "Invalid boundary"))
```

### 2. Use Explicit Choices

```scheme
;; Good: Explicit choice
(define choice (make-choice "choice-id" data))
(realize choice boundary)

;; Bad: Implicit realization
;; (realize boundary)  ; Not allowed
```

### 3. Check Validity After Realization

```scheme
(define interior (realize choice boundary))
(if (not (valid? interior boundary))
    (error "Realization failed"))
```

### 4. Use Phase Monotonicity

```scheme
;; Ensure phases are sequential
'((phase . 0) ...)
'((phase . 1) ...)
'((phase . 2) ...)
```

### 5. Register Boundaries Before Use

```scheme
;; Register first
(register-boundary boundary)

;; Then use
(define interior (realize choice boundary))
```

---

## Performance Tips

### 1. Cache Validation Results

```scheme
;; Cache FANO validation results
(define *fano-cache* '())
```

### 2. Reuse Environments

```scheme
;; Reuse environment across operations
(define env (env-empty))
;; ... multiple operations ...
```

### 3. Minimize Triple Generation

```scheme
;; For large universes, consider lazy generation
;; (Currently generates all triples upfront)
```

---

## References

- [API Reference](api-reference.md) - Complete API documentation
- [Implementation Guide](implementation-guide.md) - Implementation details
- [Architecture Documentation](architecture.md) - System architecture
- RFC-0001: Boundary–Interior Combinatorial Framework
- RFC-0002: FANO Boundary Module (PG(2,2))
- RFC-0003: CanvasL-POLY: A Deterministic Boundary–Interior Computation Standard



