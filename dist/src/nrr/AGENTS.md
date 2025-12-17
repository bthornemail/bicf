# AGENTS.md
## Native Repository Runtime (NRR) - Component Boundary Contract

**Version:** 1.0.0  
**Status:** Component-Specific Boundary Contract  
**Date:** 2025-01-XX  
**Alignment:** NRR Specification Compliant  
**Parent:** `/AGENTS.md`

---

## Component Identity

- **Name:** native-repository-runtime
- **Path:** `src/nrr/`
- **Component-ID:** nrr-v1.0.0
- **Layer:** 2 (Core - Deterministic Algorithms)
- **Boundary Hash:** [to be computed on commit]
- **Created:** 2024-12-19T00:00:00Z
- **Last Validated:** 2025-01-XXT00:00:00Z
- **RFC Compliance:** Native Repository Runtime specification

---

## Boundary Constraints

### MUST (Affirmative Constraints)

- [x] Implement minimal NRR interface (put, get, append, log)
- [x] Support content-addressed storage (hash-based references)
- [x] Provide append-only log for deterministic replay
- [x] Support multiple storage backends (file, memory, embedded)
- [x] All operations must be deterministic
- [x] Binary-safe (works with binary data)
- [x] MCU-friendly (no heap required, suitable for ESP32)
- [x] R5RS Scheme compatibility
- [x] Support Git adapter (optional backward compatibility)

### MUST NOT (Prohibitive Constraints)

- [x] Require Git as dependency (Git is optional)
- [x] Break minimal interface (put, get, append, log)
- [x] Introduce non-deterministic behavior
- [x] Require heap allocation (must work on MCUs)
- [x] Break binary safety
- [x] Create dependencies on other BICF modules

---

## Layer-Specific Responsibilities

### Primary Role

NRR provides a minimal, Git-independent repository abstraction for BICF/CanvasL. It enables deterministic replay and embedded system deployment through content-addressed storage and append-only logs.

### Layer 2 (Core) Invariants

- **Determinism:** All operations are deterministic and replayable
- **Minimalism:** Only four operations (put, get, append, log)
- **Portability:** Works on ESP32, embedded Linux, WASM, desktop
- **Binary-Safe:** Handles binary data correctly

---

## Admissible Operations

### Agents MAY

- **Add storage backends** (file, memory, embedded, flash)
- **Optimize hash computation** (SHA-256, BLAKE3, CRC32)
- **Extend log entry format** while maintaining compatibility
- **Add convenience functions** for common operations
- **Improve error handling** and diagnostics

### Execution Examples

```
add flash storage backend for ESP32
optimize hash computation with BLAKE3
extend log entry with metadata
add convenience function for batch operations
improve error messages with storage context
```

### Forbidden Operations

```
break minimal interface (put, get, append, log)
require Git as dependency
introduce non-deterministic behavior
require heap allocation
break binary safety
create dependencies on other BICF modules
```

---

## Interface Specifications

### Provided Interfaces

| Name | Type | Stability | Description |
|------|------|-----------|-------------|
| `nrr-put` | function | stable | Store content and return content-addressed reference |
| `nrr-get` | function | stable | Retrieve content by reference |
| `nrr-append` | function | stable | Append entry to append-only log |
| `nrr-log` | function | stable | Retrieve all log entries for deterministic replay |
| `nrr-replay` | function | stable | Replay execution from log entries |
| `nrr-init` | function | stable | Initialize NRR with storage backend |

### Required Dependencies

| Component | Version Constraint | Purpose | Optional |
|-----------|-------------------|---------|----------|
| R5RS Scheme | Standard | Implementation language | No |
| Git | Any | Optional adapter for transport/replication | Yes |

**Note:** NRR has **no dependencies** on other BICF modules. Git is optional.

### Data Contracts

#### Content Reference
```json
{
  "type": "string",
  "pattern": "^[a-f0-9]{64}$",
  "description": "SHA-256 hash of content"
}
```

#### Log Entry
```json
{
  "type": "object",
  "required": ["phase", "type", "ref"],
  "properties": {
    "phase": {"type": "integer", "minimum": 0},
    "type": {"type": "string", "enum": ["boundary", "interior", "guarantee"]},
    "ref": {"type": "string", "pattern": "^[a-f0-9]{64}$"}
  }
}
```

---

## Complexity Governance

### Current Metrics

- **put/get:** O(1) - Hash computation and storage lookup
- **append:** O(1) - Append to log
- **log:** O(n) where n=number of log entries
- **replay:** O(n) where n=number of log entries

### Budget Allocation

- **Storage Operations:** O(1) - Constant time
- **Log Operations:** O(n) - Linear in log size
- **Replay:** O(n) - Linear in log size

### Budget Enforcement

- ✅ O(1) for storage operations
- ✅ O(n) for log operations (acceptable)
- ❌ Block any changes exceeding O(n log n)

---

## Verification & Testing

### Required Tests

- [x] **Unit Tests:** `tests/nrr/` - Storage, log, replay tests
- [x] **Integration Tests:** NRR integration with CanvasL

### Test Coverage

- **Storage Backends:** File, memory, embedded
- **Hash Functions:** SHA-256, BLAKE3, CRC32
- **Log Operations:** Append, retrieve, replay
- **Git Adapter:** Optional Git integration

### Coverage Requirements

- **Line Coverage:** ≥ 85% (core operations)
- **Branch Coverage:** ≥ 80% (all storage backends)
- **Integration Coverage:** NRR-CanvasL integration tested

---

## Merge Semantics

### Merge Compatibility

This component MAY be merged IF:

#### Required Conditions

- [x] Minimal interface preserved (put, get, append, log)
- [x] All storage backends functional
- [x] Deterministic replay verified
- [x] Binary safety maintained
- [x] MCU compatibility preserved

---

## Change Protocol

### Modifying This Component

1. **Proposal:** Document proposed change in PR
2. **Validation:**
   - Run `tests/nrr/` test suite
   - Verify all storage backends work
   - Test deterministic replay
   - Verify MCU compatibility
3. **Impact:** Assess effect on:
   - CanvasL interpreter (uses NRR)
   - Storage backends
   - Git adapter
4. **Approval:** Get review from maintainers familiar with:
   - NRR specification
   - Embedded systems deployment
5. **Update:**
   - Modify NRR modules
   - Update tests
   - Update `production-docs/api-reference.md`
   - Update this AGENTS.md if constraints change

---

## Normative References

1. **Native Repository Runtime** - `dev-docs/Native Repository Runtime.md`
2. **Root AGENTS.md** - `/AGENTS.md` (parent boundary contract)
3. **CanvasL Integration** - `src/canvasl/nrr-backend.scm`

---

## Status & Evolution

This component is:
- ✅ Complete - Minimal interface implemented
- ✅ Tested - Multiple storage backends
- ✅ Stable - No dependencies, self-contained
- ✅ Portable - Works on ESP32, WASM, desktop

**Component Status:**
- ✅ Storage backends: File, memory, embedded
- ✅ Hash functions: SHA-256, BLAKE3, CRC32
- ✅ Git adapter: Optional compatibility layer

---

*NRR enables BICF/CanvasL to work without Git, making it suitable for embedded systems and microcontrollers. It provides the minimal abstraction needed for deterministic replay.*

