#include "canisa_mvp.h"

#include <stdio.h>
#include <string.h>

#include "canisa_poly_f2.h"
#include "sha256.h"

enum {
  OP_NOP = 0x00,
  OP_HALT = 0x01,
  OP_TRAP = 0x02,
  OP_DEF_MOD = 0x10,
  OP_TERM_NEW = 0x20,
  OP_TERM_SET_VAR = 0x21,
  OP_TERM_CLR_VAR = 0x22,
  OP_TERM_ZERO = 0x25,
  OP_STATE_ADD = 0x30,
  OP_STATE_CLEAR = 0x33,
  OP_STATE_COPY = 0x34,
  OP_STATE_NORM = 0x40,
  OP_STATE_GCD = 0x52,
  OP_STATE_LCM = 0x53,
  OP_STATE_HASH = 0x61,
  OP_PROJ_FANO = 0x93,
};

static void bytes_to_hex(const uint8_t* in, size_t in_len, char* out_hex, size_t out_hex_len) {
  static const char* hex = "0123456789abcdef";
  if (out_hex_len < (in_len * 2 + 1)) return;
  for (size_t i = 0; i < in_len; i++) {
    out_hex[i * 2] = hex[(in[i] >> 4) & 0x0F];
    out_hex[i * 2 + 1] = hex[in[i] & 0x0F];
  }
  out_hex[in_len * 2] = '\0';
}

static void sha256_prefix_hex(const uint8_t* data, size_t data_len, char out73[7 + 64 + 1]) {
  uint8_t digest[32];
  bicf_sha256_ctx_t ctx;
  bicf_sha256_init(&ctx);
  bicf_sha256_update(&ctx, data, data_len);
  bicf_sha256_final(&ctx, digest);
  char hex[65];
  bytes_to_hex(digest, sizeof(digest), hex, sizeof(hex));
  (void)snprintf(out73, 7 + 64 + 1, "sha256:%s", hex);
}

static void fano_compute_from_state(const canisa_poly_f2_t* state, uint8_t* pointmask_out, uint8_t* linemask_out) {
  uint8_t pointmask = 0;
  for (uint8_t i = 0; i < 7; i++) {
    uint32_t w0 = state->words[0];
    if ((w0 >> i) & 1u) pointmask |= (uint8_t)(1u << i);
  }

  uint8_t linemask = 0;
  struct tri {
    uint8_t a, b, c;
  };
  static const struct tri lines[7] = {
    {0, 1, 2}, {0, 3, 4}, {0, 5, 6}, {1, 3, 5}, {1, 4, 6}, {2, 3, 6}, {2, 4, 5},
  };
  for (uint8_t li = 0; li < 7; li++) {
    uint8_t a = lines[li].a, b = lines[li].b, c = lines[li].c;
    uint8_t m = (uint8_t)((1u << a) | (1u << b) | (1u << c));
    if ((pointmask & m) == m) linemask |= (uint8_t)(1u << li);
  }

  if (pointmask_out) *pointmask_out = pointmask;
  if (linemask_out) *linemask_out = linemask;
}

static void fano_hash_from_state(const canisa_poly_f2_t* state, char out73[7 + 64 + 1]) {
  uint8_t pm = 0, lm = 0;
  fano_compute_from_state(state, &pm, &lm);
  uint8_t proj_bytes[2] = {pm, lm};
  sha256_prefix_hex(proj_bytes, sizeof(proj_bytes), out73);
}

static bool read_u8(const uint8_t* buf, size_t len, size_t* idx, uint8_t* out) {
  if (*idx >= len) return false;
  *out = buf[*idx];
  *idx += 1;
  return true;
}

static bool read_u16le(const uint8_t* buf, size_t len, size_t* idx, uint16_t* out) {
  if (*idx + 2 > len) return false;
  *out = (uint16_t)(buf[*idx] | ((uint16_t)buf[*idx + 1] << 8));
  *idx += 2;
  return true;
}

static bool read_u32le(const uint8_t* buf, size_t len, size_t* idx, uint32_t* out) {
  if (*idx + 4 > len) return false;
  *out = ((uint32_t)buf[*idx]) | ((uint32_t)buf[*idx + 1] << 8) | ((uint32_t)buf[*idx + 2] << 16) |
         ((uint32_t)buf[*idx + 3] << 24);
  *idx += 4;
  return true;
}

static bool read_i16le(const uint8_t* buf, size_t len, size_t* idx, int16_t* out) {
  uint16_t u = 0;
  if (!read_u16le(buf, len, idx, &u)) return false;
  *out = (int16_t)u;
  return true;
}

