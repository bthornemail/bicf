#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Univariate polynomial over F2.
// Coefficients are stored as bits in words[] (little-endian by degree).
//
// Degree limit is fixed by CANISA_POLY_MAX_WORDS.

#ifndef CANISA_POLY_MAX_WORDS
#define CANISA_POLY_MAX_WORDS 32  // 32*32 = 1024 degrees (0..1023)
#endif

typedef struct {
  uint32_t words[CANISA_POLY_MAX_WORDS];
} canisa_poly_f2_t;

void canisa_poly_zero(canisa_poly_f2_t* p);
bool canisa_poly_is_zero(const canisa_poly_f2_t* p);
int32_t canisa_poly_deg(const canisa_poly_f2_t* p);  // -1 if zero

// p ^= q
void canisa_poly_xor(canisa_poly_f2_t* p, const canisa_poly_f2_t* q);

// Set/clear coefficient at x^deg.
bool canisa_poly_set_deg(canisa_poly_f2_t* p, uint16_t deg);
bool canisa_poly_clear_deg(canisa_poly_f2_t* p, uint16_t deg);

// out = p shifted left by k (multiply by x^k). Returns false if overflow.
bool canisa_poly_shift_left(canisa_poly_f2_t* out, const canisa_poly_f2_t* p, uint16_t k);

// out = p shifted right by k (divide by x^k). Always succeeds.
void canisa_poly_shift_right(canisa_poly_f2_t* out, const canisa_poly_f2_t* p, uint16_t k);

// out = p * q. Returns false if overflow.
bool canisa_poly_mul(canisa_poly_f2_t* out, const canisa_poly_f2_t* p, const canisa_poly_f2_t* q);

// Polynomial long division in F2:
// Computes q, r such that a = q*b + r and deg(r) < deg(b).
// Returns false on division by zero.
bool canisa_poly_divmod(canisa_poly_f2_t* q, canisa_poly_f2_t* r, const canisa_poly_f2_t* a, const canisa_poly_f2_t* b);

// out = gcd(a,b). Always succeeds.
void canisa_poly_gcd(canisa_poly_f2_t* out, const canisa_poly_f2_t* a, const canisa_poly_f2_t* b);

// out = lcm(a,b) = (a*b)/gcd(a,b). If gcd==0 => 0. Returns false on overflow.
bool canisa_poly_lcm(canisa_poly_f2_t* out, const canisa_poly_f2_t* a, const canisa_poly_f2_t* b);

// Canonical trim length in coefficients (matches Scheme VM): number of coefficients after trim.
uint16_t canisa_poly_trim_len(const canisa_poly_f2_t* p);

// Writes canonical bytes: u16le(len) || len bytes of 0/1 coefficients.
// Returns number of bytes written; 0 on overflow (out_cap too small).
size_t canisa_poly_write_canonical_bytes(uint8_t* out, size_t out_cap, const canisa_poly_f2_t* p);

