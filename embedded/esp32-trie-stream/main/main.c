#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "esp_mac.h"

#include "bicf_espnow.h"
#include "bicf_proto.h"
#include "bicf_trie.h"

// Demo: build a semantic trie keyed by:
//   mkey = "rpc/" + method_name + "@schema/" + schema_id
//
// Associate each mkey with a canonical event identity:
//   rid = sha256(CLBC_bytes)
//
// Then compute two deterministic "streams" (chirality):
//   LEFT  = traverse trie children ascending
//   RIGHT = traverse trie children descending
//
// stream_id = sha256(concat(emitted rid bytes))

static void sha32_hex(const uint8_t in32[32], char out65[65]) { bicf_hex32(in32, out65); }

static void sha32_prefixed(char out_schema_id[72], const uint8_t in32[32]) {
  char hex[65];
  sha32_hex(in32, hex);
  // "sha256:" + 64 hex + '\0' = 71
  strcpy(out_schema_id, "sha256:");
  strcat(out_schema_id, hex);
}

static void make_mkey(char* out, size_t out_cap, const char* method_name, const char* schema_id) {
  // mkey = "rpc/" + method_name + "@schema/" + schema_id
  snprintf(out, out_cap, "rpc/%s@schema/%s", method_name, schema_id);
}

static void demo_insert(bicf_trie_t* t, const char* method_name, const char* schema_id, const uint8_t clbc_bytes[],
                        size_t clbc_len) {
  uint8_t rid[32];
  bicf_sha256(clbc_bytes, clbc_len, rid);

  char mkey[196];
  make_mkey(mkey, sizeof(mkey), method_name, schema_id);
  (void)bicf_trie_insert(t, (const uint8_t*)mkey, strlen(mkey), rid);

  char rid_hex[65];
  sha32_hex(rid, rid_hex);
  printf("mkey=%s\n", mkey);
  printf("rid=%s\n", rid_hex);
}

void app_main(void) {
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  char macs[18];
  bicf_mac_to_str(mac, macs);
  printf("ROLE=TRIE_STREAM\n");
  printf("MAC=%s\n", macs);

  // Schema id derived from canonical schema bytes (demo uses a fixed string).
  static const char schema_bytes[] =
      "{\"schema\":\"rpc-method@v1\",\"fields\":[\"method\",\"schema_id\",\"deps\",\"content_anchor\"]}";
  uint8_t schema_hash[32];
  bicf_sha256((const uint8_t*)schema_bytes, strlen(schema_bytes), schema_hash);
  char schema_id[72];
  sha32_prefixed(schema_id, schema_hash);
  printf("schema_id=%s\n", schema_id);

  bicf_trie_t t = bicf_trie_create();

  // Minimal distinct CLBC blobs for stable rids (demo-only).
  static const uint8_t clbc1[] = {0x43, 0x4c, 0x42, 0x43, 0x01, 0x00, 0x00, 0x00};
  static const uint8_t clbc2[] = {0x43, 0x4c, 0x42, 0x43, 0x01, 0x00, 0x01, 0x00};
  static const uint8_t clbc3[] = {0x43, 0x4c, 0x42, 0x43, 0x01, 0x00, 0x02, 0x00};
  static const uint8_t clbc4[] = {0x43, 0x4c, 0x42, 0x43, 0x01, 0x00, 0x03, 0x00};

  // Use RPC method names as semantic keys (demo uses CanvasL/LSP-like names).
  demo_insert(&t, "canvasl/getScene", schema_id, clbc1, sizeof(clbc1));
  demo_insert(&t, "canvasl/getTrace", schema_id, clbc2, sizeof(clbc2));
  demo_insert(&t, "canvasl/getIncidence", schema_id, clbc3, sizeof(clbc3));
  demo_insert(&t, "textDocument/hover", schema_id, clbc4, sizeof(clbc4));

  uint8_t left_id[32];
  uint8_t right_id[32];
  bicf_trie_stream_id(&t, BICF_STREAM_LEFT, left_id);
  bicf_trie_stream_id(&t, BICF_STREAM_RIGHT, right_id);

  char left_hex[65];
  char right_hex[65];
  sha32_hex(left_id, left_hex);
  sha32_hex(right_id, right_hex);
  printf("STREAM_LEFT_SHA256=%s\n", left_hex);
  printf("STREAM_RIGHT_SHA256=%s\n", right_hex);

  bicf_trie_free(&t);
}
