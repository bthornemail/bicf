#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "esp_mac.h"
#include "esp_system.h"
#include "mbedtls/sha256.h"
#include "nvs.h"
#include "nvs_flash.h"

#include "bicf_espnow.h"
#include "bicf_jsonl.h"
#include "bicf_proto.h"
#include "clbc_vm.h"

// Node A: NRR service over ESPNOW.
// - APPEND: store CLBC bytes (as NVS blob) and append an entry to a small deterministic log
// - REPLAY: compute trace_id = sha256(concat(entry_sha256...)) and last VM transcript hash

#define NRR_NS "nrr"
#define NRR_MAX_ENTRIES 16

typedef struct __attribute__((packed)) {
  uint8_t sha256[32];
  uint32_t len_le;
} nrr_entry_t;

static uint8_t g_self_mac[6] = {0};
static bicf_event_ctx_t g_evt;

static bool nrr_load_log(nvs_handle_t h, nrr_entry_t* entries, uint32_t* count) {
  size_t sz = 0;
  esp_err_t err = nvs_get_blob(h, "log", NULL, &sz);
  if (err == ESP_ERR_NVS_NOT_FOUND) {
    *count = 0;
    return true;
  }
  if (err != ESP_OK) return false;
  if (sz % sizeof(nrr_entry_t) != 0) return false;
  uint32_t n = (uint32_t)(sz / sizeof(nrr_entry_t));
  if (n > NRR_MAX_ENTRIES) return false;
  if (n > 0) {
    if (nvs_get_blob(h, "log", entries, &sz) != ESP_OK) return false;
  }
  *count = n;
  return true;
}

static bool nrr_store_log(nvs_handle_t h, const nrr_entry_t* entries, uint32_t count) {
  if (count > NRR_MAX_ENTRIES) return false;
  const size_t sz = (size_t)count * sizeof(nrr_entry_t);
  if (nvs_set_blob(h, "log", entries, sz) != ESP_OK) return false;
  if (nvs_commit(h) != ESP_OK) return false;
  return true;
}

static bool nrr_reset(void) {
  nvs_handle_t h;
  if (nvs_open(NRR_NS, NVS_READWRITE, &h) != ESP_OK) return false;
  const esp_err_t e1 = nvs_erase_all(h);
  const esp_err_t e2 = nvs_commit(h);
  nvs_close(h);
  return (e1 == ESP_OK && e2 == ESP_OK);
}

static bool nrr_append_blob(const uint8_t* clbc, uint32_t len, uint8_t out_sha[32]) {
  if (!bicf_sha256(clbc, len, out_sha)) return false;

  nvs_handle_t h;
  if (nvs_open(NRR_NS, NVS_READWRITE, &h) != ESP_OK) return false;

  nrr_entry_t entries[NRR_MAX_ENTRIES];
  uint32_t count = 0;
  if (!nrr_load_log(h, entries, &count)) {
    nvs_close(h);
    return false;
  }
  if (count >= NRR_MAX_ENTRIES) {
    nvs_close(h);
    return false;
  }

  // Store blob under deterministic key "b<idx>".
  char key[16] = {0};
  snprintf(key, sizeof(key), "b%u", (unsigned)count);
  if (nvs_set_blob(h, key, clbc, len) != ESP_OK) {
    nvs_close(h);
    return false;
  }

  memcpy(entries[count].sha256, out_sha, 32);
  bicf_put_le32(&entries[count].len_le, len);
  count++;

  const bool ok = nrr_store_log(h, entries, count);
  nvs_close(h);
  return ok;
}

static bool nrr_replay(uint8_t out_trace_id[32], uint8_t out_last_vm[32], uint32_t* out_count) {
  nvs_handle_t h;
  if (nvs_open(NRR_NS, NVS_READONLY, &h) != ESP_OK) return false;

  nrr_entry_t entries[NRR_MAX_ENTRIES];
  uint32_t count = 0;
  if (!nrr_load_log(h, entries, &count)) {
    nvs_close(h);
    return false;
  }

  // trace_id = sha256(concat(entry_sha256[i])) in log order.
  mbedtls_sha256_context sha;
  mbedtls_sha256_init(&sha);
  mbedtls_sha256_starts(&sha, 0);
  for (uint32_t i = 0; i < count; i++) {
    mbedtls_sha256_update(&sha, entries[i].sha256, 32);
  }
  mbedtls_sha256_finish(&sha, out_trace_id);
  mbedtls_sha256_free(&sha);

  memset(out_last_vm, 0, 32);
  if (count > 0) {
    char key[16] = {0};
    snprintf(key, sizeof(key), "b%u", (unsigned)(count - 1));
    uint8_t clbc[256];
    size_t sz = sizeof(clbc);
    if (nvs_get_blob(h, key, clbc, &sz) == ESP_OK) {
      clbc_vm_result_t r = {0};
      if (clbc_vm_run(clbc, sz, &r) && r.ok) memcpy(out_last_vm, r.transcript_sha256, 32);
    }
  }

  nvs_close(h);
  *out_count = count;
  return true;
}

