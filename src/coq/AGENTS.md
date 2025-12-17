# AGENTS.md
## Coq Formal Verification - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** Formal Verification Standards  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** coq-formal-verification
- **Path:** `src/coq/`
- **Component-ID:** coq-v1.0.0
- **Layer:** 1 (Mathematical - Formal Verification)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z
- **RFC Compliance:** Formal Verification Standards

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] All theorems must be machine-verifiable
- [x] No `Admitted` statements
- [x] Proofs must compile and verify successfully
- [x] Formal properties must match reference implementation
- [x] Use Coq standard library

### MUST NOT (Prohibitive Constraints)

- [x] Add `Admitted` statements
- [x] Break proof compilation
- [x] Violate formal verification status
- [x] Introduce unverified claims

---

## Layer-Specific Responsibilities

### Primary Role

Coq formalization provides machine-verifiable proofs of Fano plane uniqueness and Pair-Cover Guarantee theorem.

### Layer 1 (Mathematical) Invariants

- **Machine-Verifiability:** All theorems must be machine-verified
- **Completeness:** No `Admitted` statements
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
add `Admitted` statements
break proof compilation
introduce unverified claims
violate formal verification status
```

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `Fano_PCG.v` | file | stable | Coq formalization of Fano plane and PCG |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| Coq | ≥8.15 | Proof assistant | No |

---

## Verification & Testing

### Required Tests

- [x] **Formal Verification:** `tests/formal/verify-coq.sh`

### Coverage Requirements

- **Proof Verification:** 100% (all proofs must verify)
- **No `Admitted`:** 100% (no incomplete proofs)

---

## Normative References

1. **Formal Verification** - `production-docs/formal-verification.md`
2. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)

---

## Status & Evolution

This component is:
- ✅ Complete - All proofs verified
- ✅ Verified - No `Admitted` statements

---

*Coq formalization provides machine-verifiable proofs of core BICF properties, ensuring mathematical correctness.*

