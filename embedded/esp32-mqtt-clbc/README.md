# ESP32 MQTT CLBC Firmware

ESP32 firmware that connects to WiFi, subscribes to MQTT commands, and runs CLBC and CANBC programs deterministically.

## Features

- WiFi station mode connection
- MQTT client (ESP-IDF mqtt component)
- CLBC VM execution (deterministic)
- CAN-ISA MVP execution (`.canbc`) (deterministic)
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
// "auto" derives a stable ID from the device MAC (recommended for zero-config demos).
#define DEVICE_ID "auto"
```

## MQTT Topics

### Subscribed
- `bicf/{device_id}/command` - Commands to execute

### Published
- `bicf/{device_id}/status` - Status updates (program loaded, etc.)
- `bicf/{device_id}/events` - CLBC execution results
- `bicf/announce/{device_id}` - Retained announce payload for zero-config discovery

## Commands

### Load Program
```json
{
  "type": "load_program",
  "clbc_hex": "434c4254..."
}
```

### Load CANBC
```json
{
  "type": "load_canbc",
  "canbc_hex": "43414e4243..."
}
```

### Run Program
```json
{
  "type": "run"
}
```

## Result Fields

`bicf/{device_id}/events` includes:
- `transcript_hash`: CLBC transcript hash OR CANBC state hash (for backward compatibility)
- `events`: event count
- `ok`: boolean
- `exec_ms`: device-side execution time in milliseconds (best-effort)
- `fano_hash`: present when CANBC `PROJ_FANO` was executed (or computed by the firmware)

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

### Zero-config discovery

When `DEVICE_ID` is `"auto"`, each ESP32 publishes a **retained** announce message to:
- `bicf/announce/{device_id}`

Host tools can subscribe to `bicf/announce/#` and auto-discover devices without fixed IPs or hardcoded IDs.

### UDP discovery (optional)

The firmware also sends UDP multicast discovery beacons and responds to UDP queries:
- Multicast group: `239.255.42.42:4242`
- Query payload: `BICF_DISCOVERY_QUERY`
- Hello payload: `BICF_DISCOVERY_HELLO <device_id>`

This helps a laptop discover device IDs even if you don’t want to rely on MQTT announce.

## 3-Device Test Setup

For heterogeneous network testing:

1. **ESP32 A**: Flash with `DEVICE_ID="esp32-a"`
2. **ESP32 B**: Flash with `DEVICE_ID="esp32-b"`
3. **Pico 2 / Pico 2 W**: Use USB CDC bridge (`tools/pico-mqtt-bridge.py`)
4. **MQTT Broker**: Run Mosquitto (`scripts/setup-3device-test.sh --start-broker`)

All devices receive same CLBC program, execute deterministically, and publish transcript hashes. Verify all hashes match to prove cross-architecture determinism.
