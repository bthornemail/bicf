# BICF Production System - Implementation Guide

**Version:** 1.0.0  
**Last Updated:** 2025-12-18

This document provides detailed implementation information for the BICF Production System, including architecture, design decisions, code organization, and implementation patterns.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Module Structure](#module-structure)
4. [Implementation Details](#implementation-details)
5. [Design Patterns](#design-patterns)
6. [Code Organization](#code-organization)
7. [Testing Strategy](#testing-strategy)

---

## System Overview

The BICF Production System is a production-ready implementation of the Boundary–Interior Combinatorial Framework (BICF) as specified in RFC-BICF-CANVASL-POLY-001. The system provides:

- **Formal verification** (Lean 4 and Coq)
- **Reference implementation** (R5RS Scheme)
- **Production infrastructure** (Docker, CI/CD, build scripts)
- **Comprehensive testing** (unit, integration, formal verification)

### Key Design Principles

1. **Separation of Concerns:** Boundaries (constraints) are separate from Interiors (data)
2. **Non-Canonicity:** Multiple valid realizations per boundary
3. **Explicit Interfaces:** All transformations require explicit parameters
4. **Determinism:** All operations are deterministic and replayable
5. **Formal Verification:** Core properties are machine-verified

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    BICF Production System                 │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   BICF Core  │  │ FANO Boundary│  │ PCG Consensus│  │
│  │   Module     │  │   Module     │  │   Module     │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                  │                  │          │
│         └──────────────────┼──────────────────┘          │
│                            │                             │
│                   ┌────────▼────────┐                    │
│                   │ CanvasL         │                    │
│                   │ Interpreter     │                    │
│                   └────────┬────────┘                    │
│                            │                             │
│                   ┌────────▼────────┐                    │
│                   │ Integration     │                    │
│                   │ Layer           │                    │
│                   └─────────────────┘                    │
│                                                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │         Formal Verification (Lean 4, Coq)        │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### Component Interactions

1. **BICF Core** provides foundational types and interfaces
2. **FANO Boundary** implements PG(2,2) combinatorial structure
3. **PCG Consensus** provides pair-cover guarantee validation
4. **CanvasL Interpreter** executes CanvasL-POLY JSONL traces
5. **Integration Layer** coordinates all modules

---

## Module Structure

### Directory Organization

```
src/
├── core/              # BICF Core implementation
│   ├── bicf-core.scm
│   └── README.md
├── fano/              # FANO Boundary module
│   ├── fano-checker.scm
│   └── README.md
├── consensus/         # PCG Consensus module
│   ├── pcg-validator.scm
│   └── README.md
├── canvasl/           # CanvasL Interpreter
│   ├── interpreter.scm
│   └── interpreter.scm.md (backup)
├── clbc/              # CLBC container + compiler (deterministic bytecode)
│   ├── bytes.scm
│   ├── uleb128.scm
│   ├── opcodes.scm
│   ├── format.scm
│   ├── compiler.scm
│   └── README.md
├── vm/                # CLBC reference VM
│   ├── clbc-vm.scm
│   └── README.md
├── viz/               # RFC-VIZ-001 deterministic scene model (data-only)
│   └── scene.scm
├── integration/       # Integration layer
│   ├── bicf-system.scm
│   ├── module-loader.scm
│   └── README.md
├── lean/              # Lean 4 formalization
│   └── fano_pcg.lean
├── coq/               # Coq formalization
│   └── Fano_PCG.v
└── index.scm          # Main entry point
```

Additional tooling and tests:

```
tools/
  canvasl-to-clbc.scm  # Compile CanvasL records (Scheme alists) -> CLBC
  clbc-run.scm         # Run CLBC via reference VM; print transcript hash
  viz-scene.scm        # Emit RFC-VIZ-001 scene S-expression

apps/lsp/
  canvasl-lsp.js       # Minimal CanvasL LSP server (Node)

tests/clbc/            # CLBC golden tests
tests/viz/             # RFC-VIZ-001 snapshot tests
```

### Module Dependencies

```
index.scm
  └─> integration/bicf-system.scm
       └─> integration/module-loader.scm
            ├─> core/bicf-core.scm
            ├─> fano/fano-checker.scm
            ├─> consensus/pcg-validator.scm
            └─> canvasl/interpreter.scm
                 ├─> fano/fano-checker.scm (load)
                 └─> consensus/pcg-validator.scm (load)
```

---

## Implementation Details

### BICF Core Module

**File:** `src/core/bicf-core.scm`

#### Data Structures

**Boundary Representation:**
```scheme
'((id . "boundary-id")
  (realize-fn . <function>)      ; Optional
  (transform-fn . <function>))   ; Optional
```

**Interior Representation:**
```scheme
'((boundary-ref . "boundary-id")
  (choice-id . "choice-id")
  (data . <any>)
  (project-fn . <function>))    ; Optional
```

#### Key Algorithms

1. **Validity Checking:** Structural validation of interior-boundary relationship
2. **Realization:** Default realization creates interior with boundary reference
3. **Transformation:** Identity transform by default, customizable per boundary
4. **Projection:** Default projection preserves source reference

#### Implementation Notes

- Uses association lists for all data structures (R5RS compatibility)
- Type predicates validate structure at runtime
- Error handling uses Scheme's `error` function
- Axiom testing functions provide compliance verification

---

### FANO Boundary Module

**File:** `src/fano/fano-checker.scm`

#### Data Structures

**Fano Plane Structure:**
```scheme
'((points . (0 1 2 3 4 5 6))
  (lines . ((0 1 3) (0 2 6) (0 4 5) (1 2 4) (1 5 6) (2 3 5) (3 4 6))))
```

#### Key Algorithms

1. **Incidence Validation:**
   - Check exactly 7 points
   - Check exactly 7 lines
   - Check each line has exactly 3 points
   - Check pairwise uniqueness (O(n²) for n points)

2. **Pairwise Uniqueness:**
   - For each pair of points, count lines containing both
   - Must be exactly 1 line per pair

#### Implementation Notes

- Uses standard Fano plane incidence table from Lean 4 formalization
- Exhaustive checking for finite case (7 points, 7 lines)
- Error messages include failing point/line information
- Supports custom point/line structures via `extract-fano-structure`

---

### PCG Consensus Module

**File:** `src/consensus/pcg-validator.scm`

#### Data Structures

**PCG Structure:**
```scheme
'((universe . (0 1 2 ... 13))
  (lines . ((0 1 3) (0 2 6) ... (10 11 13))))
```

#### Key Algorithms

1. **Triple Generation:**
   - Generate all C(n,3) triples from universe
   - Nested loops: O(n³) time complexity

2. **Pair-Cover Checking:**
   - For each triple, check if ≥2 points are on a common line
   - Exhaustive search through all lines
   - Similar to Lean 4 `native_decide` approach

3. **Two-Fano Construction:**
   - First Fano plane: points 0-6
   - Second Fano plane: points 7-13 (mapped by adding 7)
   - Total: 14 lines (7 + 7)

#### Implementation Notes

- Uses exhaustive checking for finite case (14 points, 14 lines)
- Generates all triples upfront (can be memory-intensive for large universes)
- Error messages identify the first failing triple
- Supports custom universe/line structures

---

### CanvasL Interpreter Module

**File:** `src/canvasl/interpreter.scm`

#### Data Structures

**Environment:**
```scheme
'((ref1 . value1)
  (ref2 . value2)
  ...)
```

**Boundary Registry:**
```scheme
'((boundary-id1 . boundary-object1)
  (boundary-id2 . boundary-object2)
  ...)
```

**Execution Step:**
```scheme
'((id . "step-id")
  (phase . 1)
  (boundary . "FANO-v1")
  (anchor . "commit:abc")
  (op . "apply_encoder")
  (inputs . ("ref1" "ref2"))
  (outputs . ("out1")))
```

#### Key Algorithms

1. **Encoder Application:**
   - Affine encoder: `E(x) = A*x + b`
   - Matrix-vector multiplication
   - Vector addition

2. **Trace Execution:**
   - Sequential processing
   - Phase monotonicity enforcement
   - Forward reference prevention
   - Boundary validation integration

3. **Validation Pipeline:**
   - Schema validation
   - Boundary ID matching
   - Automorphism matching
   - FANO incidence checking
   - PCG pair-cover checking

#### Implementation Notes

- Uses reference-based environment (content-addressable)
- Linear algebra operations implemented from scratch (R5RS compatibility)
- Validation hooks load actual implementations from FANO/PCG modules
- Supports extensible encoder types (currently only affine)

---

### Integration Layer

**Files:** `src/integration/bicf-system.scm`, `src/integration/module-loader.scm`

#### Data Structures

**Module Registry:**
```scheme
'((module-name1 . "path/to/module1.scm")
  (module-name2 . "path/to/module2.scm")
  ...)
```

**System State:**
- `*boundary-registry*` - Global boundary registry
- `*initialized*` - Initialization flag
- `*module-registry*` - Module path registry

#### Key Algorithms

1. **Module Loading:**
   - Registry-based module discovery
   - Sequential loading with dependency resolution
   - Error handling for missing modules

2. **System Coordination:**
   - Lazy initialization
   - Operation routing
   - State management

#### Implementation Notes

- Uses global state (not thread-safe)
- Module paths are relative to integration directory
- Auto-initialization on first operation
- CLI interface provides command routing

---

## Design Patterns

### 1. Association List Pattern

All data structures use association lists (alists) for R5RS compatibility:

```scheme
'((key1 . value1)
  (key2 . value2)
  ...)
```

**Advantages:**
- R5RS standard
- Simple and portable
- Easy to extend

**Disadvantages:**
- O(n) lookup time
- No type safety

### 2. Type Predicate Pattern

Runtime type checking via predicates:

```scheme
(define (boundary? x)
  (and (list? x)
       (assq 'id x)
       (string? (cdr (assq 'id x)))))
```

**Advantages:**
- Runtime validation
- Clear error messages
- Flexible structure

### 3. Error-First Pattern

Functions validate inputs and raise errors early:

```scheme
(define (transform boundary)
  (if (not (boundary? boundary))
      (error "transform: expected Boundary" boundary)
      ...))
```

**Advantages:**
- Fail fast
- Clear error messages
- Easier debugging

### 4. Default Implementation Pattern

Interfaces provide default implementations that can be overridden:

```scheme
(define (realize choice boundary)
  (let ((realize-fn (assq 'realize-fn boundary)))
    (if realize-fn
        ((cdr realize-fn) choice boundary)
        ;; Default implementation
        ...)))
```

**Advantages:**
- Extensible
- Backward compatible
- Customizable per boundary

### 5. Exhaustive Checking Pattern

Finite cases use exhaustive checking (similar to `native_decide`):

```scheme
;; Check all pairs
(let check-pairs ((points points))
  (if (null? points)
      #t
      (let check-with-p1 ((rest (cdr points)))
        ...)))
```

**Advantages:**
- Deterministic
- Complete verification
- No probabilistic elements

---

## Code Organization

### File Structure

Each module follows a consistent structure:

1. **Header Comment:** Module purpose and RFC reference
2. **Type Definitions:** Type predicates and data structures
3. **Constants:** Module-specific constants
4. **Helper Functions:** Internal utility functions
5. **Core Functions:** Public API functions
6. **Examples:** Usage examples (if applicable)

### Naming Conventions

- **Functions:** `kebab-case` (e.g., `check-fano-incidence`)
- **Predicates:** End with `?` (e.g., `boundary?`, `valid?`)
- **Constants:** `kebab-case` (e.g., `fano-line-points`)
- **Global State:** `*surrounded-by-asterisks*` (e.g., `*boundary-registry*`)

### Code Style

- **Indentation:** 2 spaces
- **Comments:** Semicolon-prefixed (`;;`)
- **Line Length:** Prefer readability over strict limits
- **Function Documentation:** Comments above functions

---

## Testing Strategy

### Unit Testing

**Location:** `tests/unit/`

Each module has corresponding unit tests:

- `core.test.scm` - BICF Core axiom tests
- `fano.test.scm` - FANO validation tests (planned)
- `canvasl.test.scm` - CanvasL interpreter tests (planned)
- `consensus.test.scm` - PCG validation tests (planned)

### Integration Testing

**Location:** `tests/integration/`

- `bicf-integration.test.scm` - End-to-end workflows
- Tests boundary → realization → validation flow
- Tests CanvasL execution
- Tests cross-module interactions

### Formal Verification Testing

**Location:** `tests/formal/`

- `verify-lean.sh` - Lean 4 proof verification
- `verify-coq.sh` - Coq proof verification
- Ensures no `sorry`/`admit` statements
- Validates proof compilation

### Test Execution

```bash
# Run all tests
./scripts/test.sh

# Run formal verification
./tests/formal/verify-lean.sh
./tests/formal/verify-coq.sh
```

### CLBC workflow (compile + run)

```bash
# Compile records (Scheme alists) -> CLBC container
guile -s tools/canvasl-to-clbc.scm tests/clbc/mini-validation.input.scm /tmp/out.clbc

# Execute CLBC and print transcript hash
guile -s tools/clbc-run.scm /tmp/out.clbc
```

### RFC-VIZ-001 workflow (scene snapshot)

```bash
# Generate a deterministic scene S-expression
guile -s tools/viz-scene.scm 3 0 1

# Or run the repo snapshot test
bash tests/viz/run-scene-snapshot.sh
```

### LSP workflow (manual run)

```bash
# Run the LSP server (stdio)
node apps/lsp/canvasl-lsp.js
```

Custom methods exposed by the server (MVP):
- `canvasl/getScene`
- `canvasl/getTrace`
- `canvasl/getIncidence`

---

## Performance Characteristics

### Time Complexity

- **FANO Validation:** O(n²) where n = number of points (7)
- **PCG Validation:** O(n³) where n = universe size (14)
- **Environment Lookup:** O(m) where m = number of bindings
- **Trace Execution:** O(s) where s = number of steps

### Space Complexity

- **Environment:** O(m) where m = number of references
- **Boundary Registry:** O(b) where b = number of boundaries
- **PCG Triple Generation:** O(n³) for triple storage

### Optimization Opportunities

1. **Hash Tables:** Replace alists with hash tables for O(1) lookup
2. **Caching:** Cache validation results
3. **Lazy Evaluation:** Generate triples on-demand
4. **Parallel Processing:** Parallelize PCG triple checking

---

## Extensibility

### Adding New Boundary Types

1. Create boundary module (e.g., `src/custom/custom-boundary.scm`)
2. Implement validation function: `check-custom-boundary decoded boundary`
3. Register in module loader
4. Add validation hook in interpreter

### Adding New Encoder Types

1. Extend `make-encoder-*` functions
2. Add case in `apply_encoder` operation
3. Implement encoder-specific logic

### Adding New Operations

1. Add case in `exec-step` function
2. Implement operation logic
3. Update documentation

---

## Security Considerations

### Input Validation

- All inputs are validated before processing
- Type predicates check structure
- Required fields are enforced

### Error Handling

- Errors include context information
- No sensitive data in error messages
- Fail-safe defaults where appropriate

### Determinism

- All operations are deterministic
- No random number generation
- Reproducible execution

---

## Future Enhancements

### Planned Features

1. **Assembly Language Generation:** Generate AAL from validated interiors
2. **Performance Optimizations:** Hash tables, caching, parallelization
3. **Additional Encoder Types:** Polynomial, trigonometric, etc.
4. **Extended Validation:** Additional boundary types
5. **Thread Safety:** Concurrent execution support

### Research Directions

1. **Incremental Validation:** Validate only changed portions
2. **Distributed Execution:** Multi-node trace execution
3. **Proof Generation:** Automatic proof generation from validation
4. **Optimization:** Compile-time optimizations

---

## References

- RFC-0001: Boundary–Interior Combinatorial Framework
- RFC-0002: FANO Boundary Module (PG(2,2))
- RFC-0003: CanvasL-POLY: A Deterministic Boundary–Interior Computation Standard
- Lean 4 Formalization: `src/lean/fano_pcg.lean`
- Coq Formalization: `src/coq/Fano_PCG.v`



