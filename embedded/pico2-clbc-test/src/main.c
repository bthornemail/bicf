#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "bsp/board.h"
#include "pico/stdlib.h"
#include "tusb.h"

#include "clbc_vm.h"

enum {
  CLBT_MAGIC = 0x434C4254u,  // 'CLBT'
  CLBT_VERSION = 0x0001u,

  MSG_LOAD_PROGRAM = 0x0001u,
  MSG_RUN = 0x0002u,

  MSG_ACK = 0x8001u,
  MSG_NACK = 0x8002u,
  MSG_RUN_RESULT = 0x8003u,
};

enum {
  ERR_NO_PROGRAM = 100,
  ERR_BAD_PAYLOAD = 101,
  ERR_TOO_LARGE = 102,
  ERR_PARSE_FAIL = 103,
};

static void write_u16le(uint8_t out[2], uint16_t v) {
  out[0] = (uint8_t)v;
  out[1] = (uint8_t)(v >> 8);
}

static void write_u32le(uint8_t out[4], uint32_t v) {
  out[0] = (uint8_t)v;
  out[1] = (uint8_t)(v >> 8);
  out[2] = (uint8_t)(v >> 16);
  out[3] = (uint8_t)(v >> 24);
}

static uint16_t read_u16le(const uint8_t in[2]) {
  return (uint16_t)in[0] | (uint16_t)((uint16_t)in[1] << 8);
}

static uint32_t read_u32le(const uint8_t in[4]) {
  return (uint32_t)in[0] | ((uint32_t)in[1] << 8) | ((uint32_t)in[2] << 16) | ((uint32_t)in[3] << 24);
}

static void cdc_write_all(const uint8_t* p, size_t n) {
  while (n) {
    if (!tud_cdc_connected()) {
      tight_loop_contents();
      continue;
    }
    uint32_t wrote = tud_cdc_write(p, (uint32_t)n);
    tud_cdc_write_flush();
    p += wrote;
    n -= wrote;
    if (!wrote) tight_loop_contents();
  }
}

static void send_frame(uint16_t msg_type, const uint8_t* payload, uint32_t payload_len) {
  uint8_t hdr[12];
  write_u32le(&hdr[0], CLBT_MAGIC);
  write_u16le(&hdr[4], CLBT_VERSION);
  write_u16le(&hdr[6], msg_type);
  write_u32le(&hdr[8], payload_len);
  cdc_write_all(hdr, sizeof(hdr));
  if (payload_len && payload) cdc_write_all(payload, payload_len);
}

static void send_ack(void) {
  send_frame(MSG_ACK, 0, 0);
}

static void send_nack(uint32_t error_code, const char* msg) {
  uint8_t payload[4 + 4 + 96];
  uint32_t msg_len = 0;
  if (msg) {
    msg_len = (uint32_t)strnlen(msg, 96);
  }
  write_u32le(&payload[0], error_code);
  write_u32le(&payload[4], msg_len);
  if (msg_len) memcpy(&payload[8], msg, msg_len);
  send_frame(MSG_NACK, payload, 8 + msg_len);
}

static void hex32(const uint8_t in32[32], char out65[65]) {
  static const char* hex = "0123456789abcdef";
  for (uint32_t i = 0; i < 32; i++) {
    out65[i * 2] = hex[(in32[i] >> 4) & 0xF];
    out65[i * 2 + 1] = hex[in32[i] & 0xF];
  }
  out65[64] = 0;
}

enum { MAX_PROGRAM = 32 * 1024 };
static uint8_t g_program[MAX_PROGRAM];
static uint32_t g_program_len = 0;

typedef enum { RX_HDR, RX_PAYLOAD } rx_state_t;

static rx_state_t g_rx_state = RX_HDR;
static uint8_t g_hdr[12];
static uint32_t g_hdr_used = 0;

static uint32_t g_payload_len = 0;
static uint32_t g_payload_used = 0;
static uint8_t g_payload[4 + MAX_PROGRAM];

