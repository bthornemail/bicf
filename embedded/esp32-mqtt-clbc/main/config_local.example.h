#pragma once

// Copy to config_local.h and edit (this file is ignored by git).

#undef WIFI_SSID
#undef WIFI_PASSWORD
#undef MQTT_BROKER_HOST
#undef MQTT_BROKER_PORT
#undef DEVICE_ID

#define WIFI_SSID "YOUR_SSID"
#define WIFI_PASSWORD "YOUR_PASSWORD"
// For phone hotspot brokers, "gateway" usually works best.
#define MQTT_BROKER_HOST "gateway"
#define MQTT_BROKER_PORT 1883

// For zero-config demos, keep "auto" so each device derives a stable ID from its MAC.
// Or set a friendly fixed ID like "esp32-a".
#define DEVICE_ID "auto"
