#include "canisa_poly_f2.h"

#include <string.h>

static inline uint32_t bit_mask_u32(uint16_t bit) { return (uint32_t)1u << (bit & 31u); }
static inline uint16_t word_index(uint16_t deg) { return (uint16_t)(deg >> 5); }

void canisa_poly_zero(canisa_poly_f2_t* p) {
  if (!p) return;
  memset(p->words, 0, sizeof(p->words));
}

bool canisa_poly_is_zero(const canisa_poly_f2_t* p) {
  if (!p) return true;
  for (size_t i = 0; i < CANISA_POLY_MAX_WORDS; i++) {
    if (p->words[i] != 0) return false;
  }
  return true;
}

int32_t canisa_poly_deg(const canisa_poly_f2_t* p) {
  if (!p) return -1;
  for (int32_t wi = (int32_t)CANISA_POLY_MAX_WORDS - 1; wi >= 0; wi--) {
    uint32_t w = p->words[wi];
    if (!w) continue;
    for (int32_t bi = 31; bi >= 0; bi--) {
      if ((w >> bi) & 1u) return (wi * 32) + bi;
    }
  }
  return -1;
}

void canisa_poly_xor(canisa_poly_f2_t* p, const canisa_poly_f2_t* q) {
  if (!p || !q) return;
  for (size_t i = 0; i < CANISA_POLY_MAX_WORDS; i++) p->words[i] ^= q->words[i];
}

bool canisa_poly_set_deg(canisa_poly_f2_t* p, uint16_t deg) {
  if (!p) return false;
  uint16_t wi = word_index(deg);
  if (wi >= CANISA_POLY_MAX_WORDS) return false;
  p->words[wi] |= bit_mask_u32(deg);
  return true;
}

bool canisa_poly_clear_deg(canisa_poly_f2_t* p, uint16_t deg) {
  if (!p) return false;
  uint16_t wi = word_index(deg);
  if (wi >= CANISA_POLY_MAX_WORDS) return false;
  p->words[wi] &= ~bit_mask_u32(deg);
  return true;
}

bool canisa_poly_shift_left(canisa_poly_f2_t* out, const canisa_poly_f2_t* p, uint16_t k) {
  if (!out || !p) return false;
  canisa_poly_zero(out);
  if (k == 0) {
    *out = *p;
    return true;
  }

  uint16_t word_shift = (uint16_t)(k >> 5);
  uint16_t bit_shift = (uint16_t)(k & 31u);
  if (word_shift >= CANISA_POLY_MAX_WORDS) return canisa_poly_is_zero(p);

  for (int32_t i = (int32_t)CANISA_POLY_MAX_WORDS - 1; i >= 0; i--) {
    uint32_t w = p->words[i];
    if (!w) continue;
    int32_t oi = i + word_shift;
    if (oi >= (int32_t)CANISA_POLY_MAX_WORDS) return false;
    if (bit_shift == 0) {
      out->words[oi] ^= w;
    } else {
      uint32_t lo = w << bit_shift;
      uint32_t hi = w >> (32u - bit_shift);
      out->words[oi] ^= lo;
      if (hi) {
        if (oi + 1 >= (int32_t)CANISA_POLY_MAX_WORDS) return false;
        out->words[oi + 1] ^= hi;
      }
    }
  }
  return true;
}

void canisa_poly_shift_right(canisa_poly_f2_t* out, const canisa_poly_f2_t* p, uint16_t k) {
  if (!out || !p) return;
  canisa_poly_zero(out);
  if (k == 0) {
    *out = *p;
    return;
  }
  uint16_t word_shift = (uint16_t)(k >> 5);
  uint16_t bit_shift = (uint16_t)(k & 31u);
  if (word_shift >= CANISA_POLY_MAX_WORDS) return;

  for (size_t oi = 0; oi < CANISA_POLY_MAX_WORDS; oi++) {
    size_t i = oi + word_shift;
    if (i >= CANISA_POLY_MAX_WORDS) break;
    uint32_t w = p->words[i];
    if (bit_shift == 0) {
      out->words[oi] ^= w;
    } else {
      uint32_t lo = w >> bit_shift;
      uint32_t hi = 0;
      if (i + 1 < CANISA_POLY_MAX_WORDS) hi = p->words[i + 1] << (32u - bit_shift);
      out->words[oi] ^= (lo | hi);
    }
  }
}

