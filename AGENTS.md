# AGENTS.md
## BICF Production System - Repository Boundary Contract

**Version:** 3.0.0  
**Status:** Repository-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** RFC-BICF-CANVASL-POLY-001 Compliant  
**Repository:** bicf-production

---

## Component Identity

- **Name:** bicf-production-system
- **Path:** `/` (repository root)
- **Component-ID:** bicf-production-v3.0.0
- **Layer:** Mixed (components span Layers 1-8)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z
- **RFC Compliance:** RFC-BICF-CANVASL-POLY-001, RFC-0001 (BICF Core), RFC-0002 (FANO), RFC-0003 (CanvasL-POLY)

---

## Repository Abstraction

The BICF Production System uses a **Native Repository Runtime (NRR)** as its minimal repository abstraction. CanvasL-POLY does **not depend on Git**; Git is treated as an optional reference implementation.

### NRR Minimal Interface

NRR provides a minimal, portable repository abstraction suitable for embedded systems, microcontrollers, and resource-constrained environments:

```text
Repository :=
  {
    put(content) -> ref      # Store content, return content-addressed reference
    get(ref) -> content      # Retrieve content by reference
    append(entry)            # Append entry to append-only log
    log() -> [entry₀ … entryₙ]  # Retrieve all log entries
  }
```

### Key Properties

- **Content-Addressed Storage:** References are computed from content hashes (SHA-256, BLAKE3, or CRC32)
- **Append-Only Log:** Deterministic replay from log entries
- **Binary-Safe:** Works with binary data, suitable for MCUs
- **MCU-Friendly:** No heap required, suitable for ESP32 and embedded Linux
- **Git-Compatible:** Optional Git adapter provides transport/replication layer

### Git Relationship

Git is **optional** and serves as:
- A **transport** mechanism (optional)
- A **replication layer** (optional)
- A **human UI** (optional)

The system works **without Git** using NRR's minimal interface. Git adapters can be implemented as thin layers mapping NRR operations to Git commands.

**Reference:** `dev-docs/Native Repository Runtime.md`

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Preserve boundary-interior duality (BICF Axiom 1)
- [x] Maintain explicit realization (no implicit state) (BICF Axiom 4)
- [x] Enforce non-canonicity (multiple valid realizations per boundary) (BICF Axiom 2)
- [x] Preserve deterministic validation (all operations deterministic and replayable)
- [x] Keep dependencies explicit (R5RS Scheme, Lean 4, Coq)
- [x] Pass all verification checks (unit, integration, formal)
- [x] Maintain CanvasL-POLY execution semantics (JSONL format, phase monotonicity)
- [x] Preserve polynomial algebra semantics in AAL modules (F₂[x] operations)
- [x] Respect complexity budgets (FANO O(n²), PCG O(n³), CanvasL O(s))
- [x] Work with NRR (content-addressed storage + append-only log)
- [x] Support deterministic replay from NRR log entries

### MUST NOT (Prohibitive Constraints)

- [x] Introduce implicit state or hidden transitions
- [x] Violate BICF axioms (RFC-0001)
- [x] Break deterministic guarantees
- [x] Create hidden dependencies (all dependencies must be explicit)
- [x] Bypass declared interfaces (BICF Core, FANO, PCG, CanvasL, AAL)
- [x] Exceed IO permissions (read-only for most operations)
- [x] Modify BICF axioms without RFC update
- [x] Introduce non-R5RS Scheme dependencies
- [x] Violate CanvasL-POLY JSONL format
- [x] Break formal verification status (Lean 4, Coq proofs must remain verified)
- [x] Require Git as a dependency (Git is optional, NRR is the abstraction)
- [x] Break NRR interface compatibility (must support put, get, append, log)

---

## Layer-Specific Responsibilities

### Primary Role

The BICF Production System implements a formally verified distributed computation framework based on boundary-interior duality, providing deterministic consensus without probabilistic mechanisms.

### Layer Assignments

#### Layer 1 (Mathematical) - Formal Verification
- **Components:** `src/lean/`, `src/coq/`
- **Responsibilities:**
  - Machine-verifiable proofs of Fano plane axioms
  - PCG (Pair-Cover Guarantee) theorem proofs
  - AAL graded modal type system soundness proofs
- **Invariants:**
  - All theorems must be machine-verifiable (no `sorry`/`admit`)
  - Proofs must compile and verify successfully
  - Formal properties must match reference implementation

