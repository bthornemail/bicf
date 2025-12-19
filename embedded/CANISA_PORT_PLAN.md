# CAN-ISA v1.0 embedded port plan (ESP32 + Pico 2 W)

Goal: run `.canbc` programs on ESP32 and Pico 2 W and produce **byte-identical `state_hash`** as the host VM.

Current host MVP implementation:
- `src/canisa/assembler.scm`
- `src/canisa/vm.scm`
- `.canbc` container (magic `CANBC\0`, version=1)
- Backend: univariate F₂[x] polynomials + SHA-256 over a canonical serialization

## Minimal opcode subset to port first

Implement the same subset as `src/canisa/vm.scm`:

- `0x00` `NOP`
- `0x01` `HALT`
- `0x02` `TRAP u16`
- `0x10` `DEF_MOD u8 mode, u32 p` (support mode=0 only)
- `0x20` `TERM_NEW u16 dst, i32 coeff, i16 exp2`
- `0x21` `TERM_SET_VAR u16 term, u16 feat_id`
- `0x22` `TERM_CLR_VAR u16 term, u16 feat_id`
- `0x25` `TERM_ZERO u16 term`
- `0x30` `STATE_ADD u16 term`
- `0x33` `STATE_CLEAR`
- `0x34` `STATE_COPY u16 dst, u16 src` (reserve `0` = current state)
- `0x40` `STATE_NORM u8 mode` (canonical trim)
- `0x52` `STATE_GCD u16 src`
- `0x53` `STATE_LCM u16 src`
- `0x61` `STATE_HASH u8 algo, u16 out` (support algo=1 SHA-256)

## Data model (MVP, matches host)

- Polynomial representation: a bitset over degrees 0..N, where bit i is coefficient of x^i.
  - For MVP, choose `N <= 255` so canonical bytes are small and stable.
- Term storage: map `u16 handle -> poly`.
- State storage: map `u16 handle -> poly`, with `handle 0` reserved as “current”.

## Canonical bytes + hash (must match host)

Canonical bytes:
- `u16le len` (number of coefficients after trim)
- `len` bytes of `0` or `1` for each coefficient (degree 0..len-1)

Hash:
- `sha256(canonical_bytes)` rendered as `sha256:<hex>`

## C implementation sketch

Shared helpers:
- Little-endian reads for `u16/u32/i16/i32`
- `poly_trim()`, `poly_xor()`, `poly_set_degree()`, `poly_clear_degree()`
- `poly_gcd()` / `poly_lcm()` over F₂ using the existing Euclidean division approach (like `src/aal/polynomials.scm`)
- SHA-256 implementation (already present in existing embedded code)

Transport:
- Reuse existing CLBT/USB CDC framing or the MQTT command path to deliver `.canbc` bytes.
  - Command: `{ "type":"load_canbc", "canbc_hex":"..." }`
  - Command: `{ "type":"run" }`
  - Result: `{ "type":"run_result", "ok":true, "events":N, "state_hash":"sha256:..." }`

## Validation

Use `tests/canisa/canisa-mini.input.scm` as the first cross-target parity program:
- Expected output is stable; host prints a `sha256:<64 hex>` string.

