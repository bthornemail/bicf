#include "clbc_vm.h"

#include <string.h>

#include "mbedtls/sha256.h"

enum {
  OP_BEGIN_RECORD = 0xF0,
  OP_END_RECORD = 0xF1,

  OP_CTX_BEGIN = 0x10,
  OP_CTX_META = 0x11,
  OP_VTX_DEF = 0x12,
  OP_EDGE_DEF = 0x13,
  OP_FACE_DEF = 0x14,
  OP_KEY_DEF = 0x15,
  OP_CTX_END = 0x16,

  OP_APPLY_BEGIN = 0x20,
  OP_APPLY_COEFF_REF = 0x21,
  OP_APPLY_VARS = 0x22,
  OP_APPLY_OUT = 0x23,
  OP_APPLY_END = 0x24,

  OP_CHECKS = 0x30,
  OP_RESULT = 0x31,
  OP_HASH = 0x32,

  OP_PROJ_BEGIN = 0x40,
  OP_PROJ_INPUT = 0x41,
  OP_PROJ_POINTS = 0x42,
  OP_PROJ_LINES = 0x43,
  OP_PROJ_END = 0x44,

  OP_COMMIT = 0x50,
};

static bool read_u8(const uint8_t* buf, size_t len, size_t* idx, uint8_t* out) {
  if (*idx >= len) return false;
  *out = buf[*idx];
  *idx += 1;
  return true;
}

static bool read_u32le(const uint8_t* buf, size_t len, size_t* idx, uint32_t* out) {
  if (*idx + 4 > len) return false;
  *out = ((uint32_t)buf[*idx]) | ((uint32_t)buf[*idx + 1] << 8) | ((uint32_t)buf[*idx + 2] << 16) |
         ((uint32_t)buf[*idx + 3] << 24);
  *idx += 4;
  return true;
}

static bool uleb128_decode_u64(const uint8_t* buf, size_t len, size_t* idx, uint64_t* out) {
  uint64_t value = 0;
  uint32_t shift = 0;
  for (uint32_t i = 0; i < 10; i++) {
    uint8_t byte = 0;
    if (!read_u8(buf, len, idx, &byte)) return false;
    value |= ((uint64_t)(byte & 0x7F)) << shift;
    if ((byte & 0x80) == 0) {
      *out = value;
      return true;
    }
    shift += 7;
  }
  return false;
}

static size_t uleb128_encode_u64(uint64_t v, uint8_t out[10]) {
  size_t n = 0;
  do {
    uint8_t byte = (uint8_t)(v & 0x7F);
    v >>= 7;
    if (v != 0) byte |= 0x80;
    out[n++] = byte;
  } while (v != 0 && n < 10);
  return n;
}

static void emit_u8(mbedtls_sha256_context* ctx, uint8_t b) { mbedtls_sha256_update(ctx, &b, 1); }

static void emit_uleb(mbedtls_sha256_context* ctx, uint64_t v) {
  uint8_t tmp[10];
  size_t n = uleb128_encode_u64(v, tmp);
  mbedtls_sha256_update(ctx, tmp, n);
}

static bool consume_value_payload(const uint8_t* rs, size_t rs_len, size_t* idx, uint8_t vtype,
                                  mbedtls_sha256_context* sha) {
  if (vtype == 0) return true;
  if (vtype == 1) {
    if (*idx + 1 > rs_len) return false;
    mbedtls_sha256_update(sha, rs + *idx, 1);
    *idx += 1;
    return true;
  }
  if (vtype == 3 || vtype == 4) {
    uint64_t val = 0;
    if (!uleb128_decode_u64(rs, rs_len, idx, &val)) return false;
    emit_uleb(sha, val);
    return true;
  }
  if (vtype == 5) {
    uint64_t n = 0;
    if (!uleb128_decode_u64(rs, rs_len, idx, &n)) return false;
    emit_uleb(sha, n);
    if (n > (uint64_t)(rs_len - *idx)) return false;
    mbedtls_sha256_update(sha, rs + *idx, (size_t)n);
    *idx += (size_t)n;
    return true;
  }
  if (vtype == 6) {
    if (*idx + 4 > rs_len) return false;
    mbedtls_sha256_update(sha, rs + *idx, 4);
    *idx += 4;
    return true;
  }
  return true;
}

