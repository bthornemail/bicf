# AGENTS.md
## BICF Core - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** RFC-0001 (BICF Core) Compliant  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** bicf-core
- **Path:** `src/core/`
- **Component-ID:** bicf-core-v1.0.0
- **Layer:** 2 (Core - Deterministic Algorithms)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z
- **RFC Compliance:** RFC-0001 (BICF Core)

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Implement all 5 BICF axioms (RFC-0001)
- [x] Preserve boundary-interior duality (Axiom 1)
- [x] Enforce non-canonicity (Axiom 2)
- [x] Maintain boundary primacy (Axiom 3)
- [x] Require explicit realization (Axiom 4)
- [x] Ensure projection safety (Axiom 5)
- [x] All functions must be deterministic
- [x] No dependencies on other BICF modules
- [x] R5RS Scheme compatibility
- [x] Pass all compliance tests (`test-bicf-compliance`)

### MUST NOT (Prohibitive Constraints)

- [x] Modify BICF axioms without RFC-0001 update
- [x] Introduce non-deterministic behavior
- [x] Create dependencies on other BICF modules
- [x] Break R5RS Scheme compatibility
- [x] Violate boundary-interior duality
- [x] Allow implicit realization
- [x] Introduce hidden state

---

## Layer-Specific Responsibilities

### Primary Role

BICF Core provides the foundational axiomatic framework for boundary-interior duality. It defines the minimal interface that all BICF components must satisfy.

### Layer 2 (Core) Invariants

- **Determinism:** All functions produce identical outputs for identical inputs
- **Purity:** No side effects (except error handling)
- **Completeness:** All 5 axioms implemented and testable
- **Independence:** No dependencies on other BICF modules
- **Portability:** R5RS Scheme standard only

---

## Admissible Operations

### Agents MAY

- **Add helper functions** when preserving axiom semantics
- **Optimize implementations** when maintaining determinism
- **Extend type predicates** for new BICF types
- **Add convenience constructors** (`make-boundary`, `make-choice`, etc.)
- **Improve error messages** without changing behavior
- **Add tests** that verify axiom compliance

### Execution Examples

```
add helper function for boundary validation
optimize interior? predicate for performance
add convenience constructor for simple boundaries
extend test-bicf-compliance with new test cases
improve error messages in realize function
```

### Forbidden Operations

```
modify BICF axioms (requires RFC-0001 update)
introduce non-deterministic behavior
add dependencies on other BICF modules
break R5RS Scheme compatibility
change function signatures of core interfaces
remove axiom compliance tests
```

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `boundary?` | function | stable | Type predicate for Boundary objects |
| `interior?` | function | stable | Type predicate for Interior objects |
| `view?` | function | stable | Type predicate for View objects |
| `choice?` | function | stable | Type predicate for Choice objects |
| `difference?` | function | stable | Type predicate for Difference objects |
| `valid?` | function | stable | Validity predicate (Interior × Boundary → Bool) |
| `sat` | function | stable | Alias for `valid?` (mathematical notation) |
| `transform` | function | stable | Boundary transformation (Boundary → Boundary) |
| `realize` | function | stable | Realization function (Boundary × Choice → Interior) |
| `project` | function | stable | Interior projection (Interior → View) |
| `difference` | function | stable | Difference computation (Interior × Interior → Difference) |
| `axiom1-boundary-interior-duality` | function | stable | Test Axiom 1 compliance |
| `axiom2-non-canonicity` | function | stable | Test Axiom 2 compliance |
| `axiom3-boundary-primacy` | function | stable | Test Axiom 3 compliance |
| `axiom4-explicit-realization` | function | stable | Test Axiom 4 compliance |
| `axiom5-projection-safety` | function | stable | Test Axiom 5 compliance |
| `test-bicf-compliance` | function | stable | Run all axiom compliance tests |
| `make-boundary` | function | stable | Constructor for Boundary objects |
| `make-choice` | function | stable | Constructor for Choice objects |
| `make-simple-boundary` | function | stable | Constructor for simple boundaries |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| R5RS Scheme | Standard | Implementation language | No |

**Note:** BICF Core has **no dependencies** on other BICF modules. It is the foundational layer.

### Data Contracts

#### Boundary Object
```json
{
  "type": "object",
  "required": ["id"],
  "properties": {
    "id": {"type": "string"},
    "realize-fn": {"type": "function", "optional": true},
    "transform-fn": {"type": "function", "optional": true}
  }
}
```

