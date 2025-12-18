# BICF Production System - Release Notes

**Last Updated:** 2025-12-18

---

## Version 1.1.0 (2025-12-18)

**Status:** Current release - Tooling + deterministic harness update

### Added

- **CLBC (CanvasL ByteCode) compiler + container**
  - Scheme implementation under `src/clbc/`
  - CLI compiler: `tools/canvasl-to-clbc.scm`
  - Deterministic string-table canonicalization (lexicographic)
  - ULEB128 encoding helpers

- **CLBC reference VM + transcript hashing**
  - Scheme VM under `src/vm/clbc-vm.scm`
  - CLI runner: `tools/clbc-run.scm`
  - Deterministic event transcript hash suitable for golden tests and embedded parity work

- **RFC-VIZ-001 (MVP) deterministic scene model**
  - Pure data scene generator: `src/viz/scene.scm`
  - CLI: `tools/viz-scene.scm`
  - Snapshot test coverage under `tests/viz/`

- **CanvasL LSP (MVP)**
  - Minimal Node server: `apps/lsp/canvasl-lsp.js`
  - Custom methods: `canvasl/getScene`, `canvasl/getTrace`, `canvasl/getIncidence`
  - Tooling-only: does not mutate core engine state

### Tests / validation

- `scripts/test.sh` runs:
  - CLBC golden test(s) (`tests/clbc/`)
  - RFC-VIZ-001 scene snapshot test(s) (`tests/viz/`)

### Documentation updates

- Updated `production-docs/api-reference.md`, `production-docs/architecture.md`, `production-docs/formal-verification.md`, `production-docs/implementation-guide.md` to reflect the above additions.

---

## Version 1.0.0 (2024-12-19)

**Status:** Initial production release

### Core Implementation

- **BICF Core** - Complete R5RS Scheme implementation (`src/core/bicf-core.scm`)
  - 5 axioms: Boundary-Interior duality, non-canonicity, boundary primacy, explicit realization, projection safety
  - Type predicates and validation functions

- **FANO Boundary Module** - PG(2,2) validator (`src/fano/fano-checker.scm`)
  - Explicit incidence table (7 points, 7 lines)
  - Exhaustive pairwise uniqueness checking

- **PCG Consensus Module** - Pair-cover guarantee (`src/consensus/pcg-validator.scm`)
  - 14-point universe (two Fano planes)
  - Exhaustive O(n³) triple generation and coverage checking

- **CanvasL Interpreter** - JSONL execution engine (`src/canvasl/interpreter.scm`)
  - Environment management
  - Encoder operations
  - Trace execution with phase monotonicity

### Formal Verification

- **Lean 4** - `src/lean/fano_pcg.lean` (307 lines)
  - ✅ 100% complete - All theorems proven, no `sorry` statements
  - Core PCG theorem fully verified

- **Coq** - `src/coq/Fano_PCG.v` (455 lines)
  - ✅ 100% complete - All theorems proven, no `Admitted` statements
  - Compilation environment-dependent

### Testing & Infrastructure

- Unit tests (`tests/unit/`)
- Integration tests (`tests/integration/`)
- Formal verification scripts (`tests/formal/`)
- Build and test scripts (`scripts/build.sh`, `scripts/test.sh`)
- CI/CD workflow (`.github/workflows/ci.yml`)

### Documentation

- Complete API reference
- Architecture documentation
- Formal verification status
- Implementation guide
- Usage guide
- Validation reports

---

## Version History

| Version | Date | Key Features |
|---------|------|--------------|
| 1.1.0 | 2025-12-18 | CLBC, VM, VIZ, LSP, deterministic testing |
| 1.0.0 | 2024-12-19 | Core, FANO, PCG, CanvasL, formal proofs |
