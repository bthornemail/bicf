#include "bicf_proto.h"

#include <string.h>

size_t bicf_frame_encode(uint8_t cmd, uint32_t seq, const uint8_t* payload, uint32_t payload_len, uint8_t* out,
                         size_t out_cap) {
  const size_t hdr_len = sizeof(bicf_frame_hdr_t);
  const size_t total = hdr_len + (size_t)payload_len + 32u;
  if (!out || out_cap < total) return 0;
  if (total > BICF_MAX_FRAME) return 0;
  if (payload_len > 0 && !payload) return 0;

  bicf_frame_hdr_t hdr;
  hdr.magic[0] = 'B';
  hdr.magic[1] = 'I';
  hdr.magic[2] = 'C';
  hdr.magic[3] = 'F';
  hdr.version = 1;
  hdr.cmd = cmd;
  bicf_put_le16(&hdr.flags_le, 0);
  bicf_put_le32(&hdr.seq_le, seq);
  bicf_put_le32(&hdr.payload_len_le, payload_len);

  memcpy(out, &hdr, hdr_len);
  if (payload_len > 0) memcpy(out + hdr_len, payload, payload_len);

  uint8_t h[32];
  if (!bicf_sha256(payload ? payload : (const uint8_t*)"", payload_len, h)) return 0;
  memcpy(out + hdr_len + payload_len, h, 32);
  return total;
}

bool bicf_frame_decode(const uint8_t* in, size_t in_len, bicf_frame_view_t* out) {
  if (!in || !out) return false;
  if (in_len < sizeof(bicf_frame_hdr_t) + 32u) return false;

  bicf_frame_hdr_t hdr;
  memcpy(&hdr, in, sizeof(hdr));

  if (!(hdr.magic[0] == 'B' && hdr.magic[1] == 'I' && hdr.magic[2] == 'C' && hdr.magic[3] == 'F')) return false;
  if (hdr.version != 1) return false;

  const uint32_t payload_len = bicf_le32(&hdr.payload_len_le);
  const size_t total = sizeof(bicf_frame_hdr_t) + (size_t)payload_len + 32u;
  if (total != in_len) return false;
  if (total > BICF_MAX_FRAME) return false;

  const uint8_t* payload = in + sizeof(bicf_frame_hdr_t);
  const uint8_t* mac = in + sizeof(bicf_frame_hdr_t) + payload_len;

  uint8_t h[32];
  if (!bicf_sha256(payload_len ? payload : (const uint8_t*)"", payload_len, h)) return false;
  if (memcmp(h, mac, 32) != 0) return false;

  out->hdr = hdr;
  out->payload = payload;
  out->payload_len = payload_len;
  memcpy(out->payload_sha256, h, 32);
  return true;
}

