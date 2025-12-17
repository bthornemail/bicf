# AGENTS.md
## Lean 4 Formal Verification - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** Formal Verification Standards  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** lean-formal-verification
- **Path:** `src/lean/`
- **Component-ID:** lean-v1.0.0
- **Layer:** 1 (Mathematical - Formal Verification)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z
- **RFC Compliance:** Formal Verification Standards

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] All theorems must be machine-verifiable
- [x] No `sorry` or `admit` statements
- [x] Proofs must compile and verify successfully
- [x] Formal properties must match reference implementation
- [x] Use Lean 4 Mathlib dependencies

### MUST NOT (Prohibitive Constraints)

- [x] Add `sorry` or `admit` statements
- [x] Break proof compilation
- [x] Violate formal verification status
- [x] Introduce unverified claims

---

## Layer-Specific Responsibilities

### Primary Role

Lean 4 formalization provides machine-verifiable proofs of Fano plane axioms and Pair-Cover Guarantee theorem.

### Layer 1 (Mathematical) Invariants

- **Machine-Verifiability:** All theorems must be machine-verified
- **Completeness:** No `sorry`/`admit` statements
- **Alignment:** Formal properties match reference implementation

---

## Admissible Operations

### Agents MAY

- **Add new theorems** when fully verified
- **Extend proofs** when preserving verification status
- **Improve proof structure** when maintaining correctness
- **Add helper lemmas** when supporting main theorems

### Forbidden Operations

```
add `sorry` or `admit` statements
break proof compilation
introduce unverified claims
violate formal verification status
```

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `fano_pcg.lean` | file | stable | Lean 4 formalization of Fano plane and PCG |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| Lean 4 | Latest | Proof assistant | No |
| Mathlib | Latest | Mathematical library | No |

---

## Verification & Testing

### Required Tests

- [x] **Formal Verification:** `tests/formal/verify-lean.sh`

### Coverage Requirements

- **Proof Verification:** 100% (all proofs must verify)
- **No `sorry`/`admit`:** 100% (no incomplete proofs)

---

## Normative References

1. **Formal Verification** - `production-docs/formal-verification.md`
2. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)

---

## Status & Evolution

This component is:
- ✅ Complete - All proofs verified
- ✅ Verified - No `sorry`/`admit` statements

---

*Lean 4 formalization provides machine-verifiable proofs of core BICF properties, ensuring mathematical correctness.*

