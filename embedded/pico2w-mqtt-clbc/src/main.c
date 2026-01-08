#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "pico/stdlib.h"

#include "pico/cyw43_arch.h"
#include "lwip/dns.h"
#include "lwip/apps/mqtt.h"
#include "lwip/ip_addr.h"
#include "lwip/netif.h"
#include "lwip/ip4_addr.h"

#include "clbc_vm.h"
#include "canisa_mvp.h"
#include "config.h"

static uint8_t g_program[MAX_CLBC_PROGRAM];
static size_t g_program_len = 0;

static uint8_t g_canbc[MAX_CLBC_PROGRAM];
static size_t g_canbc_len = 0;

static mqtt_client_t* g_mqtt = NULL;
static bool g_mqtt_connected = false;
static bool g_mqtt_connecting = false;

static void led_set(bool on) { cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, on); }

static void bytes_to_hex32(const uint8_t in[32], char out65[65]) {
  static const char* hex = "0123456789abcdef";
  for (uint32_t i = 0; i < 32; i++) {
    out65[i * 2] = hex[(in[i] >> 4) & 0xF];
    out65[i * 2 + 1] = hex[in[i] & 0xF];
  }
  out65[64] = 0;
}

static int hex_nibble(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return 10 + (c - 'a');
  if (c >= 'A' && c <= 'F') return 10 + (c - 'A');
  return -1;
}

static bool decode_hex_bytes(const char* hex, uint8_t* out, size_t out_cap, size_t* out_len) {
  if (!hex || !out || !out_len) return false;
  size_t n = strlen(hex);
  if ((n & 1) != 0) return false;
  size_t bytes = n / 2;
  if (bytes > out_cap) return false;
  for (size_t i = 0; i < bytes; i++) {
    int hi = hex_nibble(hex[i * 2]);
    int lo = hex_nibble(hex[i * 2 + 1]);
    if (hi < 0 || lo < 0) return false;
    out[i] = (uint8_t)((hi << 4) | lo);
  }
  *out_len = bytes;
  return true;
}

static bool json_get_string_field(const char* json, const char* field, char* out, size_t out_cap) {
  if (!json || !field || !out || out_cap == 0) return false;
  char needle[64];
  snprintf(needle, sizeof(needle), "\"%s\"", field);
  const char* p = strstr(json, needle);
  if (!p) return false;
  p += strlen(needle);
  while (*p && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) p++;
  if (*p != ':') return false;
  p++;
  while (*p && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) p++;
  if (*p != '"') return false;
  p++;
  size_t i = 0;
  while (*p && *p != '"' && i + 1 < out_cap) {
    out[i++] = *p++;
  }
  out[i] = 0;
  return *p == '"';
}

static void mqtt_pub_event_loaded(size_t len) {
  if (!g_mqtt_connected || !g_mqtt) return;
  char payload[128];
  snprintf(payload, sizeof(payload), "{\"type\":\"loaded\",\"clbc_len\":%u}", (unsigned)len);
  mqtt_publish(g_mqtt, MQTT_EVENTS_TOPIC, payload, strlen(payload), 1, 0, NULL, NULL);
}

static void mqtt_pub_status_online(const ip_addr_t* broker_ip) {
  if (!g_mqtt_connected || !g_mqtt) return;
  char payload[256];
  char ipbuf[48] = {0};
  if (broker_ip) {
    ipaddr_ntoa_r(broker_ip, ipbuf, sizeof(ipbuf));
  }
  snprintf(payload, sizeof(payload),
           "{\"type\":\"status\",\"status\":\"online\",\"client_id\":\"%s\",\"broker_ip\":\"%s\",\"broker_port\":%d}",
           MQTT_CLIENT_ID, ipbuf, MQTT_BROKER_PORT);
  mqtt_publish(g_mqtt, MQTT_STATUS_TOPIC, payload, strlen(payload), 1, 0, NULL, NULL);
}

static void mqtt_pub_event_run_result(const char* hash64, uint32_t events, bool ok) {
  if (!g_mqtt_connected || !g_mqtt) return;
  char payload[192];
  snprintf(payload, sizeof(payload), "{\"type\":\"run_result\",\"ok\":%s,\"events\":%u,\"transcript_hash\":\"%s\"}",
           ok ? "true" : "false", (unsigned)events, hash64 ? hash64 : "");
  mqtt_publish(g_mqtt, MQTT_EVENTS_TOPIC, payload, strlen(payload), 1, 0, NULL, NULL);
}

