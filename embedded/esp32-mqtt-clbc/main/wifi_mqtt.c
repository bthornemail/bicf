#include "wifi_mqtt.h"
#include <string.h>
#include <stdio.h>
#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_netif.h"
#include "esp_event.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "mqtt_client.h"
#include "cJSON.h"

static const char *TAG = "wifi_mqtt";

static esp_mqtt_client_handle_t g_mqtt_client = NULL;
static bool g_connected = false;
static char g_device_id[32] = {0};
static char g_mqtt_uri[128] = {0};
static char g_broker_host[64] = {0};
static int g_broker_port = 1883;
static char g_client_id[32] = {0};
static bool g_broker_is_gateway = false;
static bool g_mqtt_started = false;
static char g_ip_str[16] = {0};
static char g_gw_str[16] = {0};
static bool g_announce_task_started = false;

static void publish_announce(void) {
    if (!g_mqtt_client || !wifi_mqtt_is_connected() || !g_device_id[0]) {
        return;
    }

    cJSON *json = cJSON_CreateObject();
    cJSON_AddStringToObject(json, "id", g_device_id);
    cJSON_AddStringToObject(json, "kind", "esp32");
    cJSON_AddStringToObject(json, "fw", "esp32-mqtt-clbc");
    cJSON *caps = cJSON_CreateArray();
    cJSON_AddItemToArray(caps, cJSON_CreateString("clbc"));
    cJSON_AddItemToArray(caps, cJSON_CreateString("canbc"));
    cJSON_AddItemToObject(json, "caps", caps);
    if (g_ip_str[0]) cJSON_AddStringToObject(json, "ip", g_ip_str);
    if (g_gw_str[0]) cJSON_AddStringToObject(json, "gw", g_gw_str);

    char *payload = cJSON_PrintUnformatted(json);
    if (payload) {
        char topic[96];
        snprintf(topic, sizeof(topic), "bicf/announce/%s", g_device_id);
        esp_mqtt_client_publish(g_mqtt_client, topic, payload, 0, 1, 1);
        free(payload);
    }
    cJSON_Delete(json);
}

static void announce_task(void *arg) {
    (void)arg;
    // Periodic retained announce so hosts can discover devices even if they start later,
    // and even if the broker lost retained state (no persistence).
    for (;;) {
        if (wifi_mqtt_is_connected()) {
            publish_announce();
        }
        vTaskDelay(pdMS_TO_TICKS(3000));
    }
}

static void mqtt_event_handler_internal(void *handler_args, esp_event_base_t base,
                                        int32_t event_id, void *event_data);

static void mqtt_start_with_uri(const char* uri) {
    if (g_mqtt_started || g_mqtt_client) return;
    if (!uri || !uri[0]) return;

    esp_mqtt_client_config_t mqtt_cfg = {0};
    mqtt_cfg.broker.address.uri = uri;
    mqtt_cfg.credentials.client_id = g_client_id[0] ? g_client_id : NULL;

    g_mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    if (!g_mqtt_client) {
        ESP_LOGE(TAG, "Failed to initialize MQTT client");
        return;
    }

    esp_mqtt_client_register_event(g_mqtt_client, ESP_EVENT_ANY_ID, mqtt_event_handler_internal, NULL);
    esp_mqtt_client_start(g_mqtt_client);
    g_mqtt_started = true;
}

static void wifi_event_handler(void* arg, esp_event_base_t event_base,
                               int32_t event_id, void* event_data) {
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        ESP_LOGI(TAG, "WiFi disconnected, retrying...");
        esp_wifi_connect();
        g_connected = false;
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "WiFi connected, IP: " IPSTR, IP2STR(&event->ip_info.ip));
        g_connected = true;

        snprintf(g_ip_str, sizeof(g_ip_str), IPSTR, IP2STR(&event->ip_info.ip));
        snprintf(g_gw_str, sizeof(g_gw_str), IPSTR, IP2STR(&event->ip_info.gw));

        if (g_broker_is_gateway && !g_mqtt_started) {
            snprintf(g_mqtt_uri, sizeof(g_mqtt_uri), "mqtt://" IPSTR ":%d", IP2STR(&event->ip_info.gw), g_broker_port);
            ESP_LOGI(TAG, "Starting MQTT broker at gateway: %s", g_mqtt_uri);
            mqtt_start_with_uri(g_mqtt_uri);
        }
    }
}