static bool read_i32le(const uint8_t* buf, size_t len, size_t* idx, int32_t* out) {
  uint32_t u = 0;
  if (!read_u32le(buf, len, idx, &u)) return false;
  *out = (int32_t)u;
  return true;
}

static bool parse_canbc(const uint8_t* buf, size_t len, const uint8_t** payload, size_t* payload_len) {
  if (!buf || len < 6 + 2 + 4) return false;
  if (buf[0] != 'C' || buf[1] != 'A' || buf[2] != 'N' || buf[3] != 'B' || buf[4] != 'C' || buf[5] != 0) return false;
  size_t idx = 6;
  uint16_t ver = 0;
  uint32_t plen = 0;
  if (!read_u16le(buf, len, &idx, &ver)) return false;
  if (!read_u32le(buf, len, &idx, &plen)) return false;
  if (ver != 1) return false;
  if (idx + (size_t)plen > len) return false;
  *payload = buf + idx;
  *payload_len = (size_t)plen;
  return true;
}

typedef struct {
  bool used;
  canisa_poly_f2_t poly;
} slot_t;

static bool handle_ok(uint16_t h) { return h < CANISA_MVP_MAX_HANDLES; }

static void slot_clear(slot_t slots[CANISA_MVP_MAX_HANDLES]) {
  for (size_t i = 0; i < CANISA_MVP_MAX_HANDLES; i++) {
    slots[i].used = false;
    canisa_poly_zero(&slots[i].poly);
  }
}

static bool slot_set(slot_t slots[CANISA_MVP_MAX_HANDLES], uint16_t h, const canisa_poly_f2_t* v) {
  if (!handle_ok(h) || !v) return false;
  slots[h].used = true;
  slots[h].poly = *v;
  return true;
}

static bool slot_get(const slot_t slots[CANISA_MVP_MAX_HANDLES], uint16_t h, canisa_poly_f2_t* out) {
  if (!handle_ok(h) || !out) return false;
  if (!slots[h].used) return false;
  *out = slots[h].poly;
  return true;
}

