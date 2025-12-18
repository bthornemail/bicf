#ifndef CLBC_VM_H
#define CLBC_VM_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
  bool ok;
  uint32_t events;
  uint8_t transcript_sha256[32];
} clbc_vm_result_t;

// Parse CLBC container bytes, compute deterministic transcript SHA-256 over the
// canonicalized opcode+payload chunks (matching host `src/vm/clbc-vm.scm`).
//
// Returns false on fatal parse errors. `out->ok` is true only when the record
// stream was fully consumed without errors.
bool clbc_vm_run(const uint8_t* clbc, size_t clbc_len, clbc_vm_result_t* out);

#endif