static bool run_record_stream(const uint8_t* rs, size_t rs_len, clbc_vm_result_t* out, mbedtls_sha256_context* sha) {
  size_t idx = 0;
  uint32_t events = 0;

  while (idx < rs_len) {
    uint8_t op = rs[idx];
    switch (op) {
      case OP_BEGIN_RECORD: {
        idx++;
        uint8_t kind = 0;
        if (!read_u8(rs, rs_len, &idx, &kind)) return false;
        uint64_t phase = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &phase)) return false;
        emit_u8(sha, OP_BEGIN_RECORD);
        emit_u8(sha, kind);
        emit_uleb(sha, phase);
        events++;
        break;
      }
      case OP_END_RECORD:
        idx++;
        emit_u8(sha, OP_END_RECORD);
        events++;
        break;

      case OP_CHECKS: {
        idx++;
        uint64_t n = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &n)) return false;
        if (n > (uint64_t)(rs_len - idx)) return false;
        emit_u8(sha, OP_CHECKS);
        emit_uleb(sha, n);
        mbedtls_sha256_update(sha, rs + idx, (size_t)n);
        idx += (size_t)n;
        events++;
        break;
      }
      case OP_RESULT:
        idx++;
        if (idx + 1 > rs_len) return false;
        emit_u8(sha, OP_RESULT);
        emit_u8(sha, rs[idx]);
        idx++;
        events++;
        break;
      case OP_HASH: {
        idx++;
        uint64_t sid = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &sid)) return false;
        emit_u8(sha, OP_HASH);
        emit_uleb(sha, sid);
        events++;
        break;
      }

      case OP_CTX_BEGIN: {
        idx++;
        uint64_t cid = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &cid)) return false;
        emit_u8(sha, OP_CTX_BEGIN);
        emit_uleb(sha, cid);
        events++;
        break;
      }
      case OP_CTX_META: {
        idx++;
        uint64_t complexity = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &complexity)) return false;
        if (idx + 1 > rs_len) return false;
        uint8_t shape = rs[idx++];
        emit_u8(sha, OP_CTX_META);
        emit_uleb(sha, complexity);
        emit_u8(sha, shape);
        events++;
        break;
      }
      case OP_VTX_DEF: {
        idx++;
        uint64_t vid = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &vid)) return false;
        if (idx + 4 > rs_len) return false;
        uint8_t role = rs[idx++], basis = rs[idx++], optional = rs[idx++], vtype = rs[idx++];
        emit_u8(sha, OP_VTX_DEF);
        emit_uleb(sha, vid);
        emit_u8(sha, role);
        emit_u8(sha, basis);
        emit_u8(sha, optional);
        emit_u8(sha, vtype);
        if (!consume_value_payload(rs, rs_len, &idx, vtype, sha)) return false;
        events++;
        break;
      }
      case OP_EDGE_DEF: {
        idx++;
        uint64_t from = 0, to = 0, sid = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &from)) return false;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &to)) return false;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &sid)) return false;
        if (idx + 1 > rs_len) return false;
        uint8_t wtype = rs[idx++];
        emit_u8(sha, OP_EDGE_DEF);
        emit_uleb(sha, from);
        emit_uleb(sha, to);
        emit_uleb(sha, sid);
        emit_u8(sha, wtype);
        if (!consume_value_payload(rs, rs_len, &idx, wtype, sha)) return false;
        events++;
        break;
      }
      case OP_FACE_DEF: {
        idx++;
        uint64_t a = 0, b = 0, c = 0, sid = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &a)) return false;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &b)) return false;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &c)) return false;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &sid)) return false;
        emit_u8(sha, OP_FACE_DEF);
        emit_uleb(sha, a);
        emit_uleb(sha, b);
        emit_uleb(sha, c);
        emit_uleb(sha, sid);
        events++;
        break;
      }
      case OP_KEY_DEF: {
        idx++;
        uint64_t kid = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &kid)) return false;
        if (idx + 2 > rs_len) return false;
        uint8_t auth = rs[idx++], mut = rs[idx++];
        emit_u8(sha, OP_KEY_DEF);
        emit_uleb(sha, kid);
        emit_u8(sha, auth);
        emit_u8(sha, mut);
        events++;
        break;
      }
      case OP_CTX_END:
        idx++;
        emit_u8(sha, OP_CTX_END);
        events++;
        break;

      case OP_APPLY_BEGIN:
        idx++;
        if (idx + 1 > rs_len) return false;
        emit_u8(sha, OP_APPLY_BEGIN);
        emit_u8(sha, rs[idx++]);
        events++;
        break;
      case OP_APPLY_COEFF_REF: {
        idx++;
        uint64_t sid = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &sid)) return false;
        emit_u8(sha, OP_APPLY_COEFF_REF);
        emit_uleb(sha, sid);
        events++;
        break;
      }
      case OP_APPLY_VARS: {
        idx++;
        uint64_t n = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &n)) return false;
        emit_u8(sha, OP_APPLY_VARS);
        emit_uleb(sha, n);
        for (uint64_t i = 0; i < n; i++) {
          uint64_t vid = 0;
          if (!uleb128_decode_u64(rs, rs_len, &idx, &vid)) return false;
          emit_uleb(sha, vid);
        }
        events++;
        break;
      }
      case OP_APPLY_OUT: {
        idx++;
        uint64_t vid = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &vid)) return false;
        emit_u8(sha, OP_APPLY_OUT);
        emit_uleb(sha, vid);
        events++;
        break;
      }
      case OP_APPLY_END:
        idx++;
        emit_u8(sha, OP_APPLY_END);
        events++;
        break;

      case OP_PROJ_BEGIN:
        idx++;
        if (idx + 1 > rs_len) return false;
        emit_u8(sha, OP_PROJ_BEGIN);
        emit_u8(sha, rs[idx++]);
        events++;
        break;
      case OP_PROJ_INPUT: {
        idx++;
        uint64_t cid = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &cid)) return false;
        emit_u8(sha, OP_PROJ_INPUT);
        emit_uleb(sha, cid);
        events++;
        break;
      }
      case OP_PROJ_POINTS: {
        idx++;
        uint64_t n = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &n)) return false;
        if (n > (uint64_t)(rs_len - idx)) return false;
        emit_u8(sha, OP_PROJ_POINTS);
        emit_uleb(sha, n);
        mbedtls_sha256_update(sha, rs + idx, (size_t)n);
        idx += (size_t)n;
        events++;
        break;
      }
      case OP_PROJ_LINES: {
        idx++;
        uint64_t n = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &n)) return false;
        uint64_t bytes = n * 3;
        if (bytes > (uint64_t)(rs_len - idx)) return false;
        emit_u8(sha, OP_PROJ_LINES);
        emit_uleb(sha, n);
        mbedtls_sha256_update(sha, rs + idx, (size_t)bytes);
        idx += (size_t)bytes;
        events++;
        break;
      }
      case OP_PROJ_END:
        idx++;
        emit_u8(sha, OP_PROJ_END);
        events++;
        break;

      case OP_COMMIT: {
        idx++;
        uint64_t sid1 = 0, sid2 = 0, sid3 = 0;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &sid1)) return false;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &sid2)) return false;
        if (!uleb128_decode_u64(rs, rs_len, &idx, &sid3)) return false;
        if (idx + 8 > rs_len) return false;
        emit_u8(sha, OP_COMMIT);
        emit_uleb(sha, sid1);
        emit_uleb(sha, sid2);
        emit_uleb(sha, sid3);
        mbedtls_sha256_update(sha, rs + idx, 8);
        idx += 8;
        events++;
        break;
      }

      default:
        out->events = events;
        return false;
    }
  }

  out->events = events;
  return true;
}

