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

bool clbc_vm_run(const uint8_t* clbc, size_t clbc_len, clbc_vm_result_t* out);

#endif

