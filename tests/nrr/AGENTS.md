# AGENTS.md
## NRR Tests - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** Testing Standards  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** nrr-tests
- **Path:** `tests/nrr/`
- **Component-ID:** nrr-tests-v1.0.0
- **Layer:** 7 (Tests - Measurable Coverage)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Test all NRR operations (put, get, append, log)
- [x] Test all storage backends (file, memory, embedded)
- [x] Test deterministic replay
- [x] Test binary safety
- [x] All tests must be deterministic

### MUST NOT (Prohibitive Constraints)

- [x] Skip storage backend testing
- [x] Ignore replay determinism
- [x] Break binary safety tests

---

## Layer-Specific Responsibilities

### Primary Role

NRR tests provide comprehensive testing of the Native Repository Runtime, including storage backends, log operations, and deterministic replay.

### Layer 7 (Tests) Invariants

- **Completeness:** All NRR operations must be tested
- **Backend Coverage:** All storage backends must be tested

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `storage.test.scm` | test file | stable | Storage backend tests |
| `log.test.scm` | test file | stable | Log operation tests |
| `replay.test.scm` | test file | stable | Deterministic replay tests |
| `hash.test.scm` | test file | stable | Hash function tests |
| `integration.test.scm` | test file | stable | NRR integration tests |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| src/nrr/ | Latest | Component under test | No |

---

## Coverage Requirements

- **Line Coverage:** ≥ 85% (NRR operations)
- **Branch Coverage:** ≥ 80% (all storage backends)
- **Backend Coverage:** All storage backends tested

---

## Normative References

1. **Native Repository Runtime** - `dev-docs/Native Repository Runtime.md`
2. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)

---

## Status & Evolution

This component is:
- ✅ Active - NRR tests maintained
- ✅ Comprehensive - All backends tested

---

*NRR tests ensure the Native Repository Runtime correctly implements content-addressed storage and deterministic replay across all backends.*

