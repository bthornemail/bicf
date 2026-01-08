# BICF Production System - Architecture Documentation

**Version:** 1.1.0  
**Last Updated:** 2025-12-18

This document describes the system architecture of the BICF Production System, including component interactions, data flows, module dependencies, and integration points.

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Component Diagram](#component-diagram)
3. [Data Flow](#data-flow)
4. [Module Dependencies](#module-dependencies)
5. [Integration Points](#integration-points)
6. [Formal Verification Integration](#formal-verification-integration)

---

## System Architecture

### Overview

The BICF Production System implements a layered architecture with clear separation between:

- **Core Framework** (BICF axioms and interfaces)
- **Boundary Modules** (FANO, future custom boundaries)
- **Consensus Mechanisms** (PCG validation)
- **Execution Layer** (CanvasL interpreter)
- **Integration Layer** (System coordination)
- **Deterministic Tooling Layer** (CLBC compiler/VM, RFC-VIZ-001 scene model, LSP)

### Architectural Principles

1. **Modularity:** Each component is independently testable
2. **Separation of Concerns:** Boundaries separate from Interiors
3. **Explicit Interfaces:** All interactions through defined APIs
4. **Formal Verification:** Core properties machine-verified
5. **Determinism:** All operations are deterministic and replayable
6. **Canonical Identity:** Events use `rid = sha256(CLBC_bytes)`; arrival time is irrelevant
7. **Dialect Constraints:** 8D–11D enforces `|deps|=2`, 12D–15D enforces `|deps|=3`, +16D is non-canonical metadata only

---

## Component Diagram

```mermaid
graph TB
    subgraph "Entry Point"
        Index[src/index.scm<br/>Main Entry]
    end
    
    subgraph "Integration Layer"
        System[src/integration/bicf-system.scm<br/>System Coordination]
        Loader[src/integration/module-loader.scm<br/>Module Loader]
    end
    
    subgraph "Core Framework"
        Core[src/core/bicf-core.scm<br/>BICF Core<br/>Axioms & Interfaces]
    end
    
    subgraph "Boundary Modules"
        FANO[src/fano/fano-checker.scm<br/>FANO Boundary<br/>PG(2,2) Validation]
    end
    
    subgraph "Consensus"
        PCG[src/consensus/pcg-validator.scm<br/>PCG Validator<br/>Pair-Cover Guarantee]
    end
    
    subgraph "Execution Layer"
        Interpreter[src/canvasl/interpreter.scm<br/>CanvasL Interpreter<br/>JSONL Execution]
    end

    subgraph "Deterministic Tooling Layer"
        CLBC[src/clbc/*.scm<br/>CLBC Container+Compiler]
        VM[src/vm/clbc-vm.scm<br/>CLBC Reference VM]
        Viz[src/viz/scene.scm<br/>RFC-VIZ-001 Scene Model]
        LSP[apps/lsp/canvasl-lsp.js<br/>CanvasL LSP (Node)]
    end
    
    subgraph "Formal Verification"
        Lean[src/lean/fano_pcg.lean<br/>Lean 4 Proofs]
        Coq[src/coq/Fano_PCG.v<br/>Coq Proofs]
    end
    
    Index --> System
    System --> Loader
    Loader --> Core
    Loader --> FANO
    Loader --> PCG
    Loader --> Interpreter
    Interpreter --> FANO
    Interpreter --> PCG
    Core --> FANO
    Core --> PCG
    FANO -.validates.-> Lean
    PCG -.validates.-> Lean
    PCG -.validates.-> Coq

    Interpreter -->|"optional: compile traces"| CLBC
    CLBC --> VM
    Interpreter -->|"projection: pure scene data"| Viz
    LSP -->|"tooling calls (no engine side-effects)"| Viz
```

---

## Data Flow

### Boundary Realization Flow

```
User Input
    │
    ├─> Boundary Object
    │       │
    │       ├─> transform() ──> Transformed Boundary
    │       │
    │       └─> realize(choice) ──> Interior
    │               │
    │               ├─> valid?() ──> Validation Result
    │               │
    │               └─> project() ──> View
    │
    └─> Result
```

### CanvasL Execution Flow

```
JSONL Input
    │
    ├─> Parse Steps
    │       │
    │       ├─> For each step:
    │       │       │
    │       │       ├─> Validate Phase Monotonicity
    │       │       │
    │       │       ├─> Check Forward References
    │       │       │
    │       │       ├─> Execute Operation:
    │       │       │       │
    │       │       │       ├─> define_encoder
    │       │       │       │   └─> Create Encoder Object
    │       │       │       │
    │       │       │       ├─> apply_encoder
    │       │       │       │   └─> Compute: A*x + b
    │       │       │       │
    │       │       │       └─> decode_and_validate
    │       │       │           ├─> Decode
    │       │       │           ├─> FANO Validation
    │       │       │           └─> PCG Validation
    │       │       │
    │       │       └─> Update Environment
    │       │
    │       └─> Final Environment
    │
    └─> Output
```

### Deterministic Bytecode Harness (CLBC)

CLBC provides a deterministic compilation + execution path for golden tests and embedded parity:

```
CanvasL Records (alist/S-expression)
    │
    ├─> CLBC Compiler (src/clbc/compiler.scm)
    │       └─> CLBC Container Bytes (*.clbc)
    │
    └─> Reference VM (src/vm/clbc-vm.scm)
            └─> Transcript Hash + Diagnostics
```

### Visualization as Projection (RFC-VIZ-001 MVP)

Visualization is treated as a **pure projection** (data-only scene graph), not as part of the engine’s state transition logic:

```
Context Parameters (k, globalDecision, includeFano)
    │
    └─> viz-make-scene (src/viz/scene.scm)
            └─> Deterministic Scene Graph (alist)
```

### Tooling boundary: LSP server

The CanvasL LSP server (`apps/lsp/canvasl-lsp.js`) is tooling-only:
- It must not introduce hidden state into the engine.
- It serves deterministic responses for MVP custom methods (`canvasl/getScene`, `canvasl/getTrace`, `canvasl/getIncidence`).

### Validation Flow

```
Decoded Structure
    │
    ├─> FANO Validation
    │       │
    │       ├─> Check 7 Points
    │       ├─> Check 7 Lines
    │       ├─> Check Line Size (3 points each)
    │       └─> Check Pairwise Uniqueness
    │
    ├─> PCG Validation
    │       │
    │       ├─> Generate All Triples
    │       ├─> For each triple:
    │       │       └─> Check Coverage (≥2 points on line)
    │       └─> Verify All Covered
    │
    └─> Validation Result
```

---

## Module Dependencies

### Dependency Graph

```
Level 0 (No Dependencies):
  - core/bicf-core.scm
  - fano/fano-checker.scm
  - consensus/pcg-validator.scm

Level 1 (Depends on Level 0):
  - canvasl/interpreter.scm
    ├─> fano/fano-checker.scm (load)
    └─> consensus/pcg-validator.scm (load)

Level 2 (Depends on Level 0-1):
  - integration/module-loader.scm
    ├─> core/bicf-core.scm
    ├─> fano/fano-checker.scm
    ├─> consensus/pcg-validator.scm
    └─> canvasl/interpreter.scm

Level 3 (Depends on Level 0-2):
  - integration/bicf-system.scm
    └─> integration/module-loader.scm

Level 4 (Depends on Level 0-3):
  - index.scm
    └─> integration/bicf-system.scm
```

### Dependency Details

#### BICF Core
- **Dependencies:** None (foundational)
- **Used By:** All modules
- **Provides:** Types, interfaces, axioms

#### FANO Boundary
- **Dependencies:** None
- **Used By:** CanvasL interpreter
- **Provides:** FANO incidence validation

#### PCG Consensus
- **Dependencies:** None
- **Used By:** CanvasL interpreter
- **Provides:** Pair-cover guarantee validation

#### CanvasL Interpreter
- **Dependencies:** FANO checker, PCG validator
- **Used By:** Integration layer
- **Provides:** JSONL execution, encoder operations

#### Integration Layer
- **Dependencies:** All modules
- **Used By:** Main entry point
- **Provides:** System coordination, CLI

---

## Integration Points

### External Interfaces

#### 1. Command-Line Interface

**Entry Point:** `src/index.scm`

**Commands:**
- `help` - Display help
- `init` - Initialize system
- `register <boundary>` - Register boundary
- `get <boundary-id>` - Get boundary

**Usage:**
```bash
guile -s src/index.scm help
guile -s src/index.scm init
```

#### 2. Scheme API

**Module Loading:**
```scheme
(load "src/integration/bicf-system.scm")
(init-bicf-system)
(register-boundary boundary)
```

**Direct Function Calls:**
```scheme
(load "src/core/bicf-core.scm")
(realize choice boundary)
(valid? interior boundary)
```

#### 3. Docker Interface

**Entry Point:** `scripts/entrypoint.sh`

**Commands:**
- `help` - Show help
- `interpreter <file>` - Run CanvasL interpreter
- `validate` - Validate boundaries
- `test` - Run test suite

**Usage:**
```bash
docker run bicf/production:latest help
docker run bicf/production:latest interpreter trace.jsonl
```

#### 4. JSONL Input Format

**CanvasL JSONL Records:**
```json
{"id": "step-1", "phase": 1, "boundary": "FANO-v1", 
 "op": "apply_encoder", "encoder_ref": "enc:E.local.1",
 "vars": {"x": "ref:state_vector:t1"},
 "inputs": ["enc:E.local.1", "ref:state_vector:t1"],
 "outputs": ["state:encoded:t1"]}
```

### Internal Interfaces

#### Module Loading Interface

**Function:** `load-module name`

**Behavior:**
- Looks up module in registry
- Loads module file
- Raises error if not found

#### Boundary Registry Interface

**Functions:**
- `register-boundary boundary` - Register boundary
- `get-boundary boundary-id` - Retrieve boundary

**Behavior:**
- Global registry (not thread-safe)
- Auto-initialization on first use

#### Validation Interface

**Functions:**
- `check-fano-incidence decoded boundary` - FANO validation
- `check-pcg-pair-cover decoded boundary` - PCG validation

**Behavior:**
- Called from CanvasL interpreter
- Returns `#t` on success, raises error on failure

---

## Formal Verification Integration

### Lean 4 Integration

**File:** `src/lean/fano_pcg.lean`

**Status:** ✅ 100% complete and verified - No `sorry` statements

**Proves:**
- Fano plane incidence axioms
- Pair-cover guarantee theorem
- Two-Fano construction correctness

**Integration:**
- Reference implementation uses same incidence table
- Validation logic matches formal specification
- Proofs provide correctness guarantees

### Coq Integration

**File:** `src/coq/Fano_PCG.v`

**Status:** ✅ 100% complete - No `Admitted` statements ⚠️ Compilation environment-dependent

**Proves:**
- Fano plane uniqueness theorem
- PCG theorem for two Fano planes
- Roundtrip lemmas

**Compilation Note:**
- This repo uses a Dune-based Coq project under `src/coq/`.
- Exact Coq/Dune versions and installed Coq libraries determine whether it compiles cleanly in a given environment.

### Verification Workflow

```
Formal Specification (RFC)
    │
    ├─> Lean 4 Formalization
    │       │
    │       └─> Machine-Verified Proofs
    │
    ├─> Coq Formalization
    │       │
    │       └─> Machine-Verified Proofs
    │
    └─> Reference Implementation
            │
            ├─> Uses Formal Specifications
            ├─> Validates Against Proofs
            └─> Executable Semantics
```

### Proof-to-Implementation Mapping

| Formal Proof | Implementation |
|-------------|----------------|
| `fanoLinePoints` (Lean) | `fano-line-points` (Scheme) |
| `FanoI` (Lean) | `check-fano-incidence` (Scheme) |
| `pcg_two_fano_explicit` (Lean) | `check-pcg-pair-cover` (Scheme) |
| `fano_unique_line` (Coq) | Pairwise uniqueness check (Scheme) |

---

## System State Management

### Global State

The system uses global mutable state:

- `*boundary-registry*` - Boundary registry
- `*initialized*` - Initialization flag
- `*module-registry*` - Module path registry

### State Initialization

1. **Lazy Initialization:** System initializes on first operation
2. **Module Loading:** Modules loaded sequentially
3. **Registry Setup:** Boundaries registered as needed

### State Isolation

- **Environments:** Separate per trace execution
- **Boundary Registry:** Shared across operations
- **Module Registry:** Shared across operations

---

## Error Handling Architecture

### Error Propagation

```
Operation
    │
    ├─> Validation
    │       │
    │       ├─> Type Check ──> Type Error
    │       ├─> Structure Check ──> Structure Error
    │       └─> Semantic Check ──> Validation Error
    │
    └─> Result or Error
```

### Error Types

1. **Type Errors:** Invalid parameter types
2. **Structure Errors:** Missing required fields
3. **Validation Errors:** FANO/PCG validation failures
4. **Not Found Errors:** Missing resources
5. **Execution Errors:** Operation failures

### Error Context

All errors include:
- Error type
- Location information
- Contextual data
- Suggested fixes (where applicable)

---

## Performance Architecture

### Computational Complexity

| Operation | Time Complexity | Space Complexity |
|-----------|----------------|------------------|
| FANO Validation | O(n²) | O(n) |
| PCG Validation | O(n³) | O(n³) |
| Environment Lookup | O(m) | O(m) |
| Trace Execution | O(s) | O(s) |

Where:
- n = number of points (7 for FANO, 14 for PCG)
- m = number of environment bindings
- s = number of execution steps

### Optimization Strategies

1. **Caching:** Cache validation results
2. **Lazy Evaluation:** Generate triples on-demand
3. **Early Exit:** Stop on first validation failure
4. **Parallelization:** Parallel triple checking (future)

---

## Security Architecture

### Input Validation

All inputs validated at boundaries:
- Type checking
- Structure validation
- Semantic validation

### Determinism

- No random number generation
- No external state dependencies
- Reproducible execution

### Error Handling

- No information leakage in errors
- Fail-safe defaults
- Graceful degradation

---

## Deployment Architecture

### Docker Deployment

```
Docker Container
    │
    ├─> Base Image (Ubuntu + Guile)
    │
    ├─> Source Files
    │       ├─> src/
    │       ├─> schemas/
    │       └─> scripts/
    │
    └─> Entry Point
            └─> scripts/entrypoint.sh
```

### CI/CD Integration

```
GitHub Actions / GitLab CI
    │
    ├─> Build Job
    │       ├─> Validate Schemas
    │       ├─> Check Source Files
    │       └─> Run Build Script
    │
    ├─> Test Job
    │       ├─> Unit Tests
    │       ├─> Integration Tests
    │       └─> Formal Verification
    │
    └─> Deploy Job (optional)
            └─> Docker Build & Push
```

---

## Extension Points

### Adding New Boundary Types

1. Create boundary module
2. Implement validation function
3. Register in module loader
4. Add validation hook

### Adding New Operations

1. Extend `exec-step` function
2. Implement operation logic
3. Update documentation

### Adding New Encoder Types

1. Create encoder constructor
2. Add case in `apply_encoder`
3. Implement encoder logic

---

## Demos

Demo index: `demos/README.md`

- ESP-NOW A/B/C (terminal + asciinema): `demos/asciinema/espnow-abc/README.md`
- ESP-NOW “Agreed Policy” (Three.js live + replay): `demos/threejs/espnow-policy-visualizer/README.md`

---

## Related Systems and Research Extensions

The BICF Production System coexists with two related systems in this repository, each serving distinct purposes while sharing foundational principles.

### CAN-ISA MVP

**Location**: `embedded/canisa-mvp/`, documented in `docs/canisa-mvp.md`

**Purpose**: Minimal polynomial VM for embedded devices

**Architecture**:
- Univariate F₂[x] polynomial state representation
- Deterministic canonical state hashing (SHA-256)
- 16 minimal opcodes: STATE_ADD, STATE_GCD, STATE_LCM, STATE_NORM, STATE_HASH, etc.
- .canbc container format (CANBC magic, version, payload)

**Hardware**: ESP32/Pico 2W with MQTT coordination (same targets as BICF)

**Status**: Proof-of-concept, field testing ready

**Relationship to BICF**:
- Uses `src/aal/polynomials.scm` for polynomial operations
- Shares embedded hardware infrastructure
- Complements BICF's production CanvasL execution
- Clean artifact separation (.clbc vs .canbc)

---

### Tetragrammatron-OS

**Location**: `apps/tetragrammatron-os/`

**Purpose**: Formal, RFC-driven geometry-first operating system and VM

**Architecture**:
- 6 normative RFCs defining complete system semantics
- 8-tuple semantic registers (state, symbol, left, right, transition, source, target, result)
- Origami fold semantics with idempotent operations
- 32-bit fixed-width CANB v1 bytecode encoding
- Repository lattice (8³ topology) with Fano merge gate
- Lean formal verification (20 invariants)

**Hardware**: ESP32 UART bridge (extensible to Pico 2W, Android Termux)

**Status**: Research-grade, actively evolving, RFC-driven development

**Relationship to BICF**:
- Shares Fano plane (PG(2,2)) geometric foundations
- Builds on polynomial algebra principles
- Explores proof-carrying bytecode and geometric computation
- Formal evolution of CAN-ISA concepts
- Parallel research track complementing BICF production work

---

### System Comparison Summary

| System | Artifact | VM Core | Maturity | Use Case |
|--------|----------|---------|----------|----------|
| **BICF** | .clbc | Record-stream | Production | CanvasL execution, NRR storage |
| **CAN-ISA MVP** | .canbc | Polynomial F₂[x] | Proof-of-concept | Minimal embedded VM |
| **Tetragrammatron-OS** | .canb | 8-tuple registers | Research | Proof-carrying computation |

For detailed comparison and selection guidance, see:
- [Tetragrammatron-OS and BICF Relationship](../docs/tetragrammatron-bicf-relationship.md)
- [CAN-ISA Evolution](../docs/can-isa-evolution.md)
- [System Selection Guide](../docs/system-selection-guide.md)

---

## References

- RFC-0001: Boundary–Interior Combinatorial Framework
- RFC-0002: FANO Boundary Module (PG(2,2))
- RFC-0003: CanvasL-POLY: A Deterministic Boundary–Interior Computation Standard
- [API Reference](api-reference.md)
- [Implementation Guide](implementation-guide.md)