// MQTT event handler - registered in wifi_mqtt_init()
// Commands are handled in main.c via mqtt_event_handler
static void mqtt_event_handler_internal(void *handler_args, esp_event_base_t base,
                                        int32_t event_id, void *event_data) {
    esp_mqtt_event_handle_t event = (esp_mqtt_event_handle_t)event_data;
    esp_mqtt_client_handle_t client = event->client;

    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED:
        ESP_LOGI(TAG, "MQTT connected");
        {
            char topic[64];
            snprintf(topic, sizeof(topic), "bicf/%s/command", g_device_id);
            esp_mqtt_client_subscribe(client, topic, 1);
            ESP_LOGI(TAG, "Subscribed to: %s", topic);
            publish_announce();
            if (!g_announce_task_started) {
                g_announce_task_started = true;
                (void)xTaskCreate(announce_task, "bicf_announce", 4096, NULL, 4, NULL);
            }
        }
        g_connected = true;
        break;
    case MQTT_EVENT_DISCONNECTED:
        ESP_LOGI(TAG, "MQTT disconnected");
        g_connected = false;
        break;
    case MQTT_EVENT_ERROR:
        ESP_LOGI(TAG, "MQTT error");
        break;
    default:
        break;
    }
}

bool wifi_mqtt_init(const wifi_mqtt_config_t *config) {
    if (!config) return false;

    strncpy(g_device_id, config->device_id, sizeof(g_device_id) - 1);
    g_device_id[sizeof(g_device_id) - 1] = '\0';
    strncpy(g_broker_host, config->broker_host, sizeof(g_broker_host) - 1);
    g_broker_host[sizeof(g_broker_host) - 1] = '\0';
    g_broker_port = config->broker_port;
    strncpy(g_client_id, config->client_id, sizeof(g_client_id) - 1);
    g_client_id[sizeof(g_client_id) - 1] = '\0';
    g_broker_is_gateway = strcmp(g_broker_host, "gateway") == 0;

    // Initialize NVS
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    // Initialize network interface
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    // Initialize WiFi
    esp_netif_create_default_wifi_sta();
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL));

    wifi_config_t wifi_config = {0};
    strncpy((char*)wifi_config.sta.ssid, config->ssid, sizeof(wifi_config.sta.ssid) - 1);
    strncpy((char*)wifi_config.sta.password, config->password, sizeof(wifi_config.sta.password) - 1);
    wifi_config.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "WiFi initialization finished, connecting to: %s", config->ssid);

    // Initialize MQTT client:
    // - If broker_host == "gateway", wait for DHCP gateway in IP_EVENT_STA_GOT_IP.
    // - Otherwise build a URI immediately.
    if (!g_broker_is_gateway) {
        snprintf(g_mqtt_uri, sizeof(g_mqtt_uri), "mqtt://%s:%d", g_broker_host, g_broker_port);
        mqtt_start_with_uri(g_mqtt_uri);
    }

    return true;
}

esp_mqtt_client_handle_t wifi_mqtt_get_client(void) {
    return g_mqtt_client;
}

bool wifi_mqtt_is_connected(void) {
    return g_connected && g_mqtt_client != NULL;
}

bool wifi_mqtt_publish_result(const char *transcript_hash, const char *fano_hash, uint32_t events, bool ok, uint32_t exec_ms) {
    if (!g_mqtt_client || !wifi_mqtt_is_connected()) {
        return false;
    }

    cJSON *json = cJSON_CreateObject();
    cJSON_AddStringToObject(json, "device", g_device_id);
    cJSON_AddStringToObject(json, "transcript_hash", transcript_hash);
    if (fano_hash && fano_hash[0]) {
        cJSON_AddStringToObject(json, "fano_hash", fano_hash);
    }
    cJSON_AddNumberToObject(json, "events", events);
    cJSON_AddBoolToObject(json, "ok", ok);
    if (exec_ms > 0) {
        cJSON_AddNumberToObject(json, "exec_ms", exec_ms);
    }

    char *json_str = cJSON_Print(json);
    if (!json_str) {
        cJSON_Delete(json);
        return false;
    }

    char topic[64];
    snprintf(topic, sizeof(topic), "bicf/%s/events", g_device_id);

    int msg_id = esp_mqtt_client_publish(g_mqtt_client, topic, json_str, 0, 1, 0);
    free(json_str);
    cJSON_Delete(json);

    return msg_id >= 0;
}

const char *wifi_mqtt_device_id(void) {
    return g_device_id;
}
