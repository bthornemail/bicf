#ifndef PICO2W_MQTT_CLBC_CONFIG_LOCAL_H
#define PICO2W_MQTT_CLBC_CONFIG_LOCAL_H

// Copy to config_local.h and edit.

#undef WIFI_SSID
#undef WIFI_PASSWORD
#undef MQTT_BROKER_HOST
#undef MQTT_BROKER_PORT
#undef MQTT_CLIENT_ID

#define WIFI_SSID "YOUR_SSID"
#define WIFI_PASSWORD "YOUR_PASSWORD"
// For phone hotspot brokers, "gateway" usually works best.
#define MQTT_BROKER_HOST "gateway"
#define MQTT_BROKER_PORT 1883
#define MQTT_CLIENT_ID "pico"

#endif