#### Layer 2 (Core) - Deterministic Algorithms
- **Components:** `src/core/`, `src/aal/`, `src/nrr/` (Native Repository Runtime)
- **Responsibilities:**
  - BICF Core implementation (5 axioms)
  - AAL compiler/interpreter (polynomial algebra, type system, semantics)
  - Deterministic validation algorithms
  - NRR implementation (content-addressed storage, append-only log)
- **Invariants:**
  - All functions must be deterministic
  - No random number generation
  - Reproducible execution from logs
  - NRR must be binary-safe and MCU-friendly
  - Repository operations must support deterministic replay

#### Layer 3 (API) - Interface Contracts
- **Components:** `src/canvasl/`, `src/integration/`
- **Responsibilities:**
  - CanvasL JSONL interpreter
  - BICF system coordination APIs
  - Module loading interfaces
- **Invariants:**
  - Interface contracts must be stable
  - Backward compatibility for public APIs
  - Explicit error handling

#### Layer 4 (Services) - System Coordination
- **Components:** `src/integration/bicf-system.scm`
- **Responsibilities:**
  - System initialization and coordination
  - Boundary registry management
  - Module lifecycle management
- **Invariants:**
  - Business logic must be testable
  - State management must be explicit

#### Layer 5 (Data) - Explicit Schemas
- **Components:** `schemas/canvasl-schema.json`
- **Responsibilities:**
  - CanvasL JSONL schema definition
  - Data validation schemas
- **Invariants:**
  - Schemas must be explicit and machine-validatable
  - Schema changes must maintain backward compatibility

#### Layer 7 (Tests) - Measurable Coverage
- **Components:** `tests/unit/`, `tests/aal/`, `tests/integration/`, `tests/formal/`
- **Responsibilities:**
  - Unit tests for all modules
  - Integration tests for end-to-end workflows
  - Formal verification scripts (Lean 4, Coq)
- **Invariants:**
  - Coverage must be measurable
  - All tests must pass before merge

#### Layer 8 (Documentation) - Verifiable Accuracy
- **Components:** `production-docs/`, `dev-docs/`
- **Responsibilities:**
  - API reference documentation
  - Architecture documentation
  - RFC specifications
- **Invariants:**
  - Accuracy must be verifiable against code
  - Documentation must match implementation

---

## Admissible Operations

### Agents MAY

- **Refactor AAL modules** when preserving polynomial algebra semantics (F₂[x] operations)
- **Add boundary modules** following FANO pattern (7 points, 7 lines, incidence validation)
- **Extend CanvasL operations** when maintaining JSONL format and phase monotonicity
- **Update formal proofs** when preserving verification status (no `sorry`/`admit`)
- **Add tests** with coverage meeting minimum thresholds
- **Update documentation** to match code changes
- **Optimize algorithms** within declared complexity budgets
- **Extend AAL type system** when preserving graded modal structure (D0-D10)
- **Add new encoder types** to CanvasL when following polynomial encoding model

### Execution Examples

```
refactor AAL polynomial operations while preserving F₂[x] semantics
add FANO boundary module with 7 points, 7 lines structure
extend CanvasL interpreter with new operation maintaining JSONL format
update Lean 4 proofs preserving verification status
add integration tests for new boundary modules
optimize PCG validation within O(n³) budget
```

### Forbidden Operations

```
modify BICF axioms without RFC update (RFC-0001)
break deterministic guarantees (all operations must be replayable)
introduce non-R5RS Scheme dependencies
violate CanvasL-POLY execution semantics
add `sorry` or `admit` to formal proofs
exceed declared complexity limits (FANO O(n²), PCG O(n³))
introduce implicit state or hidden transitions
bypass boundary-interior duality (BICF Axiom 1)
```

---

## Formal Properties

### Formal Systems

- [x] **Lean 4** - `src/lean/fano_pcg.lean`
- [x] **Coq** - `src/coq/Fano_PCG.v`
- [x] **AAL** - Graded modal type system (D0-D10) with soundness proofs

### Proven Invariants

1. **Theorem:** Fano Plane Incidence Axioms
   - **Statement:** Exactly 7 points, 7 lines, each line contains exactly 3 points, any two points lie on exactly one line
   - **Proof:** `src/lean/fano_pcg.lean` (Fano structure, line_through_unique, line_card_three)
   - **Status:** ✅ verified (using `native_decide`)

