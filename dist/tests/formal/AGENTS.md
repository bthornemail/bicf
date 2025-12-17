# AGENTS.md
## Formal Verification Tests - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** Formal Verification Standards  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** formal-verification-tests
- **Path:** `tests/formal/`
- **Component-ID:** formal-tests-v1.0.0
- **Layer:** 7 (Tests - Measurable Coverage)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Verify Lean 4 proofs compile and verify
- [x] Verify Coq proofs compile and verify
- [x] Ensure no `sorry`/`admit` statements
- [x] All verification scripts must be deterministic

### MUST NOT (Prohibitive Constraints)

- [x] Skip proof verification
- [x] Allow `sorry`/`admit` statements
- [x] Break proof compilation

---

## Layer-Specific Responsibilities

### Primary Role

Formal verification tests ensure that all formal proofs (Lean 4, Coq) compile and verify successfully, maintaining mathematical correctness.

### Layer 7 (Tests) Invariants

- **Completeness:** All proofs must verify
- **No Incomplete Proofs:** No `sorry`/`admit` allowed

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `verify-lean.sh` | script | stable | Lean 4 proof verification |
| `verify-coq.sh` | script | stable | Coq proof verification |
| `verification-integration.scm` | test file | stable | Formal verification integration tests |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| Lean 4 | Latest | Proof verification | No |
| Coq | ≥8.15 | Proof verification | No |
| src/lean/ | Latest | Proofs under test | No |
| src/coq/ | Latest | Proofs under test | No |

---

## Coverage Requirements

- **Proof Verification:** 100% (all proofs must verify)
- **No `sorry`/`admit`:** 100% (no incomplete proofs)

---

## Normative References

1. **Formal Verification** - `production-docs/formal-verification.md`
2. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)

---

## Status & Evolution

This component is:
- ✅ Active - Formal verification maintained
- ✅ Complete - All proofs verified

---

*Formal verification tests ensure mathematical correctness by verifying all formal proofs compile and verify successfully.*

