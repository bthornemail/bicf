# Network Implementation Status for Pico 2 / Pico 2 W

## Hardware Note

**Important:** There are two relevant boards:
- **Pico 2 (RP2350)**: no WiFi
- **Pico 2 W (RP2350 + CYW43)**: WiFi/Bluetooth available

If you have:
- **Pico 2**: Use USB CDC only (or add an external network module)
- **Pico 2 W**: You can implement WiFi + TCP/IP + MQTT on-device (not complete yet)

## Current Status

### WiFi Interface ⚠️ Placeholder
- **Files:** `wifi_pico.h`, `wifi_pico.c`
- **Status:** Structure created, requires Pico SDK WiFi integration
- **Dependencies:** Pico SDK `cyw43` driver, `lwIP` TCP/IP stack

### MQTT Client ⚠️ Placeholder
- **Files:** `mqtt_client_pico.h`, `mqtt_client_pico.c`
- **Status:** Structure created, requires TCP socket implementation
- **Dependencies:** WiFi connection, TCP/IP stack (lwIP)

## Implementation Requirements

### For Pico 2 W / Pico W (WiFi variants):

1. **Enable WiFi in CMakeLists.txt:**
```cmake
target_link_libraries(pico2_clbc_test
  pico_stdlib
  pico_wifi
  cyw43_driver
  lwip
  tinyusb_device
  tinyusb_board
)
```

2. **Initialize WiFi:**
```c
#include "wifi_pico.h"

wifi_init();
wifi_config_t config = {
    .ssid = "YourNetwork",
    .password = "YourPassword",
    .channel = 0  // auto
};
wifi_connect(&config);
```

3. **Use MQTT:**
```c
#include "mqtt_client_pico.h"

mqtt_client_t client;
mqtt_client_init(&client, "pico-client", "192.168.1.100", 1883);
mqtt_connect(&client, NULL, NULL);  // No auth
mqtt_subscribe(&client, "bicf/events", 1);
mqtt_publish(&client, "bicf/state", data, len, 1, false);
```

## Alternative: USB CDC Bridge ✅ Implemented

If using Pico 2 (or if you want to avoid implementing MQTT on-device), use USB CDC as bridge:

1. Pico 2 communicates via USB CDC to host
2. Host runs MQTT client (Python script)
3. Host bridges USB CDC ↔ MQTT broker
4. ESP32s connect directly to MQTT broker via WiFi

**Implementation:**
- **File:** `tools/pico-mqtt-bridge.py`
- **Status:** ✅ Complete
- **Usage:**
  ```bash
  python3 tools/pico-mqtt-bridge.py /dev/ttyACM0 --broker localhost --port 1883
  ```

**Features:**
- Bridges CLBT protocol (LOAD_PROGRAM, RUN) to MQTT
- Publishes Pico events to `bicf/pico/events`
- Subscribes to `bicf/pico/command` for remote control
- Handles frame encoding/decoding
- Supports deterministic replay validation

This allows 3-device testing without requiring WiFi on Pico.

## Next Steps

1. ✅ **USB CDC Bridge:** Complete - `tools/pico-mqtt-bridge.py`
2. ✅ **Setup Script:** Complete - `scripts/setup-3device-test.sh`
3. ⏳ **If Pico 2 W / Pico W:** Complete WiFi and MQTT implementation (requires Pico SDK WiFi)
4. ⏳ **ESP32 MQTT Client:** Add MQTT client to ESP32 firmware
5. ⏳ **Test 3-device setup:** 2×ESP32 + 1×Pico over MQTT broker
6. ⏳ **Deterministic validation:** Verify same CLBC program produces identical hash on all 3 devices
