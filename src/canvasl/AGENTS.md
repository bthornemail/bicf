# AGENTS.md
## CanvasL Interpreter - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** RFC-0003 (CanvasL-POLY) Compliant  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** canvasl-interpreter
- **Path:** `src/canvasl/`
- **Component-ID:** canvasl-v1.0.0
- **Layer:** 3 (API - Interface Contracts)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z
- **RFC Compliance:** RFC-0003 (CanvasL-POLY)

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Maintain CanvasL-POLY JSONL format compliance
- [x] Enforce phase monotonicity (sequential processing)
- [x] Prevent forward references
- [x] Integrate FANO and PCG validation
- [x] Support polynomial encoding (A*x + b affine encoders)
- [x] All execution must be deterministic
- [x] Support NRR integration (content-addressed storage)
- [x] R5RS Scheme compatibility

### MUST NOT (Prohibitive Constraints)

- [x] Break JSONL format (must follow `schemas/canvasl-schema.json`)
- [x] Allow phase non-monotonicity
- [x] Allow forward references
- [x] Break deterministic execution
- [x] Remove FANO/PCG validation integration

---

## Layer-Specific Responsibilities

### Primary Role

CanvasL Interpreter executes CanvasL-POLY JSONL traces, providing deterministic boundary-interior computation with polynomial state encoding.

### Layer 3 (API) Invariants

- **Interface Stability:** Public APIs must remain stable
- **Backward Compatibility:** JSONL format changes must be backward compatible
- **Error Handling:** Explicit error handling for all operations

---

## Admissible Operations

### Agents MAY

- **Add new CanvasL operations** when maintaining JSONL format
- **Extend encoder types** when following polynomial encoding model
- **Optimize execution** while preserving determinism
- **Improve error messages** with step/phase context

### Execution Examples

```
add new CanvasL operation maintaining JSONL format
extend encoder types (polynomial, trigonometric, etc.)
optimize environment lookup
improve error messages with phase/step information
```

### Forbidden Operations

```
break JSONL format
allow phase non-monotonicity
allow forward references
break deterministic execution
remove FANO/PCG validation
```

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `exec-step` | function | stable | Execute single CanvasL step |
| `apply-encoder` | function | stable | Apply polynomial encoder (A*x + b) |
| `decode-and-validate` | function | stable | Decode and validate against boundary |
| `execute-canvasl` | function | stable | Execute CanvasL JSONL file |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| R5RS Scheme | Standard | Implementation language | No |
| src/fano/ | Latest | FANO validation | No |
| src/consensus/ | Latest | PCG validation | No |
| src/nrr/ | Latest | NRR integration | No |

---

## Complexity Governance

### Current Metrics

- **Execution:** O(s) where s=number of steps (sequential processing)
- **Environment Lookup:** O(m) where m=number of bindings
- **Validation:** O(n²) for FANO, O(n³) for PCG

### Budget Allocation

- **Execution:** O(s) - Linear in trace size
- **Lookup:** O(m) - Linear in environment size
- **Validation:** Inherited from FANO/PCG modules

---

## Verification & Testing

### Required Tests

- [x] **Integration Tests:** `tests/integration/bicf-integration.test.scm`
- [x] **Schema Validation:** `schemas/canvasl-schema.json`

### Coverage Requirements

- **Line Coverage:** ≥ 80% (interpreter)
- **Branch Coverage:** ≥ 75% (all operation paths)

---

## Normative References

1. **RFC-0003: CanvasL-POLY** - `dev-docs/RFC-BICF-CANVASL-POLY-001/05-canvasl-poly/RFC-0003-CanvasL-POLY.md`
2. **CanvasL Schema** - `schemas/canvasl-schema.json`
3. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)

---

## Status & Evolution

This component is:
- ✅ Complete - CanvasL-POLY interpreter implemented
- ✅ Tested - Integration tests complete
- ✅ RFC-compliant - Implements RFC-0003

---

*CanvasL Interpreter provides deterministic execution of boundary-interior computation traces with polynomial state encoding.*

