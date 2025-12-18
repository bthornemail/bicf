#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "esp_mac.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "bicf_espnow.h"
#include "bicf_jsonl.h"
#include "bicf_proto.h"
#include "clbc_vm.h"

// Node C: Orchestrator demo.
// - DISCOVER: learn Node A (NRR) + Node B (VERIFY) by role
// - APPEND to A: send fixed CLBC bytes
// - REPLAY from A: get trace_id + last_vm
// - VERIFY on B: verify VM transcript hash
// - Print deterministic PASS/FAIL summary

static const uint8_t CLBC_PROGRAM[] = {
  0x43, 0x4c, 0x42, 0x43, 0x01, 0x00, 0x02, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00,
  0x02, 0x68, 0x31, 0x02, 0x68, 0x32, 0xf0, 0x02, 0x01, 0x30, 0x02, 0x00, 0x01, 0x31,
  0x01, 0x32, 0x00, 0xf1, 0xf0, 0x02, 0x02, 0x30, 0x01, 0x02, 0x31, 0x00, 0x32, 0x01,
  0xf1,
};

static uint8_t g_self_mac[6];
static uint8_t g_mac_a[6];
static uint8_t g_mac_b[6];
static bool g_have_a = false;
static bool g_have_b = false;
static bicf_event_ctx_t g_evt;

static void policy_statement(char out_text[128]) {
  strcpy(out_text, "We accept new log entries only if they are independently verified by node B and they are replayable "
                   "from the shared log.");
}

static void policy_statement_id(const char* statement_text, const uint8_t trace_id32[32], uint8_t out32[32]) {
  // statement_id = sha256("POLICYv1" || statement_text || trace_id)
  uint8_t buf[8 + 128 + 32];
  memset(buf, 0, sizeof(buf));
  memcpy(buf, "POLICYv1", 8);
  size_t n = strlen(statement_text);
  if (n > 128) n = 128;
  memcpy(buf + 8, statement_text, n);
  memcpy(buf + 8 + 128, trace_id32, 32);
  (void)bicf_sha256(buf, sizeof(buf), out32);
}

static bool g_have_append_resp = false;
static uint8_t g_append_sha[32];
static bool g_append_ok = false;

static bool g_have_reset_resp = false;
static bool g_reset_ok = false;

static bool g_have_replay_resp = false;
static bool g_replay_ok = false;
static uint32_t g_replay_count = 0;
static uint8_t g_replay_trace_id[32];
static uint8_t g_replay_last_vm[32];

static bool g_have_verify_resp = false;
static bool g_verify_ok = false;
static uint32_t g_verify_events = 0;
static uint8_t g_verify_vm[32];

static int mac_cmp(const uint8_t a[6], const uint8_t b[6]) {
  for (int i = 0; i < 6; i++) {
    if (a[i] < b[i]) return -1;
    if (a[i] > b[i]) return 1;
  }
  return 0;
}

static void maybe_set_role_mac(uint8_t role, const uint8_t mac[6]) {
  if (role == BICF_ROLE_NRR) {
    if (!g_have_a || mac_cmp(mac, g_mac_a) < 0) {
      memcpy(g_mac_a, mac, 6);
      g_have_a = true;
    }
  } else if (role == BICF_ROLE_VERIFY) {
    if (!g_have_b || mac_cmp(mac, g_mac_b) < 0) {
      memcpy(g_mac_b, mac, 6);
      g_have_b = true;
    }
  }
}

static void rx_cb(const uint8_t src_mac[6], const uint8_t* data, int len) {
  bicf_frame_view_t f;
  if (!bicf_frame_decode(data, (size_t)len, &f)) return;

  const uint32_t seq = bicf_le32(&f.hdr.seq_le);

  if (f.hdr.cmd == BICF_CMD_DISCOVER_RESP && f.payload_len >= 1) {
    maybe_set_role_mac(f.payload[0], src_mac);
    return;
  }

  if (f.hdr.cmd == BICF_CMD_APPEND_RESP && f.payload_len == 33 && seq == 3) {
    g_append_ok = (f.payload[0] == 1);
    memcpy(g_append_sha, f.payload + 1, 32);
    g_have_append_resp = true;
    return;
  }

  if (f.hdr.cmd == BICF_CMD_RESET_RESP && f.payload_len == 1 && seq == 2) {
    g_reset_ok = (f.payload[0] == 1);
    g_have_reset_resp = true;
    return;
  }

  if (f.hdr.cmd == BICF_CMD_REPLAY_RESP && f.payload_len == (1 + 4 + 32 + 32) && seq == 4) {
    g_replay_ok = (f.payload[0] == 1);
    g_replay_count = bicf_le32(f.payload + 1);
    memcpy(g_replay_trace_id, f.payload + 5, 32);
    memcpy(g_replay_last_vm, f.payload + 37, 32);
    g_have_replay_resp = true;
    return;
  }

  if (f.hdr.cmd == BICF_CMD_VERIFY_RESP && f.payload_len == (1 + 4 + 32) && seq == 5) {
    g_verify_ok = (f.payload[0] == 1);
    g_verify_events = bicf_le32(f.payload + 1);
    memcpy(g_verify_vm, f.payload + 5, 32);
    g_have_verify_resp = true;
    return;
  }
}

