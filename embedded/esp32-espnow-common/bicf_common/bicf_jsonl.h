#ifndef BICF_JSONL_H
#define BICF_JSONL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Deterministic JSONL emission for the demo bridge/visualizer.
// This is not a general JSON library; it prints a fixed schema in a fixed key order.
//
// 12D–15D envelope (deps-size-3):
//   deps[0] = prev_state
//   deps[1] = trace_anchor
//   deps[2] = content_anchor
//
// mkey format:
//   mkey = "rpc/" + method_name + "@schema/" + schema_id

typedef struct {
  uint32_t seq;
  uint8_t state_id[32];  // current state head (sha256 bytes)
} bicf_event_ctx_t;

// Returns a stable schema_id string for the envelope, e.g. "sha256:abcd...".
// out must have capacity >= 72.
void bicf_schema_id_envelope(char out72[72]);

void bicf_event_ctx_init(bicf_event_ctx_t* ctx);

// Emit one JSON object line with:
//   node, seq, type, mkey, schema_id, deps[3], state_id
// plus an optional suffix (must start with ',' and contain valid JSON key/value pairs).
//
// - `method_name` becomes part of mkey ("rpc/<method_name>@schema/<schema_id>").
// - `trace_anchor32` and `content_anchor32` are raw sha256 bytes.
// - deps[0] (prev_state) uses ctx->state_id before update.
// - state_id is updated deterministically after emission.
bool bicf_jsonl_emit_rpc(bicf_event_ctx_t* ctx, char node, const char* type, const char* method_name,
                         const uint8_t trace_anchor32[32], const uint8_t content_anchor32[32],
                         const char* extra_json_suffix);

// Helper: prints a "sha256:<hex>" string for a 32-byte hash.
void bicf_sha256_prefixed(const uint8_t in32[32], char out72[72]);

#endif

