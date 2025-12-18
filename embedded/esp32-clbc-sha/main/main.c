#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "esp_system.h"
#include "esp_chip_info.h"

#include "mbedtls/sha256.h"

#include "clbc_vm.h"
#include "program_clbc.h"

static void bytes_to_hex(const uint8_t* in, size_t in_len, char* out_hex, size_t out_hex_len) {
  static const char* hex = "0123456789abcdef";
  if (out_hex_len < (in_len * 2 + 1)) return;
  for (size_t i = 0; i < in_len; i++) {
    out_hex[i * 2] = hex[(in[i] >> 4) & 0x0F];
    out_hex[i * 2 + 1] = hex[in[i] & 0x0F];
  }
  out_hex[in_len * 2] = '\0';
}

void app_main(void) {
  uint8_t digest[32] = {0};
  char digest_hex[65] = {0};

  // Deterministic: sha256 over the exact embedded CLBC bytes.
  (void)mbedtls_sha256(CLBC_PROGRAM, CLBC_PROGRAM_LEN, digest, 0);
  bytes_to_hex(digest, sizeof(digest), digest_hex, sizeof(digest_hex));

  printf("CLBC_LEN=%u\n", (unsigned)CLBC_PROGRAM_LEN);
  printf("CLBC_SHA256=%s\n", digest_hex);

  clbc_vm_result_t vm = {0};
  if (clbc_vm_run(CLBC_PROGRAM, CLBC_PROGRAM_LEN, &vm)) {
    char vm_hex[65] = {0};
    bytes_to_hex(vm.transcript_sha256, sizeof(vm.transcript_sha256), vm_hex, sizeof(vm_hex));
    printf("VM_OK=%d\n", vm.ok ? 1 : 0);
    printf("VM_EVENTS=%" PRIu32 "\n", vm.events);
    printf("VM_TRANSCRIPT_SHA256=%s\n", vm_hex);
  } else {
    printf("VM_OK=0\n");
    printf("VM_EVENTS=0\n");
    printf("VM_TRANSCRIPT_SHA256=\n");
  }

  // Print chip info for operator sanity (does not affect hashing).
  esp_chip_info_t chip_info;
  esp_chip_info(&chip_info);
  printf("CHIP_MODEL=%d CORES=%d REV=%d\n", chip_info.model, chip_info.cores, chip_info.revision);
}
