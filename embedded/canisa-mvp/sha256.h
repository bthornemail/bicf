#ifndef BICF_SHA256_H
#define BICF_SHA256_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
  uint32_t state[8];
  uint64_t bitlen;
  uint8_t block[64];
  size_t block_len;
} bicf_sha256_ctx_t;

void bicf_sha256_init(bicf_sha256_ctx_t* ctx);
void bicf_sha256_update(bicf_sha256_ctx_t* ctx, const uint8_t* data, size_t len);
void bicf_sha256_final(bicf_sha256_ctx_t* ctx, uint8_t out32[32]);

#endif

