# CAN-ISA v1.0 MVP (`.canbc`)

This repo now includes a **minimal CAN-ISA v1.0 vertical slice** (byte opcodes) producing a deterministic **canonical state hash**.

This is a clean break from existing `.clbc` (CanvasL record-stream VM). The new artifact is **`.canbc`**.

## Artifact format: `.canbc` (MVP)

Container bytes:

- Magic: `CANBC\0` (6 bytes)
- Version: `u16le` (currently `1`)
- Payload length: `u32le`
- Payload: raw CAN-ISA bytecode bytes

## MVP semantics (current implementation)

The current VM backend is **univariate F₂[x] polynomials** using `src/aal/polynomials.scm`:

- **State**: a polynomial over F₂, represented as a boolean list in little-endian coefficient order.
- **TERM handles**: also polynomials (used as addends).
- `STATE_ADD`: polynomial XOR
- `STATE_GCD` / `STATE_LCM`: `poly-gcd` / `poly-lcm`
- `STATE_NORM`: `trim` (canonical form)
- `STATE_HASH`: `sha256(u16le(len) || coeff-bytes...)`

This is intentionally minimal to establish:

- deterministic canonicalization (RFC-0001),
- meet/join operators (RFC-009 “Axiom 6” path),
- byte-identical hashing across targets (later: ESP32/Pico).

## Tools

- Assemble Scheme s-expr program → `.canbc`:
  - `guile -s tools/can-asm.scm tests/canisa/canisa-mini.input.scm /tmp/demo.canbc`
- Run VM and print hash:
  - `guile -s tools/can-run.scm /tmp/demo.canbc`
- Run 3×ESP32 MQTT demo:
  - `scripts/demo-canbc-3esp.sh --broker 127.0.0.1`
  - Auto-discovery (no fixed device IDs): `scripts/demo-canbc-3esp.sh --broker 127.0.0.1 --auto`
  - UDP discovery (no MQTT announce needed): `scripts/demo-canbc-3esp.sh --broker 127.0.0.1 --udp`
- Benchmark 3×ESP32 MQTT run (wall-clock + device-reported `exec_ms` when available):
  - `scripts/bench-canbc-3esp.sh --broker 127.0.0.1 --runs 25`
  - Auto-discovery: `scripts/bench-canbc-3esp.sh --broker 127.0.0.1 --auto --runs 25`
  - UDP discovery: `scripts/bench-canbc-3esp.sh --broker 127.0.0.1 --udp --runs 25`

## Test

- `bash tests/canisa/run-canisa-mini.sh`

## Next steps (RFC-009 / origami fold semantics)

This MVP does **not** yet implement:

- multi-variate term bitsets,
- explicit `PROJ_FANO` (now available as an extension opcode producing `fano_hash` from the current state),
- fold axiom opcodes and "barrier" enforcement.

The next implementation step is to extend the VM state to a sparse map keyed by `(vars_bitset, exp2)` and then layer:

- `PROJ_FANO` (idempotent projection, RFC-008),
- fold operators + barrier rules (RFC-009).

---

## Evolution Path

CAN-ISA v1.0 MVP is a minimal implementation establishing polynomial semantics and deterministic canonical state hashing. It serves as a field-testing platform and proof-of-concept for embedded CAN-ISA execution.

**Planned Extensions** (within MVP scope):
- Multi-variate term bitsets
- Explicit `PROJ_FANO` operator
- Fold axiom opcodes

**Formal Evolution**: See [Tetragrammatron-OS](../apps/tetragrammatron-os/) for RFC-driven formalization with:
- **32-bit fixed-width CANB v1 encoding** (RFC-0012)
- **8-tuple semantic registers** (RFC-0009)
- **Fold semantics and barrier enforcement** (RFC-0009, RFC-0013)
- **Repository lattice (8³ topology)** with Fano merge gate (RFC-0011)
- **Lean formal verification** with 20 invariants

**Relationship to Main BICF Project**:
- CAN-ISA MVP uses polynomial semantics from `src/aal/polynomials.scm`
- Shares hardware targets with BICF embedded devices
- Complements BICF's production CanvasL execution
- Serves as intermediate step toward Tetragrammatron-OS formalization

For detailed comparison of all three systems (BICF, CAN-ISA MVP, Tetragrammatron-OS), see:
- [Tetragrammatron-OS and BICF Relationship](tetragrammatron-bicf-relationship.md)
- [CAN-ISA Evolution](can-isa-evolution.md)
- [System Selection Guide](system-selection-guide.md)
