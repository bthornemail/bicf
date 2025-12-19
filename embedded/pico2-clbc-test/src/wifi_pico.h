#ifndef WIFI_PICO_H
#define WIFI_PICO_H

#include <stdbool.h>
#include <stdint.h>

// WiFi interface for WiFi-capable Pico boards (Pico W / Pico 2 W class).
// NOTE: This is currently a placeholder API.
// This is for WiFi-capable Pico variants (CYW43-based boards like Pico W / Pico 2 W).

#define WIFI_MAX_SSID_LEN 32
#define WIFI_MAX_PASSWORD_LEN 64

// WiFi connection status
typedef enum {
    WIFI_DISCONNECTED,
    WIFI_CONNECTING,
    WIFI_CONNECTED,
    WIFI_ERROR
} wifi_status_t;

// WiFi configuration
typedef struct {
    char ssid[WIFI_MAX_SSID_LEN];
    char password[WIFI_MAX_PASSWORD_LEN];
    uint8_t channel;  // 0 = auto
} wifi_config_t;

// Initialize WiFi (must be called before connecting)
bool wifi_init(void);

// Connect to WiFi network
bool wifi_connect(const wifi_config_t *config);

// Disconnect from WiFi
void wifi_disconnect(void);

// Get connection status
wifi_status_t wifi_get_status(void);

// Get IP address (returns 0.0.0.0 if not connected)
void wifi_get_ip(uint8_t ip[4]);

// Check if connected
bool wifi_is_connected(void);

#endif  // WIFI_PICO_H