static void mqtt_pub_event_run_result_with_fano(const char* hash64, const char* fano_hash, uint32_t events, bool ok) {
  if (!g_mqtt_connected || !g_mqtt) return;
  char payload[256];
  if (fano_hash && fano_hash[0]) {
    snprintf(payload, sizeof(payload),
             "{\"type\":\"run_result\",\"ok\":%s,\"events\":%u,\"transcript_hash\":\"%s\",\"fano_hash\":\"%s\"}",
             ok ? "true" : "false", (unsigned)events, hash64 ? hash64 : "", fano_hash);
  } else {
    snprintf(payload, sizeof(payload), "{\"type\":\"run_result\",\"ok\":%s,\"events\":%u,\"transcript_hash\":\"%s\"}",
             ok ? "true" : "false", (unsigned)events, hash64 ? hash64 : "");
  }
  mqtt_publish(g_mqtt, MQTT_EVENTS_TOPIC, payload, strlen(payload), 1, 0, NULL, NULL);
}

static void on_incoming_publish(void* arg, const char* topic, u32_t tot_len) {
  (void)arg;
  (void)topic;
  (void)tot_len;
}

static void on_incoming_data(void* arg, const u8_t* data, u16_t len, u8_t flags) {
  (void)arg;
  (void)flags;
  if (!data || !len) return;

  // Must hold at least {"type":"load_program","clbc_hex":"..."} with MAX_CLBC_PROGRAM bytes of hex.
  static char buf[(MAX_CLBC_PROGRAM * 2) + 512];
  static size_t used = 0;

  size_t to_copy = len;
  if (used + to_copy >= sizeof(buf)) {
    used = 0;
    return;
  }
  memcpy(buf + used, data, to_copy);
  used += to_copy;

  // MQTT may chunk payload; assume single message fits in buf and treat flags&MQTT_DATA_FLAG_LAST.
  if ((flags & MQTT_DATA_FLAG_LAST) == 0) return;
  buf[used] = 0;

  char type[32];
  if (!json_get_string_field(buf, "type", type, sizeof(type))) {
    used = 0;
    return;
  }

  if (strcmp(type, "load_program") == 0) {
    char hex[8200];
    if (!json_get_string_field(buf, "clbc_hex", hex, sizeof(hex))) {
      used = 0;
      return;
    }
    size_t out_len = 0;
    if (decode_hex_bytes(hex, g_program, sizeof(g_program), &out_len)) {
      g_program_len = out_len;
      g_canbc_len = 0;
      mqtt_pub_event_loaded(g_program_len);
    }
  } else if (strcmp(type, "load_canbc") == 0) {
    char hex[8200];
    if (!json_get_string_field(buf, "canbc_hex", hex, sizeof(hex))) {
      used = 0;
      return;
    }
    size_t out_len = 0;
    if (decode_hex_bytes(hex, g_canbc, sizeof(g_canbc), &out_len)) {
      g_canbc_len = out_len;
      g_program_len = 0;
      mqtt_pub_event_loaded(g_canbc_len);
    }
  } else if (strcmp(type, "run") == 0) {
    if (g_canbc_len) {
      canisa_mvp_result_t r = {0};
      bool ok = canisa_mvp_run_canbc(g_canbc, g_canbc_len, &r);
      mqtt_pub_event_run_result_with_fano(r.state_hash, r.fano_hash, r.events, ok && r.ok);
    } else if (g_program_len) {
      clbc_vm_result_t vm = {0};
      bool ok = clbc_vm_run(g_program, g_program_len, &vm);
      char hash65[65];
      bytes_to_hex32(vm.transcript_sha256, hash65);
      mqtt_pub_event_run_result(hash65, vm.events, ok && vm.ok);
    }
  }

  used = 0;
}

static void mqtt_connection_cb(mqtt_client_t* client, void* arg, mqtt_connection_status_t status) {
  (void)arg;
  g_mqtt_connecting = false;
  if (status == MQTT_CONNECT_ACCEPTED) {
    g_mqtt_connected = true;
    led_set(true);
    mqtt_set_inpub_callback(client, on_incoming_publish, on_incoming_data, NULL);
    mqtt_subscribe(client, MQTT_COMMAND_TOPIC, 1, NULL, NULL);
  } else {
    g_mqtt_connected = false;
    led_set(false);
  }
}

typedef struct {
  bool done;
  bool ok;
  ip_addr_t addr;
} dns_result_t;

static void dns_found_cb(const char* name, const ip_addr_t* ipaddr, void* arg) {
  (void)name;
  dns_result_t* r = (dns_result_t*)arg;
  if (!r) return;
  if (ipaddr) {
    r->addr = *ipaddr;
    r->ok = true;
  }
  r->done = true;
}