bool canisa_mvp_run_canbc(const uint8_t* canbc, size_t canbc_len, canisa_mvp_result_t* out) {
  if (!out) return false;
  memset(out, 0, sizeof(*out));
  out->ok = false;

  const uint8_t* payload = NULL;
  size_t payload_len = 0;
  if (!parse_canbc(canbc, canbc_len, &payload, &payload_len)) return false;

  bool mode_f2 = false;

  // IMPORTANT: Do NOT allocate these on the stack; it can overflow the default
  // ESP-IDF task stack and cause resets. Keep them in static storage (BSS).
  static slot_t heap[CANISA_MVP_MAX_HANDLES];
  slot_clear(heap);

  canisa_poly_f2_t state;
  canisa_poly_zero(&state);

  size_t idx = 0;
  while (idx < payload_len) {
    uint8_t op = 0;
    if (!read_u8(payload, payload_len, &idx, &op)) break;
    out->events++;

    if (op == OP_NOP) continue;
    if (op == OP_HALT) break;

    if (op == OP_TRAP) {
      uint16_t code = 0;
      if (!read_u16le(payload, payload_len, &idx, &code)) return false;
      (void)code;
      return false;
    }

    if (op == OP_DEF_MOD) {
      uint8_t mode = 0;
      uint32_t p = 0;
      if (!read_u8(payload, payload_len, &idx, &mode)) return false;
      if (!read_u32le(payload, payload_len, &idx, &p)) return false;
      if (mode != 0) return false;
      // p is included for spec completeness; for MVP we require p==2.
      if (p != 2) return false;
      mode_f2 = true;
      continue;
    }

    if (!mode_f2) return false;

    if (op == OP_TERM_NEW) {
      uint16_t dst = 0;
      int32_t coeff = 0;
      int16_t exp2 = 0;
      if (!read_u16le(payload, payload_len, &idx, &dst)) return false;
      if (!read_i32le(payload, payload_len, &idx, &coeff)) return false;
      if (!read_i16le(payload, payload_len, &idx, &exp2)) return false;

      canisa_poly_f2_t term;
      canisa_poly_zero(&term);
      if ((coeff & 1) != 0) canisa_poly_set_deg(&term, 0);

      if (exp2 > 0) {
        canisa_poly_f2_t tmp;
        if (!canisa_poly_shift_left(&tmp, &term, (uint16_t)exp2)) return false;
        term = tmp;
      } else if (exp2 < 0) {
        canisa_poly_f2_t tmp;
        canisa_poly_shift_right(&tmp, &term, (uint16_t)(-exp2));
        term = tmp;
      }
      if (!slot_set(heap, dst, &term)) return false;
      continue;
    }

    if (op == OP_TERM_SET_VAR || op == OP_TERM_CLR_VAR) {
      uint16_t term_h = 0;
      uint16_t feat_id = 0;
      if (!read_u16le(payload, payload_len, &idx, &term_h)) return false;
      if (!read_u16le(payload, payload_len, &idx, &feat_id)) return false;
      canisa_poly_f2_t term;
      if (!slot_get(heap, term_h, &term)) return false;
      bool ok = (op == OP_TERM_SET_VAR) ? canisa_poly_set_deg(&term, feat_id) : canisa_poly_clear_deg(&term, feat_id);
      if (!ok) return false;
      if (!slot_set(heap, term_h, &term)) return false;
      continue;
    }

    if (op == OP_TERM_ZERO) {
      uint16_t term_h = 0;
      if (!read_u16le(payload, payload_len, &idx, &term_h)) return false;
      canisa_poly_f2_t z;
      canisa_poly_zero(&z);
      if (!slot_set(heap, term_h, &z)) return false;
      continue;
    }

    if (op == OP_STATE_CLEAR) {
      canisa_poly_zero(&state);
      continue;
    }

    if (op == OP_STATE_ADD) {
      uint16_t term_h = 0;
      if (!read_u16le(payload, payload_len, &idx, &term_h)) return false;
      canisa_poly_f2_t t;
      if (!slot_get(heap, term_h, &t)) return false;
      canisa_poly_xor(&state, &t);
      continue;
    }

    if (op == OP_STATE_COPY) {
      uint16_t dst = 0, src = 0;
      if (!read_u16le(payload, payload_len, &idx, &dst)) return false;
      if (!read_u16le(payload, payload_len, &idx, &src)) return false;

      if (src == 0) {
        if (!slot_set(heap, dst, &state)) return false;
      } else if (dst == 0) {
        canisa_poly_f2_t s;
        if (!slot_get(heap, src, &s)) return false;
        state = s;
      } else {
        canisa_poly_f2_t s;
        if (!slot_get(heap, src, &s)) return false;
        if (!slot_set(heap, dst, &s)) return false;
      }
      continue;
    }

    if (op == OP_STATE_NORM) {
      uint8_t m = 0;
      if (!read_u8(payload, payload_len, &idx, &m)) return false;
      (void)m;
      // canonical trim is implicit in bitset representation; nothing required here.
      continue;
    }

    if (op == OP_STATE_GCD || op == OP_STATE_LCM) {
      uint16_t src = 0;
      if (!read_u16le(payload, payload_len, &idx, &src)) return false;
      canisa_poly_f2_t s;
      if (!slot_get(heap, src, &s)) return false;
      if (op == OP_STATE_GCD) {
        canisa_poly_f2_t g;
        canisa_poly_gcd(&g, &state, &s);
        state = g;
      } else {
        canisa_poly_f2_t l;
        if (!canisa_poly_lcm(&l, &state, &s)) return false;
        state = l;
      }
      continue;
    }

    if (op == OP_STATE_HASH) {
      uint8_t algo = 0;
      uint16_t out_h = 0;
      if (!read_u8(payload, payload_len, &idx, &algo)) return false;
      if (!read_u16le(payload, payload_len, &idx, &out_h)) return false;
      if (algo != 1) return false;

      uint8_t canon[CANISA_MVP_MAX_CANON_BYTES];
      size_t canon_len = canisa_poly_write_canonical_bytes(canon, sizeof(canon), &state);
      if (!canon_len) return false;

      (void)out_h;
      sha256_prefix_hex(canon, canon_len, out->state_hash);
      continue;
    }

    if (op == OP_PROJ_FANO) {
      uint16_t out_h = 0;
      if (!read_u16le(payload, payload_len, &idx, &out_h)) return false;
      (void)out_h;
      fano_hash_from_state(&state, out->fano_hash);
      continue;
    }

    return false;
  }

  // If no explicit STATE_HASH ran, hash the final state anyway for reporting parity.
  if (out->state_hash[0] == 0) {
    uint8_t canon[CANISA_MVP_MAX_CANON_BYTES];
    size_t canon_len = canisa_poly_write_canonical_bytes(canon, sizeof(canon), &state);
    if (!canon_len) return false;
    sha256_prefix_hex(canon, canon_len, out->state_hash);
  }

  if (out->fano_hash[0] == 0) {
    // Always provide a projection hash (even if the program didn't call PROJ_FANO),
    // so embedded tests can compare projection deterministically.
    fano_hash_from_state(&state, out->fano_hash);
  }

  out->ok = true;
  return true;
}