2. **Theorem:** Pair-Cover Guarantee (PCG)
   - **Statement:** For two disjoint Fano planes over 14 elements, any triple has ≥2 points on a common line
   - **Proof:** `src/lean/fano_pcg.lean` (pcg_two_fano_explicit), `src/coq/Fano_PCG.v` (pcg_theorem)
   - **Status:** ✅ verified

3. **Theorem:** Fano Plane Uniqueness
   - **Statement:** Fano plane structure is unique up to isomorphism
   - **Proof:** `src/coq/Fano_PCG.v` (fano_unique_line)
   - **Status:** ✅ verified

4. **Property:** AAL Type System Soundness
   - **Type:** Safety property
   - **Verification:** AAL v3.2 specification (127 lemmas, 42 theorems verified in Coq)
   - **Scope:** AAL compiler/interpreter (`src/aal/`)
   - **Status:** ✅ verified (documented in `dev-docs/Assembly–Algebra Language v3.2/`)

5. **Property:** Deterministic Execution
   - **Type:** Liveness property
   - **Verification:** Reference implementation (`src/canvasl/interpreter.scm`)
   - **Scope:** CanvasL interpreter
   - **Status:** ✅ verified (deterministic replay from JSONL logs)

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `boundary?` | function | stable | Type predicate for Boundary objects |
| `interior?` | function | stable | Type predicate for Interior objects |
| `valid?` | function | stable | Validity predicate (Interior × Boundary → Bool) |
| `realize` | function | stable | Realization function (Boundary × Choice → Interior) |
| `transform` | function | stable | Boundary transformation (Boundary → Boundary) |
| `project` | function | stable | Interior projection (Interior → View) |
| `check-fano-incidence` | function | stable | FANO boundary validation (decoded × boundary → bool) |
| `extract-fano-structure` | function | stable | Extract FANO structure from decoded data |
| `check-pcg-pair-cover` | function | stable | PCG validation (decoded × boundary → bool) |
| `generate-triples` | function | stable | Generate all triples for PCG checking |
| `exec-step` | function | stable | Execute single CanvasL step |
| `apply-encoder` | function | stable | Apply polynomial encoder (A*x + b) |
| `decode-and-validate` | function | stable | Decode and validate against boundary |
| `parse-aal` | function | stable | Parse AAL program from string |
| `compile-aal` | function | stable | Compile AAL program (parse → well-formed → type-check → code-gen) |
| `interpret-aal` | function | stable | Direct AAL execution with debugging |
| `nrr-put` | function | stable | Store content and return content-addressed reference |
| `nrr-get` | function | stable | Retrieve content by reference |
| `nrr-append` | function | stable | Append entry to append-only log |
| `nrr-log` | function | stable | Retrieve all log entries for deterministic replay |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| R5RS Scheme | Standard | Reference implementation language | No |
| Guile | ≥3.0 | Scheme interpreter for execution | No |
| Lean 4 | Latest | Formal verification (Fano, PCG) | No |
| Coq | ≥8.15 | Formal verification (Fano, PCG) | No |
| JSON Schema | Draft 2020-12 | CanvasL JSONL validation | No |
| Git | Any | Optional transport/replication layer (NRR adapter) | Yes |
| NRR | Native | Content-addressed storage + append-only log | No |

### Data Contracts

#### BICF Core Interface
```json
{
  "input_schema": {
    "boundary": {"type": "object", "required": ["id"]},
    "interior": {"type": "object", "required": ["boundary-ref"]},
    "choice": {"type": "object", "required": ["choice-id"]}
  },
  "output_schema": {
    "valid": {"type": "boolean"},
    "interior": {"type": "object"},
    "boundary": {"type": "object"}
  },
  "error_cases": [
    "invalid-boundary",
    "invalid-interior",
    "boundary-mismatch",
    "realization-failure"
  ]
}
```

#### CanvasL JSONL Format
```json
{
  "input_schema": {
    "$ref": "schemas/canvasl-schema.json"
  },
  "output_schema": {
    "environment": {"type": "object"},
    "final_state": {"type": "object"}
  },
  "error_cases": [
    "phase-monotonicity-violation",
    "forward-reference",
    "boundary-validation-failure",
    "pcg-validation-failure"
  ]
}
```

---

## Complexity Governance

### Current Metrics

- **FANO Validation:** O(n²) where n=7 points (exhaustive pairwise checking)
- **PCG Validation:** O(n³) where n=14 points (all triples generated and checked)
- **CanvasL Execution:** O(s) where s=number of steps (sequential processing)
- **AAL Compilation:** O(p) where p=program size (single-pass parser, type checker)
- **Environment Lookup:** O(m) where m=number of bindings (association list)

