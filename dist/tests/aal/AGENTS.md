# AGENTS.md
## AAL Tests - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** Testing Standards  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** aal-tests
- **Path:** `tests/aal/`
- **Component-ID:** aal-tests-v1.0.0
- **Layer:** 7 (Tests - Measurable Coverage)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Test all AAL components (parser, types, semantics, polynomials, geometry)
- [x] Verify polynomial algebra laws
- [x] Test type system (D0-D10)
- [x] Test Fano Plane mapping (D9)
- [x] All tests must be deterministic

### MUST NOT (Prohibitive Constraints)

- [x] Skip AAL component testing
- [x] Break polynomial algebra verification
- [x] Ignore type system tests

---

## Layer-Specific Responsibilities

### Primary Role

AAL tests provide comprehensive testing of the AAL compiler/interpreter system, including polynomial algebra, type system, semantics, and geometry.

### Layer 7 (Tests) Invariants

- **Completeness:** All AAL components must be tested
- **Formal Alignment:** Tests must verify formal properties

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `parser.test.scm` | test file | stable | AAL parser tests |
| `types.test.scm` | test file | stable | Type system tests |
| `semantics.test.scm` | test file | stable | Semantics tests |
| `polynomials.test.scm` | test file | stable | Polynomial algebra tests |
| `geometry.test.scm` | test file | stable | D9 Fano Plane mapping tests |
| `integration.test.scm` | test file | stable | AAL end-to-end tests |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| src/aal/ | Latest | Component under test | No |

---

## Coverage Requirements

- **Line Coverage:** ≥ 85% (AAL compiler/interpreter)
- **Branch Coverage:** ≥ 80% (all type system paths)
- **Polynomial Tests:** All F₂[x] operations tested

---

## Normative References

1. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)
2. **AAL Specification** - `dev-docs/Assembly–Algebra Language v3.2/`

---

## Status & Evolution

This component is:
- ✅ Active - AAL tests maintained
- ✅ Comprehensive - All components tested

---

*AAL tests ensure the compiler/interpreter system correctly implements polynomial algebra, type system, and geometric semantics.*

