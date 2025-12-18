#ifndef BICF_ESPNOW_H
#define BICF_ESPNOW_H

#include <stdbool.h>
#include <stdint.h>

#include "esp_err.h"

typedef void (*bicf_espnow_rx_cb_t)(const uint8_t src_mac[6], const uint8_t* data, int len);

esp_err_t bicf_espnow_init(bicf_espnow_rx_cb_t rx_cb);
esp_err_t bicf_espnow_add_peer(const uint8_t peer_mac[6]);
esp_err_t bicf_espnow_send(const uint8_t dst_mac[6], const uint8_t* data, int len);

static inline void bicf_mac_to_str(const uint8_t mac[6], char out18[18]) {
  static const char* hex = "0123456789abcdef";
  for (int i = 0; i < 6; i++) {
    out18[i * 3] = hex[(mac[i] >> 4) & 0x0F];
    out18[i * 3 + 1] = hex[mac[i] & 0x0F];
    if (i != 5) out18[i * 3 + 2] = ':';
  }
  out18[17] = '\0';
}

#endif