### Budget Allocation

- **FANO Validation:** Maximum O(n²) = O(49) for n=7 (acceptable for finite case)
- **PCG Validation:** Maximum O(n³) = O(2744) for n=14 (acceptable for finite case)
- **CanvasL Execution:** Linear in trace size (no budget limit, but must be deterministic)
- **AAL Compilation:** Linear in program size (no budget limit)

### Budget Enforcement

- ❌ Block commits exceeding complexity budgets
- ⚠️ Warn if approaching O(n⁴) or higher complexity
- ✅ Allow optimizations reducing complexity
- ✅ Exhaustive checking acceptable for finite cases (FANO, PCG)

---

## Verification & Testing

### Required Tests

- [x] **Unit Tests:** `tests/unit/core.test.scm` - BICF Core axiom tests
- [x] **AAL Tests:** `tests/aal/` - Parser, type system, semantics, geometry tests
- [x] **Integration Tests:** `tests/integration/bicf-integration.test.scm` - End-to-end workflows
- [x] **Formal Verification:** `tests/formal/verify-lean.sh`, `tests/formal/verify-coq.sh` - Proof compilation

### Test Locations

```
tests/
├── unit/
│   └── core.test.scm          # BICF Core tests
├── aal/
│   ├── parser.test.scm        # AAL parser tests
│   ├── types.test.scm         # Type system tests
│   ├── semantics.test.scm     # Semantics tests
│   ├── polynomials.test.scm   # Polynomial algebra tests
│   ├── geometry.test.scm      # D9 Fano Plane mapping tests
│   └── integration.test.scm   # AAL end-to-end tests
├── integration/
│   └── bicf-integration.test.scm  # System integration tests
└── formal/
    ├── verify-lean.sh         # Lean 4 proof verification
    └── verify-coq.sh          # Coq proof verification
```

### Coverage Requirements

- **Line Coverage:** ≥ 80% for core modules
- **Branch Coverage:** ≥ 75% for validation functions
- **Formal Verification:** 100% (all proofs must verify, no `sorry`/`admit`)

### Continuous Validation

- [x] Pre-commit hooks validate AGENTS.md structure
- [x] CI runs all unit and integration tests
- [x] CI runs formal verification scripts (`verify-lean.sh`, `verify-coq.sh`)
- [x] Nightly runs check boundary integrity and proof compilation

---

## CanvasL Integration

### Boundary Definition

```json
{
  "type": "boundary",
  "id": "bicf-production-repository",
  "scope": "/",
  "layer": "mixed",
  "constraints": "boundary-interior-duality,explicit-realization,non-canonicity,determinism",
  "created": "2024-12-19T00:00:00Z",
  "rfc_compliance": ["RFC-BICF-CANVASL-POLY-001", "RFC-0001", "RFC-0002", "RFC-0003"],
  "anchor": "nrr:sha256:abc123...",
  "repository": "nrr"
}
```

**Note:** The `anchor` field uses NRR content-addressed references (hash-based). Git commit hashes can be used as an optional transport layer, but NRR references are the canonical form.

### Execution Semantics

- **Phase:** Repository-level (phase 0 for structure, phase 1+ for operations)
- **Dependencies:** 
  - BICF Core → FANO, PCG
  - CanvasL Interpreter → FANO, PCG
  - Integration Layer → All modules
- **Preconditions:**
  - All formal proofs must verify
  - All tests must pass
  - Schema validation must succeed
- **Postconditions:**
  - Boundary-interior duality preserved
  - Deterministic execution maintained
  - Formal verification status unchanged

### Projection Mappings

| CanvasL Field | AGENTS.md Section | Export Format |
|---------------|-------------------|---------------|
| `boundary.id` | Component Identity | JSON, JSON-LD |
| `boundary.constraints` | Boundary Constraints | RDF/Turtle |
| `boundary.interfaces` | Interface Specifications | OpenAPI |
| `boundary.verification` | Verification & Testing | JUnit XML |
| `boundary.formal_properties` | Formal Properties | Lean 4, Coq |

### CanvasL-POLY Compliance

