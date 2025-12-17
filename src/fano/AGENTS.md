# AGENTS.md
## FANO Boundary - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** RFC-0002 (FANO) Compliant  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** fano-boundary
- **Path:** `src/fano/`
- **Component-ID:** fano-boundary-v1.0.0
- **Layer:** 2 (Core - Deterministic Algorithms)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z
- **RFC Compliance:** RFC-0002 (FANO)

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Implement PG(2,2) Fano plane structure (7 points, 7 lines)
- [x] Enforce incidence axioms (each line has exactly 3 points)
- [x] Validate pairwise uniqueness (any two points lie on exactly one line)
- [x] Support multiple valid realizations (non-canonicity)
- [x] All validation functions must be deterministic
- [x] Complexity must remain O(n²) where n=7 points
- [x] R5RS Scheme compatibility
- [x] Match formal verification (Lean 4, Coq proofs)

### MUST NOT (Prohibitive Constraints)

- [x] Modify Fano plane structure (7 points, 7 lines is fixed)
- [x] Break incidence axioms
- [x] Exceed O(n²) complexity for validation
- [x] Introduce non-deterministic behavior
- [x] Create dependencies on other boundary modules
- [x] Violate formal verification results

---

## Layer-Specific Responsibilities

### Primary Role

FANO Boundary implements the PG(2,2) projective plane structure, providing incidence validation for the Fano plane. It serves as a canonical example of boundary-interior duality in BICF.

### Layer 2 (Core) Invariants

- **Determinism:** All validation functions are deterministic
- **Completeness:** All incidence axioms verified
- **Efficiency:** O(n²) complexity for finite case (n=7)
- **Formal Alignment:** Matches Lean 4 and Coq formalizations

---

## Admissible Operations

### Agents MAY

- **Add helper functions** for Fano plane operations
- **Optimize validation** while maintaining O(n²) complexity
- **Extend structure extraction** for custom point/line encodings
- **Add convenience functions** for common Fano operations
- **Improve error messages** with point/line context

### Execution Examples

```
add helper to find line through two points
optimize pairwise uniqueness check
add function to enumerate all lines
extend extract-fano-structure for custom formats
improve error messages with failing point/line info
```

### Forbidden Operations

```
modify Fano plane structure (7 points, 7 lines is fixed)
break incidence axioms
exceed O(n²) complexity
introduce non-deterministic validation
create dependencies on other modules
violate formal verification results
```

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `check-fano-incidence` | function | stable | Validate FANO structure (decoded × boundary → bool) |
| `extract-fano-structure` | function | stable | Extract FANO structure from decoded data |
| `point-in-line?` | function | stable | Check if point is in line |
| `points-on-same-line?` | function | stable | Check if two points are on same line |
| `fano-line-points` | constant | stable | Standard Fano plane line-point incidence table |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| R5RS Scheme | Standard | Implementation language | No |

**Note:** FANO Boundary has **no dependencies** on other BICF modules. It is self-contained.

### Data Contracts

#### FANO Structure
```json
{
  "type": "object",
  "required": ["points", "lines"],
  "properties": {
    "points": {
      "type": "array",
      "items": {"type": "integer"},
      "minItems": 7,
      "maxItems": 7
    },
    "lines": {
      "type": "array",
      "items": {
        "type": "array",
        "items": {"type": "integer"},
        "minItems": 3,
        "maxItems": 3
      },
      "minItems": 7,
      "maxItems": 7
    }
  }
}
```

---

## Complexity Governance

### Current Metrics

- **Incidence Validation:** O(n²) where n=7 points (exhaustive pairwise checking)
- **Structure Extraction:** O(n) where n=number of points/lines
- **Point-in-Line Check:** O(1) - Simple membership test

### Budget Allocation

- **Maximum Allowed:** O(n²) = O(49) for n=7 (acceptable for finite case)
- **Exhaustive Checking:** Required for finite case validation
- **No Optimization Needed:** Finite case is computationally trivial

### Budget Enforcement

- ✅ O(n²) complexity acceptable for finite case (n=7)
- ❌ Block any changes exceeding O(n²)
- ✅ Exhaustive checking is the correct approach

---

## Verification & Testing

### Required Tests

- [x] **Unit Tests:** FANO validation tests (if present)
- [x] **Formal Verification:** `src/lean/fano_pcg.lean`, `src/coq/Fano_PCG.v`

### Test Coverage

- **Incidence Axioms:** All 7 points, 7 lines validated
- **Line Cardinality:** Each line has exactly 3 points
- **Pairwise Uniqueness:** Any two points on exactly one line
- **Formal Alignment:** Matches Lean 4 and Coq proofs

### Coverage Requirements

- **Line Coverage:** ≥ 90% (validation functions)
- **Branch Coverage:** ≥ 85% (all validation paths)
- **Formal Verification:** 100% (matches formal proofs)

---

## Merge Semantics

### Merge Compatibility

This component MAY be merged IF:

#### Required Conditions

- [x] Fano plane structure unchanged (7 points, 7 lines)
- [x] Incidence axioms preserved
- [x] Complexity remains O(n²)
- [x] Formal verification alignment maintained
- [x] All validation functions deterministic

---

## Change Protocol

### Modifying This Component

1. **Proposal:** Document proposed change in PR
2. **Validation:**
   - Verify Fano plane structure unchanged
   - Run validation tests
   - Verify formal verification alignment
3. **Impact:** Assess effect on:
   - CanvasL interpreter (uses FANO validation)
   - PCG validator (uses FANO structure)
   - Formal verification proofs
4. **Approval:** Get review from maintainers familiar with:
   - RFC-0002 (FANO specification)
   - Formal verification (Lean 4, Coq)
5. **Update:**
   - Modify `fano-checker.scm`
   - Update tests if needed
   - Update `production-docs/api-reference.md`
   - Update this AGENTS.md if constraints change

---

## Normative References

1. **RFC-0002: FANO** - `dev-docs/RFC-BICF-CANVASL-POLY-001/03-fano-plane/RFC-0002-FANO.md`
2. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)
3. **Formal Verification** - `src/lean/fano_pcg.lean`, `src/coq/Fano_PCG.v`

---

## Status & Evolution

This component is:
- ✅ Complete - Fano plane structure implemented
- ✅ Verified - Matches formal proofs
- ✅ Stable - No dependencies, self-contained
- ✅ RFC-compliant - Implements RFC-0002

**Component Status:**
- ✅ Fano plane structure: 7 points, 7 lines
- ✅ Incidence validation: Complete
- ✅ Formal alignment: Matches Lean 4 and Coq

---

*FANO Boundary is a canonical example of boundary-interior duality. It demonstrates the BICF framework with a concrete, formally verified structure.*