static void handle_message(uint16_t msg_type, const uint8_t* payload, uint32_t payload_len) {
  if (msg_type == MSG_LOAD_PROGRAM) {
    if (payload_len < 4) return send_nack(ERR_BAD_PAYLOAD, "LOAD_PROGRAM: short");
    uint32_t program_len = read_u32le(&payload[0]);
    if (program_len > MAX_PROGRAM) return send_nack(ERR_TOO_LARGE, "program too large");
    if (payload_len != 4 + program_len) return send_nack(ERR_BAD_PAYLOAD, "LOAD_PROGRAM: length mismatch");
    memcpy(g_program, payload + 4, program_len);
    g_program_len = program_len;
    return send_ack();
  }

  if (msg_type == MSG_RUN) {
    if (payload_len != 4) return send_nack(ERR_BAD_PAYLOAD, "RUN: bad flags");
    uint32_t flags = read_u32le(&payload[0]);
    if (flags != 0) return send_nack(ERR_BAD_PAYLOAD, "RUN: flags must be 0");
    if (!g_program_len) return send_nack(ERR_NO_PROGRAM, "no program loaded");

    clbc_vm_result_t vm = {0};
    if (!clbc_vm_run(g_program, g_program_len, &vm)) return send_nack(ERR_PARSE_FAIL, "clbc parse failed");

    char hash65[65];
    hex32(vm.transcript_sha256, hash65);
    uint32_t hash_len = 64;

    uint8_t resp[4 + 4 + 4 + 64];
    write_u32le(&resp[0], vm.ok ? 1u : 0u);
    write_u32le(&resp[4], vm.events);
    write_u32le(&resp[8], hash_len);
    memcpy(&resp[12], hash65, 64);
    return send_frame(MSG_RUN_RESULT, resp, sizeof(resp));
  }

  send_nack(ERR_BAD_PAYLOAD, "unknown msg_type");
}

static void rx_reset(void) {
  g_rx_state = RX_HDR;
  g_hdr_used = 0;
  g_payload_len = 0;
  g_payload_used = 0;
}

static void rx_poll(void) {
  if (!tud_cdc_connected()) return;
  while (tud_cdc_available()) {
    uint8_t b = 0;
    tud_cdc_read(&b, 1);

    if (g_rx_state == RX_HDR) {
      g_hdr[g_hdr_used++] = b;
      if (g_hdr_used == sizeof(g_hdr)) {
        uint32_t magic = read_u32le(&g_hdr[0]);
        uint16_t version = read_u16le(&g_hdr[4]);
        uint16_t msg_type = read_u16le(&g_hdr[6]);
        uint32_t payload_len = read_u32le(&g_hdr[8]);

        if (magic != CLBT_MAGIC || version != CLBT_VERSION) {
          send_nack(ERR_BAD_PAYLOAD, "bad magic/version");
          rx_reset();
          continue;
        }

        if (payload_len > sizeof(g_payload)) {
          send_nack(ERR_TOO_LARGE, "payload too large");
          rx_reset();
          continue;
        }

        g_payload_len = payload_len;
        g_payload_used = 0;
        g_rx_state = RX_PAYLOAD;

        if (g_payload_len == 0) {
          handle_message(msg_type, 0, 0);
          rx_reset();
        }
      }
      continue;
    }

    // RX_PAYLOAD
    g_payload[g_payload_used++] = b;
    if (g_payload_used == g_payload_len) {
      uint16_t msg_type = read_u16le(&g_hdr[6]);
      handle_message(msg_type, g_payload, g_payload_len);
      rx_reset();
    }
  }
}

int main(void) {
  board_init();
  tusb_init();

  absolute_time_t next_blink = make_timeout_time_ms(250);
  bool led = false;

  while (true) {
    tud_task();
    rx_poll();

    if (absolute_time_diff_us(get_absolute_time(), next_blink) <= 0) {
      led = !led;
      board_led_write(led);
      next_blink = delayed_by_ms(next_blink, 250);
    }
  }
}
