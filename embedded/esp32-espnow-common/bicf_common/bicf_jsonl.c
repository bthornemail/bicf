#include "bicf_jsonl.h"

#include <inttypes.h>
#include <stdio.h>
#include <string.h>

#include "bicf_proto.h"

static const char* k_schema_bytes =
    "{\"schema\":\"bicf-envelope@v1\","
    "\"fields\":[\"node\",\"seq\",\"type\",\"mkey\",\"schema_id\",\"deps\",\"state_id\"],"
    "\"deps\":[\"prev_state\",\"trace_anchor\",\"content_anchor\"],"
    "\"mkey\":\"rpc/<method>@schema/<schema_id>\"}";

void bicf_sha256_prefixed(const uint8_t in32[32], char out72[72]) {
  char hex[65];
  bicf_hex32(in32, hex);
  strcpy(out72, "sha256:");
  strcat(out72, hex);
}

void bicf_schema_id_envelope(char out72[72]) {
  uint8_t h[32];
  (void)bicf_sha256((const uint8_t*)k_schema_bytes, strlen(k_schema_bytes), h);
  bicf_sha256_prefixed(h, out72);
}

void bicf_event_ctx_init(bicf_event_ctx_t* ctx) {
  if (!ctx) return;
  ctx->seq = 0;
  memset(ctx->state_id, 0, 32);  // genesis state (all-zero bytes)
}

static void state_update(uint8_t out32[32], const uint8_t prev_state32[32], const uint8_t trace_anchor32[32],
                         const uint8_t content_anchor32[32], char node, uint32_t seq) {
  // state_id = sha256("STATEv1" || prev_state || trace_anchor || content_anchor || node || seq_le)
  uint8_t buf[6 + 32 + 32 + 32 + 1 + 4];
  memcpy(buf, "STATEv1", 6);
  memcpy(buf + 6, prev_state32, 32);
  memcpy(buf + 38, trace_anchor32, 32);
  memcpy(buf + 70, content_anchor32, 32);
  buf[102] = (uint8_t)node;
  bicf_put_le32(buf + 103, seq);
  (void)bicf_sha256(buf, sizeof(buf), out32);
}

bool bicf_jsonl_emit_rpc(bicf_event_ctx_t* ctx, char node, const char* type, const char* method_name,
                         const uint8_t trace_anchor32[32], const uint8_t content_anchor32[32],
                         const char* extra_json_suffix) {
  if (!ctx || !type || !method_name || !trace_anchor32 || !content_anchor32) return false;
  if (extra_json_suffix && extra_json_suffix[0] != ',') return false;

  char schema_id[72];
  bicf_schema_id_envelope(schema_id);

  char prev_state[72];
  char trace_anchor[72];
  char content_anchor[72];
  bicf_sha256_prefixed(ctx->state_id, prev_state);
  bicf_sha256_prefixed(trace_anchor32, trace_anchor);
  bicf_sha256_prefixed(content_anchor32, content_anchor);

  char mkey[220];
  // mkey = "rpc/" + method_name + "@schema/" + schema_id
  snprintf(mkey, sizeof(mkey), "rpc/%s@schema/%s", method_name, schema_id);

  uint8_t new_state32[32];
  state_update(new_state32, ctx->state_id, trace_anchor32, content_anchor32, node, ctx->seq);
  char state_id[72];
  bicf_sha256_prefixed(new_state32, state_id);

  // Fixed key order for determinism.
  // Note: `extra_json_suffix` is appended at the end.
  printf("{\"node\":\"%c\",\"seq\":%" PRIu32 ",\"type\":\"%s\",\"mkey\":\"%s\",\"schema_id\":\"%s\","
         "\"deps\":[\"%s\",\"%s\",\"%s\"],\"state_id\":\"%s\"%s}\n",
         node, ctx->seq, type, mkey, schema_id, prev_state, trace_anchor, content_anchor, state_id,
         extra_json_suffix ? extra_json_suffix : "");

  memcpy(ctx->state_id, new_state32, 32);
  ctx->seq++;
  return true;
}

