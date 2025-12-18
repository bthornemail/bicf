## CLBC Reference VM (MVP)

This is a minimal deterministic VM for executing CLBC bytecode and producing a **transcript hash** suitable for golden tests and embedded differential testing later.

### MVP behavior

- Parses CLBC container (`CLBC`, v1)
- Executes record framing and the MVP subset of validation opcodes
- Updates a rolling transcript hash using `src/nrr/hash.scm` (note: currently not cryptographic)