- **JSONL Format:** All CanvasL execution follows `schemas/canvasl-schema.json`
- **Phase Monotonicity:** Steps must be processed sequentially by phase
- **Forward References:** Prevented (no references to future steps)
- **Polynomial Encoding:** State evolution via `A*x + b` affine encoders
- **Boundary Validation:** FANO and PCG validation integrated into execution
- **NRR Integration:** CanvasL log entries map to NRR log entries
- **Content Addressing:** Boundary anchors use NRR content-addressed references (hash-based)
- **Deterministic Replay:** CanvasL execution uses NRR's `log()` for replay from append-only log

---

## Merge Semantics

### Merge Compatibility

This repository MAY be merged IF:

#### Required Conditions

- [x] Boundary hash matches expected value (or updated with justification)
- [x] All tests pass (unit, integration, AAL)
- [x] No AGENTS.md constraint is violated
- [x] Complexity budget is respected
- [x] Dependencies remain compatible (R5RS, Lean 4, Coq)
- [x] Formal proofs verify (no `sorry`/`admit` introduced)
- [x] CanvasL-POLY execution semantics preserved
- [x] BICF axioms remain intact

#### Conflict Resolution

**If boundary has diverged:**
1. Regenerate AGENTS.md from current state
2. Validate against repository constraints (BICF axioms, RFC compliance)
3. Update boundary hash
4. Re-run all verifications (tests, formal proofs)
5. Update documentation if interfaces changed

**If constraints conflict:**
1. Escalate to repository maintainer
2. Assess impact on BICF axioms and RFC compliance
3. Adjust boundary definition if needed (may require RFC update)
4. Update dependent components
5. Log resolution in commit message with BICF justification

**If formal proofs fail:**
1. Identify introduced `sorry`/`admit` statements
2. Complete proofs or revert changes
3. Verify all proofs compile and verify
4. Update formal verification documentation

### Merge Safety Guarantees

- ✅ Deterministic merge validation (all checks are reproducible)
- ✅ No hidden state introduction (explicit realization enforced)
- ✅ Backward compatibility check (public APIs must remain stable)
- ✅ Forward compatibility assessment (schema changes must be backward compatible)
- ✅ BICF axiom preservation (boundary-interior duality maintained)
- ✅ Formal verification preservation (proofs must remain verified)

---

## Change Protocol

### Modifying This File

1. **Proposal:** Document proposed change in PR description
2. **Validation:** 
   - Run `./scripts/test.sh` to verify all tests pass
   - Run `./tests/formal/verify-lean.sh` and `./tests/formal/verify-coq.sh`
   - Validate against `schemas/canvasl-schema.json` if CanvasL changes
3. **Impact:** Assess affected components:
   - BICF Core changes → may affect all modules
   - FANO/PCG changes → may affect CanvasL interpreter
   - AAL changes → may affect compiler/interpreter
   - Schema changes → may affect CanvasL execution
4. **Approval:** Get review from maintainers familiar with:
   - BICF principles (boundary-interior duality)
   - RFC-BICF-CANVASL-POLY-001 specification
   - Formal verification (Lean 4, Coq)
5. **Update:** 
   - Modify file and regenerate boundary hash
   - Update relevant sections (interfaces, complexity, formal properties)
   - Update `Last Validated` timestamp
6. **Verification:** 
   - Confirm all tests pass
   - Verify formal proofs compile
   - Check documentation accuracy

### Versioning Rules

- **MAJOR:** Breaking boundary changes (BICF axiom modifications, RFC updates)
- **MINOR:** New admissible operations (new boundary modules, CanvasL operations)
- **PATCH:** Clarifications, fixes, documentation updates

### Audit Trail

All changes MUST be:

- **Appended to NRR log** with content-addressed reference (for boundary integrity)
- **Linked to CanvasL execution phase** (if applicable)
- **Documented in NRR log entry** with BICF justification
- **Validated pre-merge** (tests, formal proofs, schema validation)
- **Referenced in RFC updates** (if BICF axioms or interfaces change)
- **Boundary hash computed from content** (NRR-style content addressing)

**Note:** Git commits are optional. The canonical audit trail is the NRR append-only log. Git can serve as an optional transport/replication layer, but NRR log entries are the source of truth.

### Repository-Specific Change Process

#### For BICF Core Changes
1. Update `src/core/bicf-core.scm`
2. Update RFC documents in `dev-docs/RFC-BICF-CANVASL-POLY-001/02-bicf-specification/`
3. Run `tests/unit/core.test.scm`
4. Update `production-docs/api-reference.md`
5. Update AGENTS.md interfaces section

