#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "esp_log.h"
#include "esp_system.h"
#include "esp_chip_info.h"
#include "esp_event.h"
#include "esp_timer.h"
#include "esp_mac.h"
#include "mqtt_client.h"
#include "cJSON.h"
#include "mbedtls/sha256.h"

#include "clbc_vm.h"
#include "wifi_mqtt.h"
#include "config.h"
#include "../../canisa-mvp/canisa_mvp.h"
#include "udp_discovery.h"

static const char *TAG = "mqtt_clbc";

static uint8_t g_clbc_program[4096] = {0};
static size_t g_clbc_program_len = 0;

static uint8_t g_canbc_program[4096] = {0};
static size_t g_canbc_program_len = 0;

static void derive_device_id(char *out, size_t out_len) {
    uint8_t mac[6] = {0};
    if (esp_read_mac(mac, ESP_MAC_WIFI_STA) != ESP_OK) {
        snprintf(out, out_len, "esp32-unknown");
        return;
    }
    // Stable, human-usable ID (no network prefix dependency).
    snprintf(out, out_len, "esp32-%02x%02x%02x%02x%02x%02x",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

static bool hex_to_bytes(const char *hex, uint8_t *out, size_t out_cap, size_t *out_len) {
    if (!hex || !out || !out_len) return false;
    size_t n = strlen(hex);
    if (n % 2 != 0) return false;
    size_t bytes = n / 2;
    if (bytes > out_cap) return false;
    for (size_t i = 0; i < bytes; i++) {
        char hex_byte[3] = {hex[i * 2], hex[i * 2 + 1], '\0'};
        out[i] = (uint8_t)strtol(hex_byte, NULL, 16);
    }
    *out_len = bytes;
    return true;
}

static void bytes_to_hex(const uint8_t* in, size_t in_len, char* out_hex, size_t out_hex_len) {
    static const char* hex = "0123456789abcdef";
    if (out_hex_len < (in_len * 2 + 1)) return;
    for (size_t i = 0; i < in_len; i++) {
        out_hex[i * 2] = hex[(in[i] >> 4) & 0x0F];
        out_hex[i * 2 + 1] = hex[in[i] & 0x0F];
    }
    out_hex[in_len * 2] = '\0';
}

static void handle_mqtt_command(const char *topic, const char *data, int data_len) {
    ESP_LOGI(TAG, "Received command on topic: %s", topic);

    cJSON *json = cJSON_ParseWithLength(data, data_len);
    if (!json) {
        ESP_LOGE(TAG, "Failed to parse JSON command");
        return;
    }

    const char *cmd_type = cJSON_GetStringValue(cJSON_GetObjectItem(json, "type"));
    if (!cmd_type) {
        ESP_LOGE(TAG, "Command missing 'type' field");
        cJSON_Delete(json);
        return;
    }

    if (strcmp(cmd_type, "load_program") == 0) {
        // Load CLBC program
        const char *clbc_hex = cJSON_GetStringValue(cJSON_GetObjectItem(json, "clbc_hex"));
        if (!clbc_hex) {
            ESP_LOGE(TAG, "load_program missing 'clbc_hex' field");
            cJSON_Delete(json);
            return;
        }

        size_t out_len = 0;
        if (!hex_to_bytes(clbc_hex, g_clbc_program, sizeof(g_clbc_program), &out_len)) {
            ESP_LOGE(TAG, "Invalid CLBC hex");
            cJSON_Delete(json);
            return;
        }
        g_clbc_program_len = out_len;
        g_canbc_program_len = 0;

        ESP_LOGI(TAG, "Loaded CLBC program: %zu bytes", g_clbc_program_len);

        // Publish confirmation
        cJSON *response = cJSON_CreateObject();
        cJSON_AddStringToObject(response, "device", DEVICE_ID);
        cJSON_AddStringToObject(response, "status", "loaded");
        cJSON_AddNumberToObject(response, "size", g_clbc_program_len);
        char *response_str = cJSON_Print(response);
        if (response_str) {
            char status_topic[64];
            snprintf(status_topic, sizeof(status_topic), "bicf/%s/status", DEVICE_ID);
            esp_mqtt_client_publish(wifi_mqtt_get_client(), status_topic, response_str, 0, 1, 0);
            free(response_str);
        }
        cJSON_Delete(response);

    } else if (strcmp(cmd_type, "load_canbc") == 0) {
        const char *canbc_hex = cJSON_GetStringValue(cJSON_GetObjectItem(json, "canbc_hex"));
        if (!canbc_hex) {
            ESP_LOGE(TAG, "load_canbc missing 'canbc_hex' field");
            cJSON_Delete(json);
            return;
        }
        size_t out_len = 0;
        if (!hex_to_bytes(canbc_hex, g_canbc_program, sizeof(g_canbc_program), &out_len)) {
            ESP_LOGE(TAG, "Invalid CANBC hex");
            cJSON_Delete(json);
            return;
        }
        g_canbc_program_len = out_len;
        g_clbc_program_len = 0;

        ESP_LOGI(TAG, "Loaded CANBC program: %zu bytes", g_canbc_program_len);

        cJSON *response = cJSON_CreateObject();
        cJSON_AddStringToObject(response, "device", DEVICE_ID);
        cJSON_AddStringToObject(response, "status", "loaded_canbc");
        cJSON_AddNumberToObject(response, "size", g_canbc_program_len);
        char *response_str = cJSON_Print(response);
        if (response_str) {
            char status_topic[64];
            snprintf(status_topic, sizeof(status_topic), "bicf/%s/status", DEVICE_ID);
            esp_mqtt_client_publish(wifi_mqtt_get_client(), status_topic, response_str, 0, 1, 0);
            free(response_str);
        }
        cJSON_Delete(response);

    } else if (strcmp(cmd_type, "run") == 0) {
        if (g_canbc_program_len) {
            ESP_LOGI(TAG, "Running CANBC program...");
            int64_t t0 = esp_timer_get_time();
            canisa_mvp_result_t r = {0};
            bool ok = canisa_mvp_run_canbc(g_canbc_program, g_canbc_program_len, &r);
            int64_t t1 = esp_timer_get_time();
            uint32_t exec_ms = (uint32_t)((t1 - t0) / 1000);
            ESP_LOGI(TAG, "CANBC execution complete:");
            ESP_LOGI(TAG, "  OK: %d", ok ? 1 : 0);
            ESP_LOGI(TAG, "  Events: %" PRIu32, r.events);
            ESP_LOGI(TAG, "  State hash: %s", r.state_hash);
            wifi_mqtt_publish_result(r.state_hash, r.fano_hash, r.events, ok && r.ok, exec_ms);
        } else if (g_clbc_program_len) {
            ESP_LOGI(TAG, "Running CLBC program...");

            clbc_vm_result_t vm = {0};
            int64_t t0 = esp_timer_get_time();
            if (clbc_vm_run(g_clbc_program, g_clbc_program_len, &vm)) {
                int64_t t1 = esp_timer_get_time();
                uint32_t exec_ms = (uint32_t)((t1 - t0) / 1000);
                char vm_hex[65] = {0};
                bytes_to_hex(vm.transcript_sha256, 32, vm_hex, sizeof(vm_hex));

                ESP_LOGI(TAG, "CLBC execution complete:");
                ESP_LOGI(TAG, "  OK: %d", vm.ok ? 1 : 0);
                ESP_LOGI(TAG, "  Events: %" PRIu32, vm.events);
                ESP_LOGI(TAG, "  Transcript hash: %s", vm_hex);

                wifi_mqtt_publish_result(vm_hex, NULL, vm.events, vm.ok, exec_ms);
            } else {
                int64_t t1 = esp_timer_get_time();
                uint32_t exec_ms = (uint32_t)((t1 - t0) / 1000);
                ESP_LOGE(TAG, "CLBC execution failed");
                wifi_mqtt_publish_result("", NULL, 0, false, exec_ms);
            }
        } else {
            ESP_LOGE(TAG, "No program loaded");
            cJSON_Delete(json);
            return;
        }
    }

    cJSON_Delete(json);
}

static void mqtt_event_handler(void *handler_args, esp_event_base_t base,
                                int32_t event_id, void *event_data) {
    esp_mqtt_event_handle_t event = (esp_mqtt_event_handle_t)event_data;

    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_DATA:
        {
            char topic[128] = {0};
            int topic_len = event->topic_len < sizeof(topic) - 1 ? event->topic_len : sizeof(topic) - 1;
            memcpy(topic, event->topic, topic_len);
            topic[topic_len] = '\0';

            char data[2048] = {0};
            int data_len = event->data_len < sizeof(data) - 1 ? event->data_len : sizeof(data) - 1;
            memcpy(data, event->data, data_len);
            data[data_len] = '\0';

            handle_mqtt_command(topic, data, data_len);
        }
        break;
    default:
        break;
    }
}

void app_main(void) {
    ESP_LOGI(TAG, "ESP32 MQTT CLBC Firmware");
    char device_id[sizeof(((wifi_mqtt_config_t *)0)->device_id)] = {0};
    if (DEVICE_ID[0] == '\0' || strcmp(DEVICE_ID, "auto") == 0) {
        derive_device_id(device_id, sizeof(device_id));
    } else {
        strncpy(device_id, DEVICE_ID, sizeof(device_id) - 1);
        device_id[sizeof(device_id) - 1] = '\0';
    }
    ESP_LOGI(TAG, "Device ID: %s", device_id);

    // Print chip info
    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);
    ESP_LOGI(TAG, "Chip: %s, Cores: %d, Revision: %d",
             (chip_info.model == CHIP_ESP32S3) ? "ESP32-S3" : "ESP32",
             chip_info.cores, chip_info.revision);

    // Initialize WiFi and MQTT
    wifi_mqtt_config_t config = {0};
    strncpy(config.ssid, WIFI_SSID, sizeof(config.ssid) - 1);
    strncpy(config.password, WIFI_PASSWORD, sizeof(config.password) - 1);
    strncpy(config.broker_host, MQTT_BROKER_HOST, sizeof(config.broker_host) - 1);
    config.broker_port = MQTT_BROKER_PORT;
    strncpy(config.client_id, device_id, sizeof(config.client_id) - 1);
    strncpy(config.device_id, device_id, sizeof(config.device_id) - 1);

    if (!wifi_mqtt_init(&config)) {
        ESP_LOGE(TAG, "Failed to initialize WiFi/MQTT");
        return;
    }

    // When MQTT_BROKER_HOST="gateway", the client starts only after STA gets an IP.
    // Wait for the client handle then register the command handler.
    esp_mqtt_client_handle_t client = NULL;
    for (int i = 0; i < 600 && client == NULL; i++) {  // ~60s worst-case
        client = wifi_mqtt_get_client();
        if (client) break;
        vTaskDelay(pdMS_TO_TICKS(100));
    }
    if (client) {
        esp_mqtt_client_register_event(client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    } else {
        ESP_LOGW(TAG, "MQTT client not ready; commands will be ignored until it connects");
    }

    ESP_LOGI(TAG, "Initialization complete. Waiting for commands on: bicf/%s/command", wifi_mqtt_device_id());

    // Start UDP multicast discovery after networking is up.
    // This does not replace MQTT; it just helps host tools auto-find devices.
    (void)udp_discovery_start(wifi_mqtt_device_id());

    // Main loop - just wait for MQTT commands
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
