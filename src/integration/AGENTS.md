# AGENTS.md
## BICF Integration Layer - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** BICF System Integration  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** bicf-integration
- **Path:** `src/integration/`
- **Component-ID:** integration-v1.0.0
- **Layer:** 3/4 (API/Services - Interface Contracts & System Coordination)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z
- **RFC Compliance:** BICF System Integration

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Coordinate all BICF modules (Core, FANO, PCG, CanvasL, AAL)
- [x] Provide unified system interface
- [x] Support module loading and lifecycle management
- [x] Maintain boundary registry
- [x] Support assembly language generation
- [x] All coordination must be deterministic
- [x] R5RS Scheme compatibility

### MUST NOT (Prohibitive Constraints)

- [x] Break module dependencies
- [x] Introduce non-deterministic coordination
- [x] Create circular dependencies
- [x] Break boundary registry integrity

---

## Layer-Specific Responsibilities

### Primary Role

Integration Layer coordinates all BICF modules, providing system initialization, module loading, boundary registry management, and unified interfaces.

### Layer 3/4 (API/Services) Invariants

- **Interface Stability:** Public APIs must remain stable
- **Testability:** Business logic must be testable
- **Explicit State:** State management must be explicit

---

## Admissible Operations

### Agents MAY

- **Add new module loaders** when maintaining dependency order
- **Extend boundary registry** with new functionality
- **Add convenience functions** for common operations
- **Improve error handling** and diagnostics

### Forbidden Operations

```
break module dependencies
introduce circular dependencies
break boundary registry integrity
introduce non-deterministic coordination
```

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `init-bicf-system` | function | stable | Initialize BICF system |
| `register-boundary` | function | stable | Register boundary in registry |
| `get-boundary` | function | stable | Retrieve boundary from registry |
| `load-module` | function | stable | Load BICF module |
| `generate-assembly` | function | stable | Generate assembly from boundary |
| `execute-canvasl` | function | stable | Execute CanvasL file |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| src/core/ | Latest | BICF Core | No |
| src/fano/ | Latest | FANO Boundary | No |
| src/consensus/ | Latest | PCG Consensus | No |
| src/canvasl/ | Latest | CanvasL Interpreter | No |
| src/aal/ | Latest | AAL Compiler | No |

---

## Verification & Testing

### Required Tests

- [x] **Integration Tests:** `tests/integration/bicf-integration.test.scm`

### Coverage Requirements

- **Line Coverage:** ≥ 80% (integration layer)
- **Branch Coverage:** ≥ 75% (all coordination paths)

---

## Normative References

1. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)
2. **Architecture** - `production-docs/architecture.md`

---

## Status & Evolution

This component is:
- ✅ Complete - Full BICF integration
- ✅ Tested - Integration tests complete

---

*Integration Layer provides unified coordination of all BICF modules, enabling system-wide boundary-interior computation.*

