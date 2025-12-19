# ESP32 MQTT Client Implementation Status

## ✅ Complete

### ESP32 MQTT CLBC Firmware
- **Location:** `embedded/esp32-mqtt-clbc/`
- **Status:** ✅ Complete
- **Features:**
  - WiFi station mode connection
  - MQTT client (ESP-IDF mqtt component)
  - CLBC VM execution (deterministic)
  - Remote command execution via MQTT
  - Result publishing to MQTT topics

### Components

1. **WiFi/MQTT Module** (`main/wifi_mqtt.c`)
   - WiFi station initialization
   - MQTT client setup and connection
   - Automatic reconnection on disconnect
   - Topic subscription management

2. **Main Application** (`main/main.c`)
   - MQTT command handler
   - CLBC program loading (hex-encoded)
   - CLBC program execution
   - Result publishing

3. **CLBC VM** (`main/clbc_vm.c`)
   - Copied from `esp32-clbc-sha`
   - Deterministic execution
   - Transcript hash computation

## MQTT Protocol

### Topics

**Subscribed:**
- `bicf/{device_id}/command` - Commands to execute

**Published:**
- `bicf/{device_id}/status` - Status updates
- `bicf/{device_id}/events` - CLBC execution results

### Commands

**Load Program:**
```json
{
  "type": "load_program",
  "clbc_hex": "434c4254..."
}
```

**Run Program:**
```json
{
  "type": "run"
}
```

### Results

**Status Response:**
```json
{
  "device": "esp32-a",
  "status": "loaded",
  "size": 256
}
```

**Execution Result:**
```json
{
  "device": "esp32-a",
  "transcript_hash": "b00758344445a0297a1cd4fcecb5b35e692c4013b95d51e304b8741133b75abe",
  "events": 10,
  "ok": true
}
```

## Configuration

Copy `main/config_local.example.h` to `main/config_local.h` (ignored by git):

```c
#define WIFI_SSID "YOUR_SSID"
#define WIFI_PASSWORD "YOUR_PASSWORD"
// For phone hotspot brokers, "gateway" usually works best.
#define MQTT_BROKER_HOST "gateway"
#define MQTT_BROKER_PORT 1883
#define DEVICE_ID "esp32-a"  // or "esp32-b"
```

## Build and Flash

```bash
cd embedded/esp32-mqtt-clbc
idf.py build
idf.py flash
```

## 3-Device Test Setup

### Prerequisites

1. **MQTT Broker** (Mosquitto)
   ```bash
   scripts/setup-3device-test.sh --start-broker
   ```

2. **ESP32 A** - Flash with `DEVICE_ID="esp32-a"`
3. **ESP32 B** - Flash with `DEVICE_ID="esp32-b"`
4. **Pico 2 / Pico 2 W** - Use USB CDC bridge:
   ```bash
   python3 tools/pico-mqtt-bridge.py /dev/ttyACM0 --broker localhost
   ```

### Test Flow

1. All devices connect to MQTT broker
2. Send same CLBC program to all devices:
   ```json
   {
     "type": "load_program",
     "clbc_hex": "..."
   }
   ```
3. Send run command to all devices:
   ```json
   {
     "type": "run"
   }
   ```
4. Collect transcript hashes from all devices
5. Verify all hashes match (proves cross-architecture determinism)

## Next Steps

1. **Create test script** - Automated 3-device test
2. **Add menuconfig** - WiFi/MQTT configuration via menuconfig
3. **Add NVS storage** - Store WiFi credentials in NVS
4. **Add OTA updates** - Update CLBC programs via MQTT

## References

- **ESP-IDF MQTT:** https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/protocols/mqtt.html
- **CLBC VM:** `embedded/esp32-clbc-sha/main/clbc_vm.c`
- **Pico Bridge:** `tools/pico-mqtt-bridge.py`
- **Setup Script:** `scripts/setup-3device-test.sh`
