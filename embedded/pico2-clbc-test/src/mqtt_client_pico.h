#ifndef MQTT_CLIENT_PICO_H
#define MQTT_CLIENT_PICO_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// MQTT client for Pico W2 (requires WiFi-capable Pico W variant)
// Minimal MQTT 3.1.1 client for deterministic event ordering

#define MQTT_MAX_TOPIC_LEN 128
#define MQTT_MAX_PAYLOAD_LEN 512
#define MQTT_MAX_CLIENT_ID_LEN 64
#define MQTT_DEFAULT_PORT 1883
#define MQTT_KEEP_ALIVE 60

// MQTT message structure
typedef struct {
    char topic[MQTT_MAX_TOPIC_LEN];
    uint8_t payload[MQTT_MAX_PAYLOAD_LEN];
    size_t payload_len;
    uint8_t qos;  // 0, 1, or 2
    bool retain;
} mqtt_message_t;

// MQTT client context
typedef struct {
    char client_id[MQTT_MAX_CLIENT_ID_LEN];
    char broker_host[64];
    uint16_t broker_port;
    bool connected;
    uint16_t packet_id;
    // WiFi connection state (would be managed by Pico SDK WiFi)
    void *wifi_state;
} mqtt_client_t;

// Initialize MQTT client
bool mqtt_client_init(mqtt_client_t *client, const char *client_id, const char *broker_host, uint16_t broker_port);

// Connect to MQTT broker (requires WiFi to be initialized first)
bool mqtt_connect(mqtt_client_t *client, const char *username, const char *password);

// Disconnect from broker
void mqtt_disconnect(mqtt_client_t *client);

// Publish message
bool mqtt_publish(mqtt_client_t *client, const char *topic, const uint8_t *payload, size_t payload_len, uint8_t qos, bool retain);

// Subscribe to topic
bool mqtt_subscribe(mqtt_client_t *client, const char *topic, uint8_t qos);

// Unsubscribe from topic
bool mqtt_unsubscribe(mqtt_client_t *client, const char *topic);

// Process incoming messages (call periodically)
bool mqtt_process(mqtt_client_t *client);

// Set message callback (called when message received)
typedef void (*mqtt_message_callback_t)(const mqtt_message_t *msg, void *user_data);
void mqtt_set_message_callback(mqtt_client_t *client, mqtt_message_callback_t callback, void *user_data);

// Check if connected
bool mqtt_is_connected(mqtt_client_t *client);

#endif  // MQTT_CLIENT_PICO_H