bool canisa_poly_mul(canisa_poly_f2_t* out, const canisa_poly_f2_t* p, const canisa_poly_f2_t* q) {
  if (!out || !p || !q) return false;
  canisa_poly_zero(out);
  if (canisa_poly_is_zero(p) || canisa_poly_is_zero(q)) return true;

  // Iterate over set bits in p and XOR shifted q into out.
  for (uint16_t wi = 0; wi < CANISA_POLY_MAX_WORDS; wi++) {
    uint32_t w = p->words[wi];
    while (w) {
      uint32_t lsb = w & (~w + 1u);
      uint16_t bi = (uint16_t)__builtin_ctz(w);
      uint16_t deg = (uint16_t)(wi * 32u + bi);
      canisa_poly_f2_t tmp;
      if (!canisa_poly_shift_left(&tmp, q, deg)) return false;
      canisa_poly_xor(out, &tmp);
      w ^= lsb;
    }
  }
  return true;
}

bool canisa_poly_divmod(canisa_poly_f2_t* q, canisa_poly_f2_t* r, const canisa_poly_f2_t* a,
                        const canisa_poly_f2_t* b) {
  if (!q || !r || !a || !b) return false;
  if (canisa_poly_is_zero(b)) return false;

  canisa_poly_zero(q);
  *r = *a;

  int32_t db = canisa_poly_deg(b);
  int32_t dr = canisa_poly_deg(r);
  while (dr >= db && dr >= 0) {
    uint16_t shift = (uint16_t)(dr - db);
    canisa_poly_set_deg(q, shift);
    canisa_poly_f2_t bs;
    (void)canisa_poly_shift_left(&bs, b, shift);
    canisa_poly_xor(r, &bs);
    dr = canisa_poly_deg(r);
  }
  return true;
}

void canisa_poly_gcd(canisa_poly_f2_t* out, const canisa_poly_f2_t* a, const canisa_poly_f2_t* b) {
  if (!out || !a || !b) return;
  canisa_poly_f2_t x = *a;
  canisa_poly_f2_t y = *b;

  while (!canisa_poly_is_zero(&y)) {
    canisa_poly_f2_t q, r;
    (void)canisa_poly_divmod(&q, &r, &x, &y);
    x = y;
    y = r;
  }
  *out = x;
}

bool canisa_poly_lcm(canisa_poly_f2_t* out, const canisa_poly_f2_t* a, const canisa_poly_f2_t* b) {
  if (!out || !a || !b) return false;
  if (canisa_poly_is_zero(a) || canisa_poly_is_zero(b)) {
    canisa_poly_zero(out);
    return true;
  }
  canisa_poly_f2_t g;
  canisa_poly_gcd(&g, a, b);
  if (canisa_poly_is_zero(&g)) {
    canisa_poly_zero(out);
    return true;
  }

  canisa_poly_f2_t prod;
  if (!canisa_poly_mul(&prod, a, b)) return false;

  // Exact division (prod / g), remainder must be zero.
  canisa_poly_f2_t q, r;
  if (!canisa_poly_divmod(&q, &r, &prod, &g)) return false;
  if (!canisa_poly_is_zero(&r)) return false;
  *out = q;
  return true;
}

uint16_t canisa_poly_trim_len(const canisa_poly_f2_t* p) {
  int32_t d = canisa_poly_deg(p);
  if (d < 0) return 0;
  return (uint16_t)(d + 1);
}

static bool canisa_poly_get_coeff(const canisa_poly_f2_t* p, uint16_t deg) {
  uint16_t wi = word_index(deg);
  if (wi >= CANISA_POLY_MAX_WORDS) return false;
  return ((p->words[wi] >> (deg & 31u)) & 1u) != 0;
}

size_t canisa_poly_write_canonical_bytes(uint8_t* out, size_t out_cap, const canisa_poly_f2_t* p) {
  if (!out || !p) return 0;
  uint16_t len = canisa_poly_trim_len(p);
  size_t need = (size_t)2 + (size_t)len;
  if (out_cap < need) return 0;
  out[0] = (uint8_t)(len & 0xffu);
  out[1] = (uint8_t)((len >> 8) & 0xffu);
  for (uint16_t i = 0; i < len; i++) out[2 + i] = canisa_poly_get_coeff(p, i) ? 1u : 0u;
  return need;
}