static bool wait_flag(volatile bool* flag, int ms) {
  const int64_t deadline = esp_timer_get_time() + (int64_t)ms * 1000;
  while (esp_timer_get_time() < deadline) {
    if (*flag) return true;
    vTaskDelay(pdMS_TO_TICKS(10));
  }
  return *flag;
}

static void print_mac(const char* label, const uint8_t mac[6]) {
  char s[18];
  bicf_mac_to_str(mac, s);
  printf("%s=%s\n", label, s);
}

static void orch_task(void* arg) {
  (void)arg;

  printf("ROLE=C(ORCH)\n");
  print_mac("MAC", g_self_mac);
  uint8_t zero[32] = {0};
  uint8_t mac_hash[32];
  (void)bicf_sha256(g_self_mac, 6, mac_hash);
  (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "state", "bicf/boot", zero, mac_hash, ",\"role\":\"ORCH\"");

  // 1) Discover A + B.
  const uint8_t broadcast[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff};
  uint8_t frame[BICF_MAX_FRAME];
  size_t flen = bicf_frame_encode(BICF_CMD_DISCOVER_REQ, 1, NULL, 0, frame, sizeof(frame));
  (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "rpc", "bicf/discover", zero, zero, ",\"to\":\"broadcast\",\"cmd\":\"DISCOVER_REQ\"");
  (void)bicf_espnow_send(broadcast, frame, (int)flen);
  vTaskDelay(pdMS_TO_TICKS(500));
  (void)bicf_espnow_send(broadcast, frame, (int)flen);
  vTaskDelay(pdMS_TO_TICKS(500));

  if (!g_have_a || !g_have_b) {
    (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "decision", "policy/decide", zero, zero,
                              ",\"ok\":0,\"reason\":\"discover\"");
    printf("DEMO_FAIL=discover\n");
    vTaskDelete(NULL);
    return;
  }

  bicf_espnow_add_peer(g_mac_a);
  bicf_espnow_add_peer(g_mac_b);

  print_mac("NODE_A", g_mac_a);
  print_mac("NODE_B", g_mac_b);

  // 2) Local expectations.
  uint8_t clbc_sha[32];
  bicf_sha256(CLBC_PROGRAM, sizeof(CLBC_PROGRAM), clbc_sha);
  clbc_vm_result_t local_vm = {0};
  (void)clbc_vm_run(CLBC_PROGRAM, sizeof(CLBC_PROGRAM), &local_vm);

  // 3) RESET A so the demo starts from a known log state.
  g_have_reset_resp = false;
  flen = bicf_frame_encode(BICF_CMD_RESET_REQ, 2, NULL, 0, frame, sizeof(frame));
  (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "rpc", "bicf/nrr/reset", zero, zero, ",\"to\":\"A\",\"cmd\":\"RESET_REQ\"");
  (void)bicf_espnow_send(g_mac_a, frame, (int)flen);
  if (!wait_flag(&g_have_reset_resp, 1500)) {
    (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "decision", "policy/decide", zero, zero,
                              ",\"ok\":0,\"reason\":\"reset_timeout\"");
    printf("DEMO_FAIL=reset_timeout\n");
    vTaskDelete(NULL);
    return;
  }
  if (!g_reset_ok) {
    (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "decision", "policy/decide", zero, zero,
                              ",\"ok\":0,\"reason\":\"reset_rejected\"");
    printf("DEMO_FAIL=reset_rejected\n");
    vTaskDelete(NULL);
    return;
  }

  // 4) APPEND to A.
  g_have_append_resp = false;
  flen = bicf_frame_encode(BICF_CMD_APPEND_REQ, 3, CLBC_PROGRAM, (uint32_t)sizeof(CLBC_PROGRAM), frame, sizeof(frame));
  (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "rpc", "bicf/nrr/append", clbc_sha, clbc_sha, ",\"to\":\"A\",\"cmd\":\"APPEND_REQ\"");
  (void)bicf_espnow_send(g_mac_a, frame, (int)flen);
  if (!wait_flag(&g_have_append_resp, 1500)) {
    (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "decision", "policy/decide", zero, clbc_sha,
                              ",\"ok\":0,\"reason\":\"append_timeout\"");
    printf("DEMO_FAIL=append_timeout\n");
    vTaskDelete(NULL);
    return;
  }

  // 5) REPLAY from A.
  g_have_replay_resp = false;
  flen = bicf_frame_encode(BICF_CMD_REPLAY_REQ, 4, NULL, 0, frame, sizeof(frame));
  (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "rpc", "bicf/nrr/replay", zero, zero, ",\"to\":\"A\",\"cmd\":\"REPLAY_REQ\"");
  (void)bicf_espnow_send(g_mac_a, frame, (int)flen);
  if (!wait_flag(&g_have_replay_resp, 1500)) {
    (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "decision", "policy/decide", zero, zero,
                              ",\"ok\":0,\"reason\":\"replay_timeout\"");
    printf("DEMO_FAIL=replay_timeout\n");
    vTaskDelete(NULL);
    return;
  }

  // 6) VERIFY on B.
  g_have_verify_resp = false;
  flen = bicf_frame_encode(BICF_CMD_VERIFY_REQ, 5, CLBC_PROGRAM, (uint32_t)sizeof(CLBC_PROGRAM), frame, sizeof(frame));
  (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "rpc", "bicf/vm/verify", local_vm.transcript_sha256, clbc_sha,
                            ",\"to\":\"B\",\"cmd\":\"VERIFY_REQ\"");
  (void)bicf_espnow_send(g_mac_b, frame, (int)flen);
  if (!wait_flag(&g_have_verify_resp, 1500)) {
    (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "decision", "policy/decide", zero, clbc_sha,
                              ",\"ok\":0,\"reason\":\"verify_timeout\"");
    printf("DEMO_FAIL=verify_timeout\n");
    vTaskDelete(NULL);
    return;
  }

  // Expected trace_id after exactly one append: sha256(clbc_sha)
  uint8_t exp_trace_id[32];
  bicf_sha256(clbc_sha, 32, exp_trace_id);

  bool pass = true;
  pass &= g_append_ok;
  pass &= (memcmp(g_append_sha, clbc_sha, 32) == 0);
  pass &= g_replay_ok;
  pass &= (g_replay_count == 1);
  pass &= (memcmp(g_replay_trace_id, exp_trace_id, 32) == 0);
  pass &= (memcmp(g_replay_last_vm, local_vm.transcript_sha256, 32) == 0);
  pass &= g_verify_ok;
  pass &= (memcmp(g_verify_vm, local_vm.transcript_sha256, 32) == 0);

  char h1[65], h2[65], h3[65], h4[65];
  bicf_hex32(clbc_sha, h1);
  bicf_hex32(g_append_sha, h2);
  bicf_hex32(local_vm.transcript_sha256, h3);
  bicf_hex32(g_verify_vm, h4);

  printf("CLBC_SHA256=%s\n", h1);
  printf("A_APPEND_SHA256=%s\n", h2);
  printf("VM_TRANSCRIPT_SHA256=%s\n", h3);
  printf("B_VERIFY_VM_SHA256=%s\n", h4);

  char t1[65], t2[65];
  bicf_hex32(exp_trace_id, t1);
  bicf_hex32(g_replay_trace_id, t2);
  printf("TRACE_ID_EXPECTED=%s\n", t1);
  printf("TRACE_ID_A=%s\n", t2);

  printf("DEMO_PASS=%d\n", pass ? 1 : 0);

  // Emit the civic policy statement as a non-authoritative (+16D) payload with a binding fingerprint.
  char statement_text[128];
  policy_statement(statement_text);
  uint8_t sid[32];
  policy_statement_id(statement_text, g_replay_trace_id, sid);
  char sid_s[72];
  bicf_sha256_prefixed(sid, sid_s);
  char trace_s[72];
  bicf_sha256_prefixed(g_replay_trace_id, trace_s);
  char suffix[512];
  (void)snprintf(suffix, sizeof(suffix),
           ",\"ok\":%d,\"statement_text\":\"%s\",\"statement_id\":\"%s\",\"trace_id\":\"%s\"",
           pass ? 1 : 0, statement_text, sid_s, trace_s);
  (void)bicf_jsonl_emit_rpc(&g_evt, 'C', "decision", "policy/decide", g_replay_trace_id, sid, suffix);

  // Auto-repeat for demos: after a short pause, restart so a bridge/viewer can attach any time.
  vTaskDelay(pdMS_TO_TICKS(8000));
  esp_restart();
}

void app_main(void) {
  esp_read_mac(g_self_mac, ESP_MAC_WIFI_STA);
  bicf_event_ctx_init(&g_evt);
  ESP_ERROR_CHECK(bicf_espnow_init(rx_cb));
  xTaskCreate(orch_task, "orch_task", 8192, NULL, 5, NULL);
}
