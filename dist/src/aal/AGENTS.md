# AGENTS.md
## AAL (Assembly–Algebra Language) - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** AAL v3.2 Specification Compliant  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** aal-compiler-interpreter
- **Path:** `src/aal/`
- **Component-ID:** aal-v1.0.0
- **Layer:** 2 (Core - Deterministic Algorithms)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z
- **RFC Compliance:** AAL v3.2 Specification

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Preserve polynomial algebra semantics (F₂[x] operations)
- [x] Implement graded modal type system (D0-D10)
- [x] Maintain small-step semantics determinism
- [x] Support D9 Fano Plane mapping (geometry.scm)
- [x] All compiler/interpreter operations must be deterministic
- [x] R5RS Scheme compatibility
- [x] Match AAL v3.2 formal specification

### MUST NOT (Prohibitive Constraints)

- [x] Break polynomial algebra laws (commutativity, associativity, distributivity)
- [x] Violate type system soundness (D0-D10 dimensions)
- [x] Introduce non-deterministic behavior
- [x] Break Fano Plane mapping (D9 geometry)
- [x] Create dependencies on other BICF modules (except for integration)

---

## Layer-Specific Responsibilities

### Primary Role

AAL implements a formally verified language that executes machine code as polynomial transformations over F₂[x], with a complete graded modal type system tracking 11 layers of abstraction (D0-D10).

### Layer 2 (Core) Invariants

- **Determinism:** All compiler/interpreter operations are deterministic
- **Polynomial Semantics:** F₂[x] operations must preserve algebraic laws
- **Type Soundness:** Graded modal type system (D0-D10) must be sound
- **Formal Alignment:** Matches AAL v3.2 specification (127 lemmas, 42 theorems)

---

## Admissible Operations

### Agents MAY

- **Add new instructions** when preserving polynomial semantics
- **Extend type system** when maintaining D0-D10 structure
- **Optimize compiler** while preserving semantics
- **Add convenience functions** for common operations
- **Improve error messages** with type/instruction context

### Execution Examples

```
add new AAL instruction preserving polynomial semantics
extend type checker with new dimension checks
optimize polynomial multiplication algorithm
add convenience function for register allocation
improve error messages with type information
```

### Forbidden Operations

```
break polynomial algebra laws
violate type system soundness
introduce non-deterministic behavior
break Fano Plane mapping (D9)
modify AAL v3.2 specification without update
```

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `parse-aal` | function | stable | Parse AAL program from string |
| `compile-aal` | function | stable | Compile AAL program (parse → well-formed → type-check → code-gen) |
| `interpret-aal` | function | stable | Direct AAL execution with debugging |
| `poly-add` | function | stable | Polynomial addition over F₂[x] |
| `poly-mul` | function | stable | Polynomial multiplication over F₂[x] |
| `poly-gcd` | function | stable | Polynomial GCD over F₂[x] |
| `poly-lcm` | function | stable | Polynomial LCM over F₂[x] |
| `verify-commutativity` | function | stable | Verify polynomial commutativity |
| `verify-associativity` | function | stable | Verify polynomial associativity |
| `verify-distributivity` | function | stable | Verify polynomial distributivity |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| R5RS Scheme | Standard | Implementation language | No |

**Note:** AAL is self-contained. Integration with BICF is handled by `src/integration/`.

---

## Complexity Governance

### Current Metrics

- **Parsing:** O(p) where p=program size (single-pass parser)
- **Type Checking:** O(p) where p=program size (single-pass)
- **Polynomial Operations:** O(n²) where n=polynomial degree
- **Compilation:** O(p) where p=program size

### Budget Allocation

- **Parsing/Type Checking:** O(p) - Linear in program size
- **Polynomial Operations:** O(n²) - Acceptable for typical degrees
- **Compilation:** O(p) - Linear in program size

---

## Verification & Testing

### Required Tests

- [x] **Unit Tests:** `tests/aal/` - Parser, types, semantics, polynomials, geometry
- [x] **Formal Verification:** AAL v3.2 specification (127 lemmas, 42 theorems)

### Test Coverage

- **Polynomial Algebra:** All F₂[x] operations tested
- **Type System:** D0-D10 dimensions tested
- **Semantics:** Small-step semantics tested
- **Geometry:** D9 Fano Plane mapping tested

### Coverage Requirements

- **Line Coverage:** ≥ 85% (compiler/interpreter)
- **Branch Coverage:** ≥ 80% (all type system paths)
- **Formal Verification:** 100% (matches AAL v3.2 specification)

---

## Normative References

1. **AAL v3.2 Specification** - `dev-docs/Assembly–Algebra Language v3.2/`
2. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)

---

## Status & Evolution

This component is:
- ✅ Complete - AAL v3.2 implementation
- ✅ Verified - Matches formal specification
- ✅ Stable - Self-contained compiler/interpreter

**Component Status:**
- ✅ Polynomial algebra: Complete
- ✅ Type system: D0-D10 implemented
- ✅ Compiler/Interpreter: Complete

---

*AAL provides the bridge from machine code to polynomial algebra, enabling formally verified computation with geometric semantics.*