static void handle_frame(const uint8_t src_mac[6], const bicf_frame_view_t* f) {
  const uint8_t broadcast[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff};

  const uint32_t seq = bicf_le32(&f->hdr.seq_le);
  const uint8_t cmd = f->hdr.cmd;

  uint8_t tx[BICF_MAX_FRAME];
  size_t tx_len = 0;

  if (cmd == BICF_CMD_DISCOVER_REQ) {
    uint8_t zero[32] = {0};
    (void)bicf_jsonl_emit_rpc(&g_evt, 'A', "rpc", "bicf/discover/resp", zero, f->payload_sha256,
                              ",\"cmd\":\"DISCOVER_REQ\",\"ok\":1");
    uint8_t payload[2] = {BICF_ROLE_NRR, 0};
    tx_len = bicf_frame_encode(BICF_CMD_DISCOVER_RESP, seq, payload, sizeof(payload), tx, sizeof(tx));
    bicf_espnow_add_peer(src_mac);
    if (tx_len) (void)bicf_espnow_send(src_mac, tx, (int)tx_len);
    return;
  }

  if (cmd == BICF_CMD_APPEND_REQ) {
    uint8_t sha[32];
    bool ok = nrr_append_blob(f->payload, f->payload_len, sha);
    uint8_t trace_anchor[32] = {0};
    // For append, trace anchor is the appended rid (sha256(CLBC_bytes)).
    memcpy(trace_anchor, sha, 32);
    (void)bicf_jsonl_emit_rpc(&g_evt, 'A', "rpc", "bicf/nrr/append", trace_anchor, f->payload_sha256,
                              ok ? ",\"cmd\":\"APPEND_REQ\",\"ok\":1" : ",\"cmd\":\"APPEND_REQ\",\"ok\":0");
    uint8_t payload[1 + 32];
    payload[0] = ok ? 1 : 0;
    memcpy(payload + 1, sha, 32);
    tx_len = bicf_frame_encode(BICF_CMD_APPEND_RESP, seq, payload, sizeof(payload), tx, sizeof(tx));
    bicf_espnow_add_peer(src_mac);
    if (tx_len) (void)bicf_espnow_send(src_mac, tx, (int)tx_len);
    return;
  }

  if (cmd == BICF_CMD_RESET_REQ) {
    const bool ok = nrr_reset();
    uint8_t zero[32] = {0};
    (void)bicf_jsonl_emit_rpc(&g_evt, 'A', "rpc", "bicf/nrr/reset", zero, f->payload_sha256,
                              ok ? ",\"cmd\":\"RESET_REQ\",\"ok\":1" : ",\"cmd\":\"RESET_REQ\",\"ok\":0");
    uint8_t payload[1] = {ok ? 1 : 0};
    tx_len = bicf_frame_encode(BICF_CMD_RESET_RESP, seq, payload, sizeof(payload), tx, sizeof(tx));
    bicf_espnow_add_peer(src_mac);
    if (tx_len) (void)bicf_espnow_send(src_mac, tx, (int)tx_len);
    return;
  }

  if (cmd == BICF_CMD_REPLAY_REQ) {
    uint8_t trace_id[32];
    uint8_t last_vm[32];
    uint32_t count = 0;
    bool ok = nrr_replay(trace_id, last_vm, &count);
    (void)bicf_jsonl_emit_rpc(&g_evt, 'A', "rpc", "bicf/nrr/replay", trace_id, f->payload_sha256,
                              ok ? ",\"cmd\":\"REPLAY_REQ\",\"ok\":1" : ",\"cmd\":\"REPLAY_REQ\",\"ok\":0");
    uint8_t payload[1 + 4 + 32 + 32];
    payload[0] = ok ? 1 : 0;
    bicf_put_le32(payload + 1, count);
    memcpy(payload + 5, trace_id, 32);
    memcpy(payload + 37, last_vm, 32);
    tx_len = bicf_frame_encode(BICF_CMD_REPLAY_RESP, seq, payload, sizeof(payload), tx, sizeof(tx));
    bicf_espnow_add_peer(src_mac);
    if (tx_len) (void)bicf_espnow_send(src_mac, tx, (int)tx_len);
    return;
  }

  // ignore others
  (void)broadcast;
}

static void rx_cb(const uint8_t src_mac[6], const uint8_t* data, int len) {
  bicf_frame_view_t f;
  if (!bicf_frame_decode(data, (size_t)len, &f)) return;
  handle_frame(src_mac, &f);
}

void app_main(void) {
  esp_read_mac(g_self_mac, ESP_MAC_WIFI_STA);
  char macs[18];
  bicf_mac_to_str(g_self_mac, macs);
  printf("ROLE=A(NRR)\n");
  printf("MAC=%s\n", macs);

  bicf_event_ctx_init(&g_evt);
  uint8_t zero[32] = {0};
  uint8_t mac_hash[32];
  (void)bicf_sha256(g_self_mac, 6, mac_hash);
  (void)bicf_jsonl_emit_rpc(&g_evt, 'A', "state", "bicf/boot", zero, mac_hash, ",\"role\":\"NRR\"");

  ESP_ERROR_CHECK(bicf_espnow_init(rx_cb));
}
