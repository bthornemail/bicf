#include "bicf_espnow.h"

#include <string.h>

#include "esp_event.h"
#include "esp_mac.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "esp_now.h"
#include "nvs_flash.h"

static bicf_espnow_rx_cb_t g_rx_cb = 0;

static void espnow_recv_cb(const esp_now_recv_info_t* recv_info, const uint8_t* data, int len) {
  if (!recv_info || !data || len <= 0) return;
  if (g_rx_cb) g_rx_cb(recv_info->src_addr, data, len);
}

esp_err_t bicf_espnow_init(bicf_espnow_rx_cb_t rx_cb) {
  g_rx_cb = rx_cb;

  esp_err_t err = nvs_flash_init();
  if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    ESP_ERROR_CHECK(nvs_flash_erase());
    err = nvs_flash_init();
  }
  ESP_ERROR_CHECK(err);

  ESP_ERROR_CHECK(esp_netif_init());
  ESP_ERROR_CHECK(esp_event_loop_create_default());

  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  ESP_ERROR_CHECK(esp_wifi_init(&cfg));
  ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));
  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
  ESP_ERROR_CHECK(esp_wifi_start());

  // ESPNOW requires WiFi started and a channel; keep channel fixed for determinism.
  ESP_ERROR_CHECK(esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE));

  ESP_ERROR_CHECK(esp_now_init());
  ESP_ERROR_CHECK(esp_now_register_recv_cb(espnow_recv_cb));

  // Add broadcast peer
  const uint8_t broadcast[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff};
  esp_now_peer_info_t peer = {0};
  memcpy(peer.peer_addr, broadcast, 6);
  peer.channel = 1;
  peer.encrypt = false;
  (void)esp_now_add_peer(&peer);

  return ESP_OK;
}

esp_err_t bicf_espnow_add_peer(const uint8_t peer_mac[6]) {
  if (!peer_mac) return ESP_ERR_INVALID_ARG;
  esp_now_peer_info_t peer = {0};
  memcpy(peer.peer_addr, peer_mac, 6);
  peer.channel = 1;
  peer.encrypt = false;
  if (esp_now_is_peer_exist(peer_mac)) return ESP_OK;
  return esp_now_add_peer(&peer);
}

esp_err_t bicf_espnow_send(const uint8_t dst_mac[6], const uint8_t* data, int len) {
  if (!dst_mac || !data || len <= 0) return ESP_ERR_INVALID_ARG;
  return esp_now_send(dst_mac, data, len);
}
