# AGENTS.md
## Integration Tests - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** Testing Standards  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** integration-tests
- **Path:** `tests/integration/`
- **Component-ID:** integration-tests-v1.0.0
- **Layer:** 7 (Tests - Measurable Coverage)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Test end-to-end workflows
- [x] Test cross-module interactions
- [x] Test boundary → realization → validation flow
- [x] Test CanvasL execution
- [x] All tests must be deterministic

### MUST NOT (Prohibitive Constraints)

- [x] Skip integration scenarios
- [x] Break end-to-end workflows
- [x] Ignore cross-module interactions

---

## Layer-Specific Responsibilities

### Primary Role

Integration tests verify that all BICF modules work together correctly, testing complete workflows from boundary definition to validation.

### Layer 7 (Tests) Invariants

- **End-to-End:** Tests must cover complete workflows
- **Cross-Module:** Tests must verify module interactions

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `bicf-integration.test.scm` | test file | stable | BICF system integration tests |
| `bicf-aal-integration.test.scm` | test file | stable | BICF-AAL integration tests |
| `assembly-pipeline.test.scm` | test file | stable | Assembly generation pipeline tests |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| All BICF modules | Latest | Components under test | No |

---

## Coverage Requirements

- **Workflow Coverage:** All major workflows tested
- **Module Interaction:** All cross-module interactions tested
- **End-to-End:** Complete boundary → validation flows tested

---

## Normative References

1. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)

---

## Status & Evolution

This component is:
- ✅ Active - Integration tests maintained
- ✅ Comprehensive - All workflows tested

---

*Integration tests ensure all BICF modules work together correctly, verifying complete system functionality.*