static bool resolve_broker_ip(ip_addr_t* out, uint32_t timeout_ms) {
  if (!out) return false;

  if (strcmp(MQTT_BROKER_HOST, "gateway") == 0) {
    bool ok = false;
    cyw43_arch_lwip_begin();
    if (netif_default) {
      const ip4_addr_t* gw = netif_ip4_gw(netif_default);
      if (gw && ip4_addr_get_u32(gw) != 0) {
        ip_addr_set_ip4_u32(out, ip4_addr_get_u32(gw));
        ok = true;
      }
    }
    cyw43_arch_lwip_end();
    return ok;
  }

  if (ipaddr_aton(MQTT_BROKER_HOST, out)) return true;

  dns_result_t res = {0};
  cyw43_arch_lwip_begin();
  err_t e = dns_gethostbyname(MQTT_BROKER_HOST, out, dns_found_cb, &res);
  cyw43_arch_lwip_end();

  if (e == ERR_OK) return true;
  if (e != ERR_INPROGRESS) return false;

  absolute_time_t deadline = make_timeout_time_ms(timeout_ms);
  while (!time_reached(deadline) && !res.done) {
    sleep_ms(50);
  }
  if (!res.done || !res.ok) return false;
  *out = res.addr;
  return true;
}

static bool wifi_is_up(void) {
  int s = cyw43_tcpip_link_status(&cyw43_state, CYW43_ITF_STA);
  return s == CYW43_LINK_UP;
}

static int wifi_connect_try(uint32_t timeout_ms) {
  // Some hotspots require WPA2 mixed mode; try both deterministically.
  int rc = cyw43_arch_wifi_connect_timeout_ms(WIFI_SSID, WIFI_PASSWORD, CYW43_AUTH_WPA2_AES_PSK, timeout_ms);
  if (!rc) return 0;
  rc = cyw43_arch_wifi_connect_timeout_ms(WIFI_SSID, WIFI_PASSWORD, CYW43_AUTH_WPA2_MIXED_PSK, timeout_ms);
  return rc;
}

int main(void) {
  stdio_init_all();
  sleep_ms(200);

  if (cyw43_arch_init()) {
    return 1;
  }
  cyw43_arch_enable_sta_mode();
  led_set(false);

  g_mqtt = mqtt_client_new();
  if (!g_mqtt) return 2;

  struct mqtt_connect_client_info_t info = {0};
  info.client_id = MQTT_CLIENT_ID;

  absolute_time_t next_wifi_try = get_absolute_time();
  absolute_time_t next_mqtt_try = get_absolute_time();
  bool led_phase = false;
  absolute_time_t next_led = get_absolute_time();
  ip_addr_t broker_ip_last = {0};

  while (true) {
    if (!wifi_is_up()) {
      g_mqtt_connected = false;
      g_mqtt_connecting = false;

      // LED: slow blink while WiFi is down.
      if (absolute_time_diff_us(get_absolute_time(), next_led) <= 0) {
        led_phase = !led_phase;
        led_set(led_phase);
        next_led = delayed_by_ms(get_absolute_time(), 500);
      }

      if (absolute_time_diff_us(get_absolute_time(), next_wifi_try) <= 0) {
        int rc = wifi_connect_try(30000);
        if (rc) {
          next_wifi_try = delayed_by_ms(get_absolute_time(), 2000);
        } else {
          next_wifi_try = delayed_by_ms(get_absolute_time(), 1000);
        }
      }
      sleep_ms(100);
      continue;
    }

    // LED: faster blink while WiFi up but MQTT not connected.
    if (!g_mqtt_connected) {
      if (absolute_time_diff_us(get_absolute_time(), next_led) <= 0) {
        led_phase = !led_phase;
        led_set(led_phase);
        next_led = delayed_by_ms(get_absolute_time(), 150);
      }
    }

    if (!g_mqtt_connected && !g_mqtt_connecting && absolute_time_diff_us(get_absolute_time(), next_mqtt_try) <= 0) {
      ip_addr_t broker_ip;
      if (resolve_broker_ip(&broker_ip, 5000)) {
        broker_ip_last = broker_ip;
        g_mqtt_connecting = true;
        cyw43_arch_lwip_begin();
        mqtt_client_connect(g_mqtt, &broker_ip, MQTT_BROKER_PORT, mqtt_connection_cb, NULL, &info);
        cyw43_arch_lwip_end();
        next_mqtt_try = delayed_by_ms(get_absolute_time(), 2000);
      } else {
        next_mqtt_try = delayed_by_ms(get_absolute_time(), 2000);
      }
    }

    // Periodic status heartbeat.
    static absolute_time_t next_status;
    if (is_nil_time(next_status)) next_status = get_absolute_time();
    if (g_mqtt_connected && absolute_time_diff_us(get_absolute_time(), next_status) <= 0) {
      mqtt_pub_status_online(&broker_ip_last);
      next_status = delayed_by_ms(get_absolute_time(), 5000);
    }

    sleep_ms(100);
  }
}
