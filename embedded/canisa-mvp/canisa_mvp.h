#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Runs CAN-ISA v1.0 MVP on a CANBC container and returns deterministic results.
//
// Supported subset matches `src/canisa/vm.scm`:
// - mode: F2 only (DEF_MOD mode=0, p ignored but must be 2)
// - univariate polynomial backend over F2
// - hash algo: SHA-256 only (algo=1)

#ifndef CANISA_MVP_MAX_HANDLES
#define CANISA_MVP_MAX_HANDLES 256
#endif

#ifndef CANISA_MVP_MAX_CANON_BYTES
#define CANISA_MVP_MAX_CANON_BYTES 2048
#endif

typedef struct {
  bool ok;
  uint32_t events;
  char state_hash[7 + 64 + 1];  // "sha256:" + 64 hex + NUL
  char fano_hash[7 + 64 + 1];   // "sha256:" + 64 hex + NUL (optional; set by PROJ_FANO)
} canisa_mvp_result_t;

bool canisa_mvp_run_canbc(const uint8_t* canbc, size_t canbc_len, canisa_mvp_result_t* out);