bool clbc_vm_run(const uint8_t* clbc, size_t clbc_len, clbc_vm_result_t* out) {
  if (!clbc || !out) return false;
  memset(out, 0, sizeof(*out));

  if (clbc_len < 14) return false;
  if (!(clbc[0] == 'C' && clbc[1] == 'L' && clbc[2] == 'B' && clbc[3] == 'C')) return false;
  if (clbc[4] != 1) return false;

  size_t idx = 5;
  uint8_t flags = 0;
  if (!read_u8(clbc, clbc_len, &idx, &flags)) return false;
  uint32_t record_count = 0;
  if (!read_u32le(clbc, clbc_len, &idx, &record_count)) return false;
  uint32_t st_len = 0;
  if (!read_u32le(clbc, clbc_len, &idx, &st_len)) return false;
  (void)flags;
  (void)record_count;

  if (idx + st_len > clbc_len) return false;
  idx += st_len;
  const uint8_t* rs = clbc + idx;
  const size_t rs_len = clbc_len - idx;

  mbedtls_sha256_context sha;
  mbedtls_sha256_init(&sha);
  mbedtls_sha256_starts(&sha, 0);

  const bool ok = run_record_stream(rs, rs_len, out, &sha);
  mbedtls_sha256_finish(&sha, out->transcript_sha256);
  mbedtls_sha256_free(&sha);

  out->ok = ok;
  return true;
}

