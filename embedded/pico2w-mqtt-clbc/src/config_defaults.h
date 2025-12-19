#ifndef PICO2W_MQTT_CLBC_CONFIG_DEFAULTS_H
#define PICO2W_MQTT_CLBC_CONFIG_DEFAULTS_H

// Defaults compile without secrets. Prefer creating src/config_local.h and leaving this as-is.

#define WIFI_SSID "YOUR_SSID"
#define WIFI_PASSWORD "YOUR_PASSWORD"

// Broker host:
// - "gateway": use the DHCP gateway (works well for phone hotspot brokers)
// - IP literal: "10.0.0.1"
// - hostname: "broker.local" (requires DNS)
#define MQTT_BROKER_HOST "gateway"
#define MQTT_BROKER_PORT 1883

#define MQTT_COMMAND_TOPIC "bicf/pico/command"
#define MQTT_EVENTS_TOPIC "bicf/pico/events"

#define MQTT_CLIENT_ID "pico"

#define MAX_CLBC_PROGRAM 4096

#endif
