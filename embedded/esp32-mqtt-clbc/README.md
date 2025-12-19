# ESP32 MQTT CLBC Firmware

ESP32 firmware that connects to WiFi, subscribes to MQTT commands, and runs CLBC programs deterministically.

## Features

- WiFi station mode connection
- MQTT client (ESP-IDF mqtt component)
- CLBC VM execution (deterministic)
- Publishes results to MQTT topics
- Supports remote command execution

## Configuration

Copy `main/config_local.example.h` to `main/config_local.h` and configure:

```c
#define WIFI_SSID "YOUR_SSID"
#define WIFI_PASSWORD "YOUR_PASSWORD"
// For phone hotspot brokers, "gateway" usually works best.
#define MQTT_BROKER_HOST "gateway"
#define MQTT_BROKER_PORT 1883
#define DEVICE_ID "esp32-a"  // set to "esp32-b" for the second device
```

## MQTT Topics

### Subscribed
- `bicf/{device_id}/command` - Commands to execute

### Published
- `bicf/{device_id}/status` - Status updates (program loaded, etc.)
- `bicf/{device_id}/events` - CLBC execution results

## Commands

### Load Program
```json
{
  "type": "load_program",
  "clbc_hex": "434c4254..."
}
```

### Run Program
```json
{
  "type": "run"
}
```

## Build

```bash
cd embedded/esp32-mqtt-clbc
idf.py build
idf.py flash
```

## Usage

1. Flash firmware to ESP32
2. Configure WiFi and MQTT broker settings
3. Device connects to WiFi and MQTT broker
4. Send commands via MQTT to `bicf/{device_id}/command`
5. Results published to `bicf/{device_id}/events`

## 3-Device Test Setup

For heterogeneous network testing:

1. **ESP32 A**: Flash with `DEVICE_ID="esp32-a"`
2. **ESP32 B**: Flash with `DEVICE_ID="esp32-b"`
3. **Pico 2 / Pico 2 W**: Use USB CDC bridge (`tools/pico-mqtt-bridge.py`)
4. **MQTT Broker**: Run Mosquitto (`scripts/setup-3device-test.sh --start-broker`)

All devices receive same CLBC program, execute deterministically, and publish transcript hashes. Verify all hashes match to prove cross-architecture determinism.
