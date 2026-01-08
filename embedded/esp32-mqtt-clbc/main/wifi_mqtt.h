#ifndef WIFI_MQTT_H
#define WIFI_MQTT_H

#include <stdbool.h>
#include "mqtt_client.h"

// WiFi and MQTT configuration
typedef struct {
    char ssid[32];
    char password[64];
    char broker_host[64];
    uint16_t broker_port;
    char client_id[32];
    char device_id[32];  // "esp32-<mac>" or friendly alias
} wifi_mqtt_config_t;

// Initialize WiFi and MQTT
bool wifi_mqtt_init(const wifi_mqtt_config_t *config);

// Get MQTT client handle (for publishing)
esp_mqtt_client_handle_t wifi_mqtt_get_client(void);

// Check if connected
bool wifi_mqtt_is_connected(void);

// Publish CLBC result
bool wifi_mqtt_publish_result(const char *transcript_hash, const char *fano_hash, uint32_t events, bool ok, uint32_t exec_ms);

// Returns the active device_id used for topics (may be auto-derived).
const char *wifi_mqtt_device_id(void);

#endif  // WIFI_MQTT_H
