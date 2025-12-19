# Pico 2 W MQTT CLBC firmware (power-only demo)

Runs the deterministic CLBC VM on **Pico 2 W** and exposes it over **MQTT**:

- Subscribes: `bicf/pico/command`
- Publishes: `bicf/pico/events`

This lets you run the 3-device test without needing a USB data port for the Pico (after flashing).

## Configure

Copy `src/config_local.example.h` to `src/config_local.h` and set:

- `WIFI_SSID` / `WIFI_PASSWORD`
- `MQTT_BROKER_HOST` / `MQTT_BROKER_PORT`

For a phone hotspot broker, `MQTT_BROKER_HOST="gateway"` usually works best (it resolves to the DHCP gateway).

Hotspot IP changes aren’t a problem if you use the **gateway IP** (the devices always route through it). To find it from your laptop while connected to the hotspot:

```bash
ip route | awk '/^default/ {print $3}'
```

## Build

Run once to get `pico-sdk` + toolchain (reuses the existing bootstrap):

```bash
embedded/pico2-clbc-test/bootstrap.sh
```

Then:

```bash
export PICO_SDK_PATH="$PWD/.deps/pico-sdk"
cd embedded/pico2w-mqtt-clbc
cmake -S . -B build -G Ninja -DPICO_BOARD=pico2_w
cmake --build build
```

UF2: `embedded/pico2w-mqtt-clbc/build/pico2w_mqtt_clbc.uf2`

## Flash

BOOTSEL → copy UF2 to `/media/$USER/RP2350/` (or run `scripts/flash-pico2w-mqtt-clbc.sh`).

## 3-device test (power-only)

1. Run an MQTT broker on your hotspot network (phone or any other device).
2. Flash `embedded/esp32-mqtt-clbc` to two ESP32s (set `DEVICE_ID` to `esp32-a` and `esp32-b`).
3. Flash this firmware to the Pico 2 W.
4. From the laptop, publish a `.clbc` program to all three devices and compare hashes:

```bash
pip install paho-mqtt
guile -s tools/canvasl-to-clbc.scm tests/clbc/mini-validation.input.scm /tmp/mini.clbc
python3 tools/mqtt-clbc-3device.py --broker 192.168.43.1 --clbc /tmp/mini.clbc
```
