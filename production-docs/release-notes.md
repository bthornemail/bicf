# BICF Production System - Release Notes

**Last Updated:** 2025-12-18

## 2025-12-18 (Tooling + deterministic harness update)

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


