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

## Test

- `bash tests/canisa/run-canisa-mini.sh`

## Next steps (RFC-009 / origami fold semantics)

This MVP does **not** yet implement:

- multi-variate term bitsets,
- explicit `PROJ_FANO`,
- fold axiom opcodes and “barrier” enforcement.

The next implementation step is to extend the VM state to a sparse map keyed by `(vars_bitset, exp2)` and then layer:

- `PROJ_FANO` (idempotent projection, RFC-008),
- fold operators + barrier rules (RFC-009).

