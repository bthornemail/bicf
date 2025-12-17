# AGENTS.md
## PCG Consensus - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** RFC-0002 (FANO), RFC-0005 (PCG) Compliant  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** pcg-consensus
- **Path:** `src/consensus/`
- **Component-ID:** pcg-consensus-v1.0.0
- **Layer:** 2 (Core - Deterministic Algorithms)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z
- **RFC Compliance:** RFC-0002 (FANO), RFC-0005 (PCG)

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Implement Pair-Cover Guarantee (PCG) validation
- [x] Validate all triples have ≥2 points on a common line
- [x] Support two-Fano construction (14 points, 14 lines)
- [x] All validation functions must be deterministic
- [x] Complexity must remain O(n³) where n=14 points
- [x] R5RS Scheme compatibility
- [x] Match formal verification (Lean 4, Coq proofs)

### MUST NOT (Prohibitive Constraints)

- [x] Break PCG theorem (all triples must be covered)
- [x] Exceed O(n³) complexity for validation
- [x] Introduce non-deterministic behavior
- [x] Create dependencies on other boundary modules
- [x] Violate formal verification results

---

## Layer-Specific Responsibilities

### Primary Role

PCG Consensus implements deterministic merge verification using the Pair-Cover Guarantee. It provides conflict detection and consensus formation without probabilistic mechanisms.

### Layer 2 (Core) Invariants

- **Determinism:** All validation functions are deterministic
- **Completeness:** All triples verified for coverage
- **Efficiency:** O(n³) complexity for finite case (n=14)
- **Formal Alignment:** Matches Lean 4 and Coq formalizations

---

## Admissible Operations

### Agents MAY

- **Add helper functions** for triple generation
- **Optimize validation** while maintaining O(n³) complexity
- **Extend structure extraction** for custom universe/line encodings
- **Add convenience functions** for merge decision logic
- **Improve error messages** with triple context

### Execution Examples

```
optimize triple generation algorithm
add helper to find covering line for triple
extend extract-pcg-structure for custom formats
improve error messages with failing triple info
add merge decision helper functions
```

### Forbidden Operations

```
break PCG theorem (all triples must be covered)
exceed O(n³) complexity
introduce non-deterministic validation
create dependencies on other modules
violate formal verification results
modify two-Fano construction
```

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `check-pcg-pair-cover` | function | stable | Validate PCG (decoded × boundary → bool) |
| `generate-triples` | function | stable | Generate all triples for PCG checking |
| `extract-pcg-structure` | function | stable | Extract PCG structure from decoded data |
| `triple-covered?` | function | stable | Check if triple is covered by lines |
| `count-triple-in-line` | function | stable | Count points of triple in line |
| `point-in-line?` | function | stable | Check if point is in line |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| R5RS Scheme | Standard | Implementation language | No |

**Note:** PCG Consensus has **no dependencies** on other BICF modules. It uses FANO structure but doesn't depend on FANO module.

### Data Contracts

#### PCG Structure
```json
{
  "type": "object",
  "required": ["universe", "lines"],
  "properties": {
    "universe": {
      "type": "array",
      "items": {"type": "integer"},
      "minItems": 14,
      "maxItems": 14
    },
    "lines": {
      "type": "array",
      "items": {
        "type": "array",
        "items": {"type": "integer"},
        "minItems": 3,
        "maxItems": 3
      },
      "minItems": 14,
      "maxItems": 14
    }
  }
}
```

---

## Complexity Governance

### Current Metrics

- **PCG Validation:** O(n³) where n=14 points (all triples generated and checked)
- **Triple Generation:** O(n³) - Generate all C(n,3) triples
- **Coverage Check:** O(m) where m=number of lines (per triple)

### Budget Allocation

- **Maximum Allowed:** O(n³) = O(2744) for n=14 (acceptable for finite case)
- **Exhaustive Checking:** Required for finite case validation
- **No Optimization Needed:** Finite case is computationally acceptable

### Budget Enforcement

- ✅ O(n³) complexity acceptable for finite case (n=14)
- ❌ Block any changes exceeding O(n³)
- ✅ Exhaustive checking is the correct approach

---

## Verification & Testing

### Required Tests

- [x] **Unit Tests:** PCG validation tests (if present)
- [x] **Formal Verification:** `src/lean/fano_pcg.lean`, `src/coq/Fano_PCG.v`

### Test Coverage

- **PCG Theorem:** All triples verified for coverage
- **Two-Fano Construction:** 14 points, 14 lines validated
- **Triple Generation:** All C(14,3) = 364 triples generated
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

- [x] PCG theorem preserved (all triples covered)
- [x] Two-Fano construction unchanged
- [x] Complexity remains O(n³)
- [x] Formal verification alignment maintained
- [x] All validation functions deterministic

---

## Change Protocol

### Modifying This Component

1. **Proposal:** Document proposed change in PR
2. **Validation:**
   - Verify PCG theorem preserved
   - Run validation tests
   - Verify formal verification alignment
3. **Impact:** Assess effect on:
   - CanvasL interpreter (uses PCG validation)
   - Merge semantics (depends on PCG)
   - Formal verification proofs
4. **Approval:** Get review from maintainers familiar with:
   - RFC-0005 (PCG specification)
   - Formal verification (Lean 4, Coq)
5. **Update:**
   - Modify `pcg-validator.scm`
   - Update tests if needed
   - Update `production-docs/api-reference.md`
   - Update this AGENTS.md if constraints change

---

## Normative References

1. **RFC-0002: FANO** - `dev-docs/RFC-BICF-CANVASL-POLY-001/03-fano-plane/RFC-0002-FANO.md`
2. **RFC-0005: PCG** - PCG-based deterministic consensus
3. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)
4. **Formal Verification** - `src/lean/fano_pcg.lean`, `src/coq/Fano_PCG.v`

---

## Status & Evolution

This component is:
- ✅ Complete - PCG validation implemented
- ✅ Verified - Matches formal proofs
- ✅ Stable - No dependencies, self-contained
- ✅ RFC-compliant - Implements PCG specification

**Component Status:**
- ✅ PCG validation: Complete
- ✅ Two-Fano construction: 14 points, 14 lines
- ✅ Formal alignment: Matches Lean 4 and Coq

---

*PCG Consensus provides deterministic merge verification without probabilistic mechanisms. It demonstrates how combinatorial guarantees enable distributed consensus.*