#### For AAL Changes
1. Update `src/aal/` modules
2. Run `tests/aal/` test suite
3. Verify AAL specification in `dev-docs/Assembly–Algebra Language v3.2/`
4. Update `production-docs/api-reference.md` if interfaces change
5. Update AGENTS.md interfaces and complexity sections

#### For CanvasL Changes
1. Update `src/canvasl/interpreter.scm`
2. Update `schemas/canvasl-schema.json` if format changes
3. Run `tests/integration/bicf-integration.test.scm`
4. Verify against RFC-0003 (CanvasL-POLY)
5. Update `production-docs/api-reference.md`
6. Update AGENTS.md CanvasL Integration section

#### For Formal Proof Changes
1. Update `src/lean/fano_pcg.lean` or `src/coq/Fano_PCG.v`
2. Verify no `sorry`/`admit` statements introduced
3. Run `tests/formal/verify-lean.sh` or `tests/formal/verify-coq.sh`
4. Update `production-docs/formal-verification.md`
5. Update AGENTS.md Formal Properties section

---

## Normative References

1. **RFC-BICF-CANVASL-POLY-001** - Base standard (`dev-docs/RFC-BICF-CANVASL-POLY-001/`)
2. **RFC-0001: BICF Core** - Boundary–Interior Combinatorial Framework (`dev-docs/RFC-BICF-CANVASL-POLY-001/02-bicf-specification/RFC-0001-BICF-Core.md`)
3. **RFC-0002: FANO** - Fano Plane Boundary Module (`dev-docs/RFC-BICF-CANVASL-POLY-001/03-fano-plane/RFC-0002-FANO.md`)
4. **RFC-0003: CanvasL-POLY** - Deterministic Boundary–Interior Computation Standard (`dev-docs/RFC-BICF-CANVASL-POLY-001/05-canvasl-poly/RFC-0003-CanvasL-POLY.md`)
5. **CanvasL JSONL Schema** - `schemas/canvasl-schema.json`
6. **AAL v3.2 Specification** - `dev-docs/Assembly–Algebra Language v3.2/`
7. **Native Repository Runtime (NRR)** - `dev-docs/Native Repository Runtime.md` - Minimal repository abstraction (content-addressed storage + append-only log)
8. **Universal Layer Model** - Component classification (this document)
9. **Production Documentation** - `production-docs/` (architecture, API reference, implementation guide)

---

## Status & Evolution

This boundary contract is:
- ✅ Repository-specific (not a generic template)
- ✅ BICF-aligned (boundary-interior duality, explicit realization, non-canonicity)
- ✅ Formally grounded (Lean 4, Coq, AAL proofs referenced)
- ✅ Practically validated (actual components, interfaces, complexity metrics)
- ✅ RFC-compliant (RFC-BICF-CANVASL-POLY-001 aligned)

**Component Status:**
- ✅ BICF Core: Complete and verified
- ✅ FANO Boundary: Complete and verified
- ✅ PCG Consensus: Complete and verified
- ✅ CanvasL Interpreter: Complete and verified
- ✅ AAL Implementation: Complete (Phase 1-2), integration planned
- ✅ Formal Verification: Complete (Lean 4, Coq proofs verified)
- ✅ NRR: Native Repository Runtime specification complete

**Deployment Targets:**
- ✅ **Desktop/Linux:** Full R5RS Scheme implementation
- ✅ **Embedded Systems:** NRR enables ESP32, WASM, and microcontroller deployment
- ✅ **MCU-Friendly:** Binary-safe, constant memory (polynomial state encoding)
- ✅ **Git-Optional:** System works without Git; Git serves as optional transport layer
- ✅ **Docker Compose Development Environment:** Complete Docker Compose setup (`docker-compose.dev.yml`) with 7 services for Coq+Dune compilation, Lean 4 verification, E2E testing, and demo modeling (Three.js visualizer, asciinema recorder)

**Next steps:**
1. Complete AAL-BICF integration (Phase 3)
2. Add additional boundary modules following FANO pattern
3. Extend CanvasL operations while maintaining JSONL format
4. Enhance formal verification coverage
5. Implement NRR for embedded targets (ESP32, WASM)
6. ✅ **Docker Infrastructure:** Complete - Development environment with Coq+Dune, Lean 4, E2E testing, and demo services

---

*AGENTS.md transforms documentation into execution contracts. For the BICF Production System, it enforces boundary-interior duality, explicit realization, and deterministic validation—the core principles that make distributed computation verifiable and replayable.*
