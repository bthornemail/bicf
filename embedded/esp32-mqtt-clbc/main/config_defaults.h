#pragma once

// Defaults compile without secrets. Create config_local.h (ignored by git).

#define WIFI_SSID "YOUR_SSID"
#define WIFI_PASSWORD "YOUR_PASSWORD"

// Broker host:
// - "gateway": use the DHCP gateway (works well for phone hotspot brokers)
// - IP literal: "10.0.0.1"
// - hostname: "broker.local" (DNS via your network stack)
#define MQTT_BROKER_HOST "gateway"
#define MQTT_BROKER_PORT 1883

// Must be unique per device.
#define DEVICE_ID "esp32-a"
