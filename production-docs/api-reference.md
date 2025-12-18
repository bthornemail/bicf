# BICF Production System - API Reference

**Version:** 1.1.0  
**Last Updated:** 2025-12-18  
**Languages:** R5RS Scheme (core + tooling CLIs), Node.js (LSP)

This document provides a complete API reference for the BICF Production System. All functions, types, and interfaces are documented with signatures, parameters, return values, and usage examples.

---

## Table of Contents

1. [BICF Core Module](#bicf-core-module)
2. [FANO Boundary Module](#fano-boundary-module)
3. [PCG Consensus Module](#pcg-consensus-module)
4. [CanvasL Interpreter Module](#canvasl-interpreter-module)
5. [Integration Layer](#integration-layer)
6. [Module Loader](#module-loader)
7. [CLBC (CanvasL ByteCode)](#clbc-canvasl-bytecode)
8. [CLBC Reference VM](#clbc-reference-vm)
9. [RFC-VIZ-001 Scene Model (MVP)](#rfc-viz-001-scene-model-mvp)
10. [CanvasL LSP (MVP)](#canvasl-lsp-mvp)

---

## BICF Core Module

**File:** `src/core/bicf-core.scm`  
**Implements:** RFC-0001: Boundary–Interior Combinatorial Framework

### Type Definitions

#### `boundary? x → boolean`

Type predicate for Boundary objects.

**Parameters:**
- `x` - Any value

**Returns:** `#t` if `x` is a valid Boundary (alist with `'id` field containing a string), `#f` otherwise

**Example:**
```scheme
(boundary? '((id . "test-boundary")))  ; => #t
(boundary? '((name . "test")))         ; => #f
```

---

#### `interior? x → boolean`

Type predicate for Interior objects.

**Parameters:**
- `x` - Any value

**Returns:** `#t` if `x` is a valid Interior (alist with `'boundary-ref` field containing a string), `#f` otherwise

**Example:**
```scheme
(interior? '((boundary-ref . "test-boundary")))  ; => #t
```

---

#### `view? x → boolean`

Type predicate for View objects (projections of Interiors).

**Parameters:**
- `x` - Any value

**Returns:** `#t` if `x` is a valid View (alist with `'source-ref` field), `#f` otherwise

---

#### `choice? x → boolean`

Type predicate for Choice objects (realization parameters).

**Parameters:**
- `x` - Any value

**Returns:** `#t` if `x` is a valid Choice (alist with `'choice-id` field), `#f` otherwise

---

#### `difference? x → boolean`

Type predicate for Difference objects (structural differences between Interiors).

**Parameters:**
- `x` - Any value

**Returns:** `#t` if `x` is a valid Difference (alist with `'diff-type` field), `#f` otherwise

---

### Core Judgment

#### `valid? interior boundary → boolean`

**Validity predicate:** Checks if an Interior satisfies a Boundary.

**Parameters:**
- `interior` - Interior object
- `boundary` - Boundary object

**Returns:** `#t` if the interior is valid for the boundary, `#f` otherwise

**Preconditions:**
- `interior` must be a valid Interior
- `boundary` must be a valid Boundary
- Interior's `boundary-ref` must match boundary's `id`

**Example:**
```scheme
(define boundary '((id . "FANO-v1")))
(define interior '((boundary-ref . "FANO-v1") (data . "...")))
(valid? interior boundary)  ; => #t
```

---

#### `sat interior boundary → boolean`

**Notation helper:** Alias for `valid?`. Represents the mathematical notation `i ⊨ b`.

**Parameters:**
- `interior` - Interior object
- `boundary` - Boundary object

**Returns:** Same as `valid?`

---

### Required Interfaces

#### `transform boundary → boundary`

**Boundary transformation:** Transforms a Boundary to another Boundary.

**Parameters:**
- `boundary` - Boundary object

**Returns:** Transformed Boundary object

**Behavior:**
- If boundary has a custom `transform-fn`, applies it
- Otherwise returns the boundary unchanged (identity transform)
- Preserves boundary validity
- Does not require access to interior state

**Errors:**
- Raises error if `boundary` is not a valid Boundary

**Example:**
```scheme
(define b '((id . "test") (transform-fn . ,(lambda (b) b))))
(transform b)  ; => transformed boundary
```

---

#### `realize choice boundary → interior`

**Realization interface:** Produces an Interior from a Boundary and Choice.

**Parameters:**
- `choice` - Choice object (realization parameters)
- `boundary` - Boundary object

**Returns:** Interior object that satisfies the boundary

**Behavior:**
- If boundary has a custom `realize-fn`, uses it
- Otherwise creates a default interior with boundary reference
- Non-canonical: different choices may produce different interiors

**Errors:**
- Raises error if `choice` is not a valid Choice
- Raises error if `boundary` is not a valid Boundary

**Example:**
```scheme
(define choice '((choice-id . "choice1") (data . "data1")))
(define boundary '((id . "test-boundary")))
(realize choice boundary)
; => '((boundary-ref . "test-boundary") (choice-id . "choice1") (data . "data1"))
```

---

#### `project interior → view`

**Projection interface:** Creates a View from an Interior (may discard information).

**Parameters:**
- `interior` - Interior object

**Returns:** View object

**Behavior:**
- If interior has a custom `project-fn`, uses it
- Otherwise creates a default view with source reference
- Does not introduce new constraints
- Deterministic with respect to the interior

**Errors:**
- Raises error if `interior` is not a valid Interior

**Example:**
```scheme
(define interior '((boundary-ref . "test") (data . "data")))
(project interior)
; => '((source-ref . "test") (view-data . "data"))
```

---

#### `difference interior1 interior2 → difference`

**Difference computation:** Computes structural difference between two Interiors.

**Parameters:**
- `interior1` - First Interior object
- `interior2` - Second Interior object

**Returns:** Difference object containing structural comparison

**Behavior:**
- Compares data fields structurally
- Does not alter either operand
- Returns difference object with `diff-type`, `from`, `to`, and `equal?` fields

**Errors:**
- Raises error if either parameter is not a valid Interior

**Example:**
```scheme
(define i1 '((boundary-ref . "test") (data . "data1")))
(define i2 '((boundary-ref . "test") (data . "data2")))
(difference i1 i2)
; => '((diff-type . structural) (from . "data1") (to . "data2") (equal? . #f))
```

---

### Axiom Testing Functions

#### `axiom1-boundary-interior-duality interior boundary → boolean`

Tests Axiom 1: Boundary–Interior Duality.

**Parameters:**
- `interior` - Interior object
- `boundary` - Boundary object

**Returns:** `#t` if axiom holds, `#f` otherwise

---

#### `axiom2-non-canonicity boundary choice1 choice2 → boolean`

Tests Axiom 2: Non-Canonicity of Realization.

**Parameters:**
- `boundary` - Boundary object
- `choice1` - First Choice object
- `choice2` - Second Choice object

**Returns:** `#t` if choices are different (enforcing non-canonicity), `#f` otherwise

**Errors:**
- Raises error if any parameter is invalid

---

#### `axiom3-boundary-primacy boundary choice → boolean`

Tests Axiom 3: Boundary Primacy in Transformation.

**Parameters:**
- `boundary` - Boundary object
- `choice` - Choice object

**Returns:** `#t` if transformed boundary produces valid interior, `#f` otherwise

---

#### `axiom4-explicit-realization boundary → boolean`

Tests Axiom 4: Explicit Realization Interface.

**Parameters:**
- `boundary` - Boundary object

**Returns:** Always `#t` (enforced by type system)

---

#### `axiom5-projection-safety interior boundary → boolean`

Tests Axiom 5: Projection Does Not Alter Validity.

**Parameters:**
- `interior` - Interior object
- `boundary` - Boundary object

**Returns:** `#t` if projection is safe, `#f` otherwise

---

### Compliance Testing

#### `test-bicf-compliance boundary choice1 choice2 → alist`

Tests all BICF axioms for a given boundary and choices.

**Parameters:**
- `boundary` - Boundary object
- `choice1` - First Choice object (optional)
- `choice2` - Second Choice object (optional)

**Returns:** Alist with test results: `((axiom1 . #t) (axiom2 . #t) ...)`

**Example:**
```scheme
(define boundary (make-simple-boundary "test"))
(define choice1 (make-choice "c1" '((data . "d1"))))
(define choice2 (make-choice "c2" '((data . "d2"))))
(test-bicf-compliance boundary choice1 choice2)
; => ((axiom5 . #t) (axiom4 . #t) (axiom3 . #t) (axiom2 . #t) (axiom1 . #t))
```

---

### Helper Functions

#### `make-boundary id realize-fn transform-fn → boundary`

Creates a boundary with custom realization and transformation functions.

**Parameters:**
- `id` - String identifier
- `realize-fn` - Function: `(choice boundary) → interior`
- `transform-fn` - Function: `(boundary) → boundary`

**Returns:** Boundary object

---

#### `make-choice choice-id data → choice`

Creates a choice object.

**Parameters:**
- `choice-id` - String identifier
- `data` - Any data value

**Returns:** Choice object

---

#### `make-simple-boundary id → boundary`

Creates a simple boundary with identity transform and default realization.

**Parameters:**
- `id` - String identifier

**Returns:** Boundary object

---

## FANO Boundary Module

**File:** `src/fano/fano-checker.scm`  
**Implements:** RFC-0002: FANO Boundary Module (PG(2,2))

### Constants

#### `fano-line-points`

Standard Fano plane incidence table (7 lines, each with 3 points).

**Value:**
```scheme
'((0 1 3)    ; L0
  (0 2 6)    ; L1
  (0 4 5)    ; L2
  (1 2 4)    ; L3
  (1 5 6)    ; L4
  (2 3 5)    ; L5
  (3 4 6))   ; L6
```

---

### Helper Functions

#### `point-in-line? point line → boolean`

Checks if a point is contained in a line.

**Parameters:**
- `point` - Integer point identifier
- `line` - List of points (line)

**Returns:** `#t` if point is in line, `#f` otherwise

---

#### `points-on-same-line? p1 p2 lines → boolean`

Checks if two points lie on the same line.

**Parameters:**
- `p1` - First point identifier
- `p2` - Second point identifier
- `lines` - List of lines

**Returns:** `#t` if both points are on a common line, `#f` otherwise

---

#### `extract-fano-structure decoded → (points . lines)`

Extracts points and lines from decoded structure.

**Parameters:**
- `decoded` - Alist potentially containing `'points` and `'lines` fields

**Returns:** Pair `(points . lines)` where:
- `points` - List of point identifiers (defaults to `(0 1 2 3 4 5 6)`)
- `lines` - List of lines (defaults to `fano-line-points`)

---

### Main Validation Function

#### `check-fano-incidence decoded boundary → boolean`

**FANO incidence validation:** Validates that a structure satisfies Fano plane axioms.

**Parameters:**
- `decoded` - Decoded structure (alist with optional `'points` and `'lines` fields)
- `boundary` - Boundary object (currently unused but required for interface)

**Returns:** `#t` if structure is a valid Fano plane, raises error otherwise

**Validation Checks:**
1. Exactly 7 points
2. Exactly 7 lines
3. Each line contains exactly 3 points
4. Any two distinct points lie on exactly one line

**Errors:**
- Raises error with descriptive message if any validation fails

**Example:**
```scheme
(define decoded '((points . (0 1 2 3 4 5 6))
                  (lines . ((0 1 3) (0 2 6) (0 4 5) (1 2 4) (1 5 6) (2 3 5) (3 4 6)))))
(define boundary '((id . "FANO-v1")))
(check-fano-incidence decoded boundary)  ; => #t
```

---

## PCG Consensus Module

**File:** `src/consensus/pcg-validator.scm`  
**Implements:** RFC-0002 and RFC-0003: Pair-Cover Guarantee

### Constants

#### `fano-lines-first`

First Fano plane lines (points 0-6).

**Value:**
```scheme
'((0 1 3) (0 2 6) (0 4 5) (1 2 4) (1 5 6) (2 3 5) (3 4 6))
```

---

#### `fano-lines-second`

Second Fano plane lines (points 7-13, mapped from first by adding 7).

---

#### `all-pcg-lines`

All 14 lines (7 from first Fano + 7 from second Fano).

---

### Helper Functions

#### `point-in-line? point line → boolean`

Checks if a point is in a line.

**Parameters:**
- `point` - Integer point identifier
- `line` - List of points

**Returns:** `#t` if point is in line, `#f` otherwise

---

#### `count-triple-in-line triple line → integer`

Counts how many points from a triple are in a line.

**Parameters:**
- `triple` - List of three point identifiers `(p1 p2 p3)`
- `line` - List of points

**Returns:** Integer count (0-3)

---

#### `triple-covered? triple lines → boolean`

Checks if a triple is covered by at least one line (≥2 points on line).

**Parameters:**
- `triple` - List of three point identifiers
- `lines` - List of lines

**Returns:** `#t` if triple is covered, `#f` otherwise

---

#### `generate-triples points → list`

Generates all possible triples from a universe of points.

**Parameters:**
- `points` - List of point identifiers

**Returns:** List of all triples `((p1 p2 p3) ...)`

**Example:**
```scheme
(generate-triples '(0 1 2))
; => ((0 1 2))
(generate-triples '(0 1 2 3))
; => ((0 1 2) (0 1 3) (0 2 3) (1 2 3))
```

---

#### `extract-pcg-structure decoded → (universe . lines)`

Extracts universe and lines from decoded structure.

**Parameters:**
- `decoded` - Alist potentially containing `'universe` and `'lines` fields

**Returns:** Pair `(universe . lines)` where:
- `universe` - List of point identifiers (defaults to `(0 1 2 ... 13)`)
- `lines` - List of lines (defaults to `all-pcg-lines`)

---

### Main Validation Function

#### `check-pcg-pair-cover decoded boundary → boolean`

**PCG validation:** Validates Pair-Cover Guarantee.

**Parameters:**
- `decoded` - Decoded structure (alist with optional `'universe` and `'lines` fields)
- `boundary` - Boundary object (currently unused but required for interface)

**Returns:** `#t` if PCG holds, raises error otherwise

**PCG Statement:**
For every triple `T ⊆ U` with `|T| = 3`, there exists a line `ℓ ∈ L` such that `|T ∩ ℓ| ≥ 2`.

**Behavior:**
- Generates all possible triples from universe
- Checks each triple is covered by at least one line
- Uses exhaustive checking (similar to Lean 4 `native_decide`)

**Errors:**
- Raises error with triple that fails PCG if validation fails

**Example:**
```scheme
(define decoded '((universe . (0 1 2 3 4 5 6 7 8 9 10 11 12 13))))
(define boundary '((id . "FANO-v1")))
(check-pcg-pair-cover decoded boundary)  ; => #t
```

---

## CanvasL Interpreter Module

**File:** `src/canvasl/interpreter.scm`  
**Implements:** RFC-0003: CanvasL-POLY

### Utility Functions

#### `alist-ref a k → value | #f`

Gets value from alist by key.

**Parameters:**
- `a` - Association list
- `k` - Key (symbol)

**Returns:** Value associated with key, or `#f` if not found

---

#### `alist-ref/req a k → value`

Gets required value from alist by key.

**Parameters:**
- `a` - Association list
- `k` - Key (symbol)

**Returns:** Value associated with key

**Errors:**
- Raises error if key not found

---

#### `ensure pred msg x → x`

Ensures a value satisfies a predicate.

**Parameters:**
- `pred` - Predicate function
- `msg` - Error message string
- `x` - Value to check

**Returns:** `x` if predicate holds

**Errors:**
- Raises error with message if predicate fails

---

### Environment Management

#### `env-empty → environment`

Creates an empty environment.

**Returns:** Empty environment (empty list)

---

#### `env-get env ref → value | #f`

Gets value from environment by reference.

**Parameters:**
- `env` - Environment (alist)
- `ref` - Reference string

**Returns:** Value associated with reference, or `#f` if not found

---

#### `env-get/req env ref → value`

Gets required value from environment by reference.

**Parameters:**
- `env` - Environment
- `ref` - Reference string

**Returns:** Value associated with reference

**Errors:**
- Raises error if reference not found

---

#### `env-set env ref val → environment`

Sets value in environment.

**Parameters:**
- `env` - Environment
- `ref` - Reference string
- `val` - Value

**Returns:** New environment with added binding

---

### Boundary Registry

#### `boundary-reg-empty → registry`

Creates an empty boundary registry.

**Returns:** Empty registry

---

#### `boundary-reg-add reg id boundary-obj → registry`

Adds a boundary to the registry.

**Parameters:**
- `reg` - Boundary registry
- `id` - Boundary identifier string
- `boundary-obj` - Boundary object

**Returns:** New registry with added boundary

---

#### `boundary-reg-get/req reg id → boundary`

Gets required boundary from registry.

**Parameters:**
- `reg` - Boundary registry
- `id` - Boundary identifier string

**Returns:** Boundary object

**Errors:**
- Raises error if boundary not found

---

### Linear Algebra Operations

#### `vec? v → boolean`

Type predicate for vectors (lists of numbers).

**Parameters:**
- `v` - Value to check

**Returns:** `#t` if `v` is a list of numbers, `#f` otherwise

---

#### `mat? m → boolean`

Type predicate for matrices (lists of vectors).

**Parameters:**
- `m` - Value to check

**Returns:** `#t` if `m` is a list of vectors, `#f` otherwise

---

#### `dot a b → number`

Computes dot product of two vectors.

**Parameters:**
- `a` - Vector (list of numbers)
- `b` - Vector (list of numbers)

**Returns:** Dot product (number)

**Errors:**
- Raises error if vectors have different lengths

---

#### `mat-vec-mul A x → vector`

Multiplies matrix by vector.

**Parameters:**
- `A` - Matrix (list of vectors)
- `x` - Vector

**Returns:** Result vector

---

#### `vec-add a b → vector`

Adds two vectors element-wise.

**Parameters:**
- `a` - First vector
- `b` - Second vector

**Returns:** Sum vector

**Errors:**
- Raises error if vectors have different lengths

---

### Encoder Operations

#### `make-encoder-affine ring basis-dim A-ref b-ref → encoder`

Creates an affine encoder object.

**Parameters:**
- `ring` - Ring identifier string (e.g., "Z")
- `basis-dim` - Basis dimension (integer)
- `A-ref` - Reference to matrix A
- `b-ref` - Reference to vector b

**Returns:** Encoder object (alist)

---

#### `encoder-kind enc → symbol`

Gets the kind of an encoder.

**Parameters:**
- `enc` - Encoder object

**Returns:** Encoder kind symbol (e.g., `'affine`)

**Errors:**
- Raises error if `kind` field not found

---

### Validation Hooks

#### `check-schema step → boolean`

Schema validation check (placeholder).

**Parameters:**
- `step` - Execution step

**Returns:** Always `#t`

---

#### `check-boundary-id-match step boundary-id → boolean`

Checks that step's boundary matches expected boundary ID.

**Parameters:**
- `step` - Execution step
- `boundary-id` - Expected boundary identifier

**Returns:** `#t` if match, raises error otherwise

**Errors:**
- Raises error if boundary IDs don't match

---

#### `check-automorphism-match step boundary → boolean`

Checks automorphism match (placeholder).

**Parameters:**
- `step` - Execution step
- `boundary` - Boundary object

**Returns:** Always `#t`

---

#### `check-fano-incidence decoded boundary → boolean`

FANO incidence validation (loaded from `fano-checker.scm`).

**Parameters:**
- `decoded` - Decoded structure
- `boundary` - Boundary object

**Returns:** `#t` if valid, raises error otherwise

---

#### `check-pcg-pair-cover decoded boundary → boolean`

PCG validation (loaded from `pcg-validator.scm`).

**Parameters:**
- `decoded` - Decoded structure
- `boundary` - Boundary object

**Returns:** `#t` if PCG holds, raises error otherwise

---

### Decoder

#### `decode-under-boundary encoded boundary → (decoded . proof)`

Decodes encoded data under a boundary.

**Parameters:**
- `encoded` - Encoded data
- `boundary` - Boundary object

**Returns:** Pair `(decoded . proof)` where:
- `decoded` - Decoded structure
- `proof` - Proof object (currently `'ok`)

---

### Step Execution

#### `require-common-fields step → boolean`

Validates that step has all required common fields.

**Parameters:**
- `step` - Execution step (alist)

**Required Fields:**
- `id` - Step identifier
- `phase` - Phase number
- `boundary` - Boundary identifier
- `anchor` - Anchor reference
- `op` - Operation name
- `inputs` - List of input references
- `outputs` - List of output references

**Returns:** `#t` if valid

**Errors:**
- Raises error if any required field is missing or invalid

---

#### `strict-phase-check prev-phase step → integer`

Checks that phase is monotone non-decreasing.

**Parameters:**
- `prev-phase` - Previous phase number
- `step` - Execution step

**Returns:** Current phase number

**Errors:**
- Raises error if phase decreases

---

#### `no-forward-refs-check env step → boolean`

Checks that all input references are resolved (no forward references).

**Parameters:**
- `env` - Current environment
- `step` - Execution step

**Returns:** `#t` if all references resolved

**Errors:**
- Raises error if any input reference is unresolved

---

#### `exec-step env boundary-reg step → (new-env . outputs)`

Executes a single step.

**Parameters:**
- `env` - Current environment
- `boundary-reg` - Boundary registry
- `step` - Execution step

**Returns:** Pair `(new-env . outputs)` where:
- `new-env` - Updated environment
- `outputs` - List of output references produced

**Supported Operations:**
- `"define_encoder"` - Defines a polynomial encoder
- `"apply_encoder"` - Applies an encoder to variables
- `"decode_and_validate"` - Decodes and validates under boundary

**Errors:**
- Raises error for unknown operations or validation failures

**Example:**
```scheme
(define step '((id . "step-1") (phase . 1) (boundary . "FANO-v1")
               (anchor . "commit:abc") (op . "apply_encoder")
               (encoder_ref . "enc:E.local.1")
               (vars . ((x . "ref:state_vector:t1")))
               (inputs . ("enc:E.local.1" "ref:state_vector:t1"))
               (outputs . ("state:encoded:t1"))))
(exec-step env boundary-reg step)
; => (new-env . ("state:encoded:t1"))
```

---

### Trace Execution

#### `run-trace steps boundary-reg initial-env → environment`

Executes a complete trace of steps.

**Parameters:**
- `steps` - List of execution steps
- `boundary-reg` - Boundary registry
- `initial-env` - Initial environment

**Returns:** Final environment after executing all steps

**Behavior:**
- Processes steps sequentially
- Enforces phase monotonicity
- Prevents forward references
- Validates all operations
- Applies boundary-specific validation checks

**Errors:**
- Raises error on phase violations, forward references, or validation failures

**Example:**
```scheme
(define steps (list step1 step2 step3))
(define final-env (run-trace steps boundary-reg initial-env))
(env-get final-env "state:decoded:t1")
```

---

## Integration Layer

**File:** `src/integration/bicf-system.scm`

### System Initialization

#### `init-bicf-system → void`

Initializes the BICF system.

**Behavior:**
- Loads all core modules
- Sets up system state
- Displays initialization message

**Returns:** `#<unspecified>`

---

### Boundary Registry

#### `register-boundary boundary → string`

Registers a boundary in the system registry.

**Parameters:**
- `boundary` - Boundary object

**Returns:** Boundary identifier string

**Behavior:**
- Auto-initializes system if not already initialized
- Adds boundary to internal registry
- Returns boundary ID

---

#### `get-boundary boundary-id → boundary`

Gets a boundary from the registry by ID.

**Parameters:**
- `boundary-id` - Boundary identifier string

**Returns:** Boundary object

**Errors:**
- Raises error if boundary not found

---

### Operation Execution

#### `execute-bicf-operation op . args → value`

Executes a BICF operation.

**Parameters:**
- `op` - Operation symbol: `register-boundary`, `get-boundary`, `realize`, `transform`, `project`, `valid?`
- `args` - Operation-specific arguments

**Returns:** Operation-specific return value

**Behavior:**
- Auto-initializes system if needed
- Routes to appropriate function based on operation

**Errors:**
- Raises error for unknown operations

**Example:**
```scheme
(execute-bicf-operation 'realize choice boundary)
(execute-bicf-operation 'valid? interior boundary)
```

---

### CLI Interface

#### `bicf-cli args → void`

Command-line interface helper.

**Parameters:**
- `args` - List of command-line arguments

**Commands:**
- `help` - Display help message
- `init` - Initialize system
- `register` - Register a boundary
- `get` - Get a boundary by ID

**Example:**
```scheme
(bicf-cli '("help"))
(bicf-cli '("init"))
(bicf-cli '("register" boundary))
```

---

## Module Loader

**File:** `src/integration/module-loader.scm`

### Module Registry

#### `register-module name path → void`

Registers a module in the module registry.

**Parameters:**
- `name` - Module name (symbol)
- `path` - Module file path (string)

**Behavior:**
- Adds module to internal registry

---

#### `load-module name → void`

Loads a module by name.

**Parameters:**
- `name` - Module name (symbol)

**Behavior:**
- Looks up module path in registry
- Loads the module file

**Errors:**
- Raises error if module not found

---

### Module Initialization

#### `init-module-registry → void`

Initializes the module registry with standard modules.

**Registered Modules:**
- `bicf-core` → `../core/bicf-core.scm`
- `fano-checker` → `../fano/fano-checker.scm`
- `pcg-validator` → `../consensus/pcg-validator.scm`
- `canvasl-interpreter` → `../canvasl/interpreter.scm`

---

#### `load-all-modules → void`

Loads all core modules.

**Behavior:**
- Initializes module registry
- Loads all registered modules in order

---

## Main Entry Point

**File:** `src/index.scm`

### Main Function

#### `main args → void`

Main entry point for the BICF system.

**Parameters:**
- `args` - Command-line arguments (list)

**Behavior:**
- Initializes system on load
- Routes to CLI interface
- Executes commands

**Usage:**
```bash
guile -s src/index.scm help
guile -s src/index.scm init
```

---

## Error Handling

All functions follow consistent error handling:

- **Type errors:** Raised when parameters don't match expected types
- **Missing field errors:** Raised when required fields are absent
- **Validation errors:** Raised when validation checks fail
- **Not found errors:** Raised when resources (boundaries, modules, etc.) are not found

Error messages include context to aid debugging.

---

## Type System

The BICF system uses a structural type system based on association lists:

- **Boundary:** Alist with `'id` field (string)
- **Interior:** Alist with `'boundary-ref` field (string)
- **View:** Alist with `'source-ref` field
- **Choice:** Alist with `'choice-id` field
- **Difference:** Alist with `'diff-type` field

Type predicates (`boundary?`, `interior?`, etc.) validate structure at runtime.

---

## Concurrency and Thread Safety

The current implementation is **not thread-safe**. All state is global and mutable. For concurrent use, consider:

- Using separate environments per thread
- Implementing locking mechanisms
- Using immutable data structures

---

## Performance Considerations

- **PCG validation:** Exhaustive checking of all triples - O(n³) where n is universe size
- **FANO validation:** O(n²) for pairwise checks where n is number of points
- **Environment lookups:** O(n) linear search in association lists
- **Trace execution:** O(m) where m is number of steps

For large-scale use, consider:
- Caching validation results
- Using hash tables for environments
- Optimizing triple generation

---

## Version History

- **1.0.0** (2024-12-19): Initial production release
  - Complete BICF Core implementation
  - FANO and PCG validation
  - CanvasL interpreter
  - Integration layer

- **1.1.0** (2025-12-18): Tooling + deterministic harness additions
  - CLBC container + compiler + reference VM
  - RFC-VIZ-001 deterministic scene generator + snapshot tests
  - Minimal CanvasL LSP server (custom methods; no engine side-effects)

---

## References

- RFC-0001: Boundary–Interior Combinatorial Framework
- RFC-0002: FANO Boundary Module (PG(2,2))
- RFC-0003: CanvasL-POLY: A Deterministic Boundary–Interior Computation Standard

---

## CLBC (CanvasL ByteCode)

**Files:** `src/clbc/bytes.scm`, `src/clbc/uleb128.scm`, `src/clbc/opcodes.scm`, `src/clbc/format.scm`, `src/clbc/compiler.scm`  
**CLI:** `tools/canvasl-to-clbc.scm`

CLBC is a deterministic container + bytecode stream intended for golden-testing and embedded parity.

### CLBC compiler entrypoints

#### `canvasl-records->clbc records → (table . bytes)`

Compiles a list of CanvasL records (alist datums) into a CLBC container byte list.

**Parameters:**
- `records` - List of alists (one record per step)

**Returns:**
- Pair `(table . bytes)` where `bytes` is the CLBC container (list of u8)

#### `read-records-from-port port → records`

Reads one Scheme datum at a time from `port` until EOF, returning a list of alists.

### CLI: CanvasL records → CLBC

```bash
guile -s tools/canvasl-to-clbc.scm input.scm output.clbc
```

**Notes:**
- `input.scm` is expected to contain one Scheme datum per line (an alist record), compatible with `read-records-from-port`.

---

## CLBC Reference VM

**File:** `src/vm/clbc-vm.scm`  
**CLI:** `tools/clbc-run.scm`

Minimal deterministic VM for executing CLBC byte streams and producing a transcript hash.

### VM entrypoints

#### `vm-run-clbc-bytes clbc-bytes → alist`

Executes CLBC bytes and returns an alist result:
- `(ok? . boolean)` success flag
- `(transcript-hash . string)` rolling transcript hash
- `(events . integer)` number of events observed
- `(errors . (list string))` deterministic error list

#### `read-file-bytes path → (list u8)`

Reads a file as a byte list.

### CLI: Run CLBC and print transcript

```bash
guile -s tools/clbc-run.scm program.clbc
```

---

## RFC-VIZ-001 Scene Model (MVP)

**File:** `src/viz/scene.scm`  
**CLI:** `tools/viz-scene.scm`

Pure deterministic “scene graph” generator (data only) suitable for snapshot/golden testing.

### Scene generation

#### `viz-make-scene k has-global-decision? include-fano? fano-points fano-lines → scene`

Returns a deterministic alist structure rooted at `ContextRoot` with:
- `ClosureEnvelope`
- `StructureProxy`
- `IncidenceOverlay`
- `TraceLayer`

### CLI: Generate a scene snapshot

```bash
guile -s tools/viz-scene.scm <k> <globalDecision:0|1> <includeFano:0|1>
```

---

## CanvasL LSP (MVP)

**File:** `apps/lsp/canvasl-lsp.js`  
**Language:** Node.js (no external deps)

Minimal Language Server Protocol implementation focused on deterministic tooling and custom CanvasL methods.

### Custom request methods

#### `canvasl/getScene → object`

Returns a deterministic placeholder scene object (MVP).

#### `canvasl/getTrace → object`

Returns a minimal trace summary (MVP placeholder).

#### `canvasl/getIncidence → object`

Returns Fano incidence payload (points + lines) as a deterministic response.



