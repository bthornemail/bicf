// CLBC embedded parity surface (MVP)
// This is a header-only contract; implementation is a later step.
//
// Goal: run the same CLBC programs as the desktop reference VM and produce the
// same transcript hash.

#ifndef CLBC_VM_H
#define CLBC_VM_H

#include <stddef.h>
#include <stdint.h>

typedef enum {
  CLBC_OK = 0,
  CLBC_ERR_BAD_MAGIC = 1,
  CLBC_ERR_UNSUPPORTED_VERSION = 2,
  CLBC_ERR_TRUNCATED = 3,
  CLBC_ERR_UNKNOWN_OPCODE = 4,
  CLBC_ERR_BUFFER_TOO_SMALL = 5
} clbc_status_t;

typedef struct {
  uint32_t events;
  clbc_status_t status;
  // ASCII hex transcript hash (NUL-terminated)
  char transcript_hash[65];
} clbc_run_result_t;

// Runs a CLBC container buffer. Must be deterministic.
// - program: pointer to full CLBC container bytes
// - program_len: length in bytes
// - out: result including transcript_hash
clbc_status_t clbc_run(const uint8_t* program, size_t program_len, clbc_run_result_t* out);

#endif


