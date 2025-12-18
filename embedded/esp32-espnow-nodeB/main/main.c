#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "esp_mac.h"

#include "bicf_espnow.h"
#include "bicf_jsonl.h"
#include "bicf_proto.h"
#include "clbc_vm.h"

static uint8_t g_self_mac[6] = {0};
static bicf_event_ctx_t g_evt;

static void handle_frame(const uint8_t src_mac[6], const bicf_frame_view_t* f) {
  const uint32_t seq = bicf_le32(&f->hdr.seq_le);

  uint8_t tx[BICF_MAX_FRAME];
  size_t tx_len = 0;

  if (f->hdr.cmd == BICF_CMD_DISCOVER_REQ) {
    uint8_t zero[32] = {0};
    (void)bicf_jsonl_emit_rpc(&g_evt, 'B', "rpc", "bicf/discover/resp", zero, f->payload_sha256,
                              ",\"cmd\":\"DISCOVER_REQ\",\"ok\":1");
    uint8_t payload[2] = {BICF_ROLE_VERIFY, 0};
    tx_len = bicf_frame_encode(BICF_CMD_DISCOVER_RESP, seq, payload, sizeof(payload), tx, sizeof(tx));
    bicf_espnow_add_peer(src_mac);
    if (tx_len) (void)bicf_espnow_send(src_mac, tx, (int)tx_len);
    return;
  }

  if (f->hdr.cmd == BICF_CMD_VERIFY_REQ) {
    clbc_vm_result_t r = {0};
    bool ran = clbc_vm_run(f->payload, f->payload_len, &r);
    uint8_t trace_anchor[32] = {0};
    // For verify, trace anchor is the VM transcript hash if ok, else zero.
    if (ran && r.ok) memcpy(trace_anchor, r.transcript_sha256, 32);
    (void)bicf_jsonl_emit_rpc(&g_evt, 'B', "rpc", "bicf/vm/verify", trace_anchor, f->payload_sha256,
                              (ran && r.ok) ? ",\"cmd\":\"VERIFY_REQ\",\"ok\":1" : ",\"cmd\":\"VERIFY_REQ\",\"ok\":0");
    uint8_t payload[1 + 4 + 32];
    payload[0] = (ran && r.ok) ? 1 : 0;
    bicf_put_le32(payload + 1, r.events);
    for (int i = 0; i < 32; i++) payload[5 + i] = r.transcript_sha256[i];
    tx_len = bicf_frame_encode(BICF_CMD_VERIFY_RESP, seq, payload, sizeof(payload), tx, sizeof(tx));
    bicf_espnow_add_peer(src_mac);
    if (tx_len) (void)bicf_espnow_send(src_mac, tx, (int)tx_len);
    return;
  }
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
  printf("ROLE=B(VERIFY)\n");
  printf("MAC=%s\n", macs);

  bicf_event_ctx_init(&g_evt);
  uint8_t zero[32] = {0};
  uint8_t mac_hash[32];
  (void)bicf_sha256(g_self_mac, 6, mac_hash);
  (void)bicf_jsonl_emit_rpc(&g_evt, 'B', "state", "bicf/boot", zero, mac_hash, ",\"role\":\"VERIFY\"");

  ESP_ERROR_CHECK(bicf_espnow_init(rx_cb));
}
