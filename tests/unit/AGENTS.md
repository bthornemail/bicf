# AGENTS.md
## Unit Tests - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** Testing Standards  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** unit-tests
- **Path:** `tests/unit/`
- **Component-ID:** unit-tests-v1.0.0
- **Layer:** 7 (Tests - Measurable Coverage)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] All tests must verify actual behavior
- [x] Tests must be deterministic and repeatable
- [x] Coverage must be measurable
- [x] Tests must pass before merge
- [x] R5RS Scheme compatibility

### MUST NOT (Prohibitive Constraints)

- [x] Add tests that don't verify behavior
- [x] Introduce non-deterministic tests
- [x] Skip tests without justification
- [x] Break test framework

---

## Layer-Specific Responsibilities

### Primary Role

Unit tests provide isolated testing of individual components, ensuring each module functions correctly in isolation.

### Layer 7 (Tests) Invariants

- **Measurability:** Coverage must be measurable
- **Isolation:** Tests must be isolated (no dependencies between tests)
- **Determinism:** All tests must be deterministic

---

## Admissible Operations

### Agents MAY

- **Add new unit tests** for component functionality
- **Improve test coverage** for existing components
- **Refactor tests** when maintaining test behavior
- **Add test helpers** for common test patterns

### Forbidden Operations

```
add tests that don't verify behavior
introduce non-deterministic tests
skip tests without justification
break test isolation
```

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `core.test.scm` | test file | stable | BICF Core unit tests |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| R5RS Scheme | Standard | Test execution | No |
| src/core/ | Latest | Component under test | No |

---

## Verification & Testing

### Coverage Requirements

- **Line Coverage:** ≥ 80% for core modules
- **Branch Coverage:** ≥ 75% for validation functions
- **Test Execution:** All tests must pass

---

## Normative References

1. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)

---

## Status & Evolution

This component is:
- ✅ Active - Unit tests maintained
- ✅ Measurable - Coverage tracked

---

*Unit tests ensure individual components function correctly in isolation, providing the foundation for system reliability.*

