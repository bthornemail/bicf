#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "esp_log.h"
#include "esp_system.h"
#include "esp_chip_info.h"
#include "esp_event.h"
#include "mqtt_client.h"
#include "cJSON.h"
#include "mbedtls/sha256.h"

#include "clbc_vm.h"
#include "wifi_mqtt.h"

static const char *TAG = "mqtt_clbc";

// Configuration (would normally come from menuconfig or NVS)
#define WIFI_SSID "YourNetwork"
#define WIFI_PASSWORD "YourPassword"
#define MQTT_BROKER_HOST "192.168.1.100"
#define MQTT_BROKER_PORT 1883
#define DEVICE_ID "esp32-a"  // Change to "esp32-b" for second device

static uint8_t g_clbc_program[4096] = {0};
static size_t g_clbc_program_len = 0;

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

        // Decode hex string to binary
        size_t hex_len = strlen(clbc_hex);
        if (hex_len % 2 != 0 || hex_len / 2 > sizeof(g_clbc_program)) {
            ESP_LOGE(TAG, "Invalid CLBC hex length");
            cJSON_Delete(json);
            return;
        }

        for (size_t i = 0; i < hex_len / 2; i++) {
            char hex_byte[3] = {clbc_hex[i * 2], clbc_hex[i * 2 + 1], '\0'};
            g_clbc_program[i] = (uint8_t)strtol(hex_byte, NULL, 16);
        }
        g_clbc_program_len = hex_len / 2;

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

    } else if (strcmp(cmd_type, "run") == 0) {
        // Run CLBC program
        if (g_clbc_program_len == 0) {
            ESP_LOGE(TAG, "No CLBC program loaded");
            cJSON_Delete(json);
            return;
        }

        ESP_LOGI(TAG, "Running CLBC program...");

        clbc_vm_result_t vm = {0};
        if (clbc_vm_run(g_clbc_program, g_clbc_program_len, &vm)) {
            char vm_hex[65] = {0};
            bytes_to_hex(vm.transcript_sha256, 32, vm_hex, sizeof(vm_hex));

            ESP_LOGI(TAG, "CLBC execution complete:");
            ESP_LOGI(TAG, "  OK: %d", vm.ok ? 1 : 0);
            ESP_LOGI(TAG, "  Events: %" PRIu32, vm.events);
            ESP_LOGI(TAG, "  Transcript hash: %s", vm_hex);

            // Publish result
            wifi_mqtt_publish_result(vm_hex, vm.events, vm.ok);
        } else {
            ESP_LOGE(TAG, "CLBC execution failed");
            wifi_mqtt_publish_result("", 0, false);
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
    ESP_LOGI(TAG, "Device ID: %s", DEVICE_ID);

    // Print chip info
    esp_chip_info_t chip_info;
    esp_chip_info(&chip_info);
    ESP_LOGI(TAG, "Chip: %s, Cores: %d, Revision: %d",
             (chip_info.model == CHIP_ESP32S3) ? "ESP32-S3" : "ESP32",
             chip_info.cores, chip_info.revision);

    // Initialize WiFi and MQTT
    wifi_mqtt_config_t config = {
        .ssid = WIFI_SSID,
        .password = WIFI_PASSWORD,
        .broker_host = MQTT_BROKER_HOST,
        .broker_port = MQTT_BROKER_PORT,
        .client_id = DEVICE_ID,
        .device_id = DEVICE_ID
    };

    if (!wifi_mqtt_init(&config)) {
        ESP_LOGE(TAG, "Failed to initialize WiFi/MQTT");
        return;
    }

    // Note: MQTT event handler is registered in wifi_mqtt_init()
    // Additional handlers can be registered here if needed

    ESP_LOGI(TAG, "Initialization complete. Waiting for commands on: bicf/%s/command", DEVICE_ID);

    // Main loop - just wait for MQTT commands
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

