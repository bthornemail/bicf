#ifndef BICF_PROTO_H
#define BICF_PROTO_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// ESPNOW payload budget is ~250 bytes. Keep this conservative.
#define BICF_MAX_FRAME (240u)

typedef enum {
  BICF_ROLE_UNKNOWN = 0,
  BICF_ROLE_NRR = 1,     // Node A
  BICF_ROLE_VERIFY = 2,  // Node B
  BICF_ROLE_ORCH = 3,    // Node C (orchestrator)
} bicf_role_t;

typedef enum {
  // discovery
  BICF_CMD_DISCOVER_REQ = 0x01,
  BICF_CMD_DISCOVER_RESP = 0x02,

  // NRR service (A)
  BICF_CMD_APPEND_REQ = 0x10,
  BICF_CMD_APPEND_RESP = 0x11,
  BICF_CMD_RESET_REQ = 0x12,
  BICF_CMD_RESET_RESP = 0x13,
  BICF_CMD_REPLAY_REQ = 0x20,
  BICF_CMD_REPLAY_RESP = 0x21,

  // Verify service (B)
  BICF_CMD_VERIFY_REQ = 0x30,
  BICF_CMD_VERIFY_RESP = 0x31,
} bicf_cmd_t;

typedef struct __attribute__((packed)) {
  uint8_t magic[4];      // "BICF"
  uint8_t version;       // 1
  uint8_t cmd;           // bicf_cmd_t
  uint16_t flags_le;     // reserved (0)
  uint32_t seq_le;       // caller-chosen monotonically increasing sequence number
  uint32_t payload_len_le;
} bicf_frame_hdr_t;

// A frame on-the-wire is: hdr (16) | payload (N) | sha256(payload) (32).
// Hash covers payload bytes only; all other fields are authenticated by echoing them back.
typedef struct {
  bicf_frame_hdr_t hdr;
  const uint8_t* payload;
  uint32_t payload_len;
  uint8_t payload_sha256[32];
} bicf_frame_view_t;

bool bicf_sha256(const uint8_t* data, size_t len, uint8_t out32[32]);
void bicf_hex32(const uint8_t in32[32], char out65[65]);

// Encode: writes into `out` (<= BICF_MAX_FRAME). Returns total bytes or 0 on error.
size_t bicf_frame_encode(uint8_t cmd, uint32_t seq, const uint8_t* payload, uint32_t payload_len,
                         uint8_t* out, size_t out_cap);

// Decode: validates magic/version, bounds, and payload sha256.
bool bicf_frame_decode(const uint8_t* in, size_t in_len, bicf_frame_view_t* out);

static inline uint32_t bicf_le32(const void* p) {
  const uint8_t* b = (const uint8_t*)p;
  return ((uint32_t)b[0]) | ((uint32_t)b[1] << 8) | ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

static inline void bicf_put_le32(void* p, uint32_t v) {
  uint8_t* b = (uint8_t*)p;
  b[0] = (uint8_t)(v & 0xFF);
  b[1] = (uint8_t)((v >> 8) & 0xFF);
  b[2] = (uint8_t)((v >> 16) & 0xFF);
  b[3] = (uint8_t)((v >> 24) & 0xFF);
}

static inline void bicf_put_le16(void* p, uint16_t v) {
  uint8_t* b = (uint8_t*)p;
  b[0] = (uint8_t)(v & 0xFF);
  b[1] = (uint8_t)((v >> 8) & 0xFF);
}

#endif
