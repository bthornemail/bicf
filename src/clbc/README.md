## CLBC (CanvasL ByteCode) – MVP implementation notes

This folder implements the **CLBC container format** and **bytecode encoding/decoding** described in:

- `dev-docs/Inbox/Map CanvasL JSONL → ISA Bytecode (Deterministic, Emulator-Friendly).md`

### MVP scope

- CLBC container header (`CLBC`, version `0x01`)
- Deterministic string table (lexicographic unique strings → stable `sid`)
- Record stream encoding for the core opcodes used by the MVP compiler/VM

### Determinism rules

- String table is canonicalized by **lexicographic ordering**
- Integers are encoded using **ULEB128** unless stated otherwise
- All multi-byte fixed-width integers in the header are **little-endian**