#### Interior Object
```json
{
  "type": "object",
  "required": ["boundary-ref"],
  "properties": {
    "boundary-ref": {"type": "string"},
    "choice-id": {"type": "string", "optional": true},
    "data": {"type": "any", "optional": true},
    "project-fn": {"type": "function", "optional": true}
  }
}
```

---

## Complexity Governance

### Current Metrics

- **Type Predicates:** O(1) - Simple structure checks
- **Validity Check:** O(1) - Reference matching only
- **Realization:** O(1) - Default or function call
- **Transformation:** O(1) - Default or function call
- **Projection:** O(1) - Default or function call

### Budget Allocation

- **All operations:** O(1) - Constant time complexity
- **No loops or recursion** in core operations
- **Simple data structures** (association lists)

### Budget Enforcement

- ✅ All operations must remain O(1)
- ❌ Block any changes introducing O(n) or higher complexity
- ✅ Helper functions may have higher complexity if isolated

---

## Verification & Testing

### Required Tests

- [x] **Unit Tests:** `tests/unit/core.test.scm` - All axiom tests
- [x] **Compliance Tests:** `test-bicf-compliance` function - Axiom verification

### Test Coverage

- **Axiom 1:** Boundary-interior duality tests
- **Axiom 2:** Non-canonicity tests (multiple realizations)
- **Axiom 3:** Boundary primacy tests
- **Axiom 4:** Explicit realization tests
- **Axiom 5:** Projection safety tests

### Coverage Requirements

- **Line Coverage:** ≥ 95% (core module must be highly tested)
- **Branch Coverage:** ≥ 90% (all axiom paths tested)
- **Axiom Coverage:** 100% (all 5 axioms must have tests)

---

## Merge Semantics

### Merge Compatibility

This component MAY be merged IF:

#### Required Conditions

- [x] All axiom compliance tests pass
- [x] No BICF axioms are modified
- [x] All functions remain deterministic
- [x] No dependencies on other modules introduced
- [x] R5RS Scheme compatibility maintained

#### Conflict Resolution

**If axioms are modified:**
1. RFC-0001 must be updated first
2. All dependent modules must be notified
3. Formal verification must be updated
4. Documentation must reflect changes

**If interfaces change:**
1. Assess impact on all dependent modules
2. Update API reference documentation
3. Maintain backward compatibility if possible
4. Version the interface if breaking changes

---

## Change Protocol

### Modifying This Component

1. **Proposal:** Document proposed change in PR
2. **Validation:**
   - Run `test-bicf-compliance` to verify axioms
   - Run `tests/unit/core.test.scm` to verify tests pass
   - Verify R5RS Scheme compatibility
3. **Impact:** Assess effect on:
   - All modules that use BICF Core
   - Formal verification (if axioms change)
   - API reference documentation
4. **Approval:** Get review from maintainers familiar with:
   - RFC-0001 (BICF Core specification)
   - BICF axioms and their implications
5. **Update:**
   - Modify `bicf-core.scm`
   - Update tests if needed
   - Update `production-docs/api-reference.md`
   - Update this AGENTS.md if constraints change
6. **Verification:**
   - Confirm all tests pass
   - Verify no dependencies introduced
   - Check R5RS compatibility

### Versioning Rules

- **MAJOR:** BICF axiom modifications (requires RFC-0001 update)
- **MINOR:** New helper functions or convenience constructors
- **PATCH:** Bug fixes, error message improvements

---

## Normative References

1. **RFC-0001: BICF Core** - `dev-docs/RFC-BICF-CANVASL-POLY-001/02-bicf-specification/RFC-0001-BICF-Core.md`
2. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)
3. **API Reference** - `production-docs/api-reference.md` (BICF Core Module section)

---

## Status & Evolution

This component is:
- ✅ Complete - All 5 axioms implemented
- ✅ Tested - Comprehensive compliance tests
- ✅ Stable - No dependencies, foundational layer
- ✅ RFC-compliant - Implements RFC-0001

**Component Status:**
- ✅ All 5 BICF axioms: Implemented and tested
- ✅ Type predicates: Complete
- ✅ Core interfaces: Complete
- ✅ Compliance testing: Complete

---

*BICF Core is the foundational layer. All other BICF components depend on its axioms and interfaces. Changes here affect the entire system.*

