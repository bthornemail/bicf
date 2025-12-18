#include "bicf_proto.h"

#include "mbedtls/sha256.h"

bool bicf_sha256(const uint8_t* data, size_t len, uint8_t out32[32]) {
  if (!out32) return false;
  if (!data && len != 0) return false;
  (void)mbedtls_sha256(data ? data : (const uint8_t*)"", len, out32, 0);
  return true;
}

void bicf_hex32(const uint8_t in32[32], char out65[65]) {
  static const char* hex = "0123456789abcdef";
  for (size_t i = 0; i < 32; i++) {
    out65[i * 2] = hex[(in32[i] >> 4) & 0x0F];
    out65[i * 2 + 1] = hex[in32[i] & 0x0F];
  }
  out65[64] = '\0';
}

