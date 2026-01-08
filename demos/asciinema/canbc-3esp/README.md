# CANBC 3×ESP32 Demo (asciinema → GIF)

Records a terminal demo showing:
- CANBC assembly (`.canbc`)
- UDP discovery (optional) + MQTT load/run across 3 ESP32 devices
- Deterministic parity (matching hashes)

## Requirements

- `asciinema` (recording)
- `agg` (render to GIF): https://docs.asciinema.org/manual/agg/usage/
- `python3` + `paho-mqtt` (host tool)
- A reachable MQTT broker (e.g. `mosquitto`)

## Record

```bash
# Start a broker (example):
cat >/tmp/mosquitto-demo.conf <<'EOF'
listener 1883 0.0.0.0
allow_anonymous true
EOF
mosquitto -c /tmp/mosquitto-demo.conf -v

# In another terminal:
BROKER=127.0.0.1 DISCOVERY=mqtt demos/asciinema/canbc-3esp/record.sh
# or UDP discovery (works only if multicast + client-to-client are allowed):
BROKER=127.0.0.1 DISCOVERY=udp demos/asciinema/canbc-3esp/record.sh
```

Output: `demos/asciinema/canbc-3esp/canbc-3esp.cast`

## Render GIF

```bash
THEME=dracula demos/asciinema/canbc-3esp/render.sh
```

Output: `demos/asciinema/canbc-3esp/render/canbc-3esp-<theme>.gif`

