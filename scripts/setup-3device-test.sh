#!/usr/bin/env bash
# Setup script for 3-device heterogeneous network test
# 2×ESP32-S3 + 1×Pico W2 over MQTT

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
usage: scripts/setup-3device-test.sh [options]

Sets up 3-device heterogeneous network test environment:
- Mosquitto MQTT broker (Docker container)
- ESP32-S3 A and B (connect via WiFi to MQTT)
- Pico W2 (via USB CDC bridge to MQTT)

options:
  --broker-host <host>    MQTT broker host (default: localhost)
  --broker-port <port>    MQTT broker port (default: 1883)
  --pico-port <port>      Pico USB CDC port (default: /dev/ttyACM0)
  --esp32-a-port <port>   ESP32 A UART port (optional)
  --esp32-b-port <port>   ESP32 B UART port (optional)
  --start-broker          Start Mosquitto broker in Docker
  --start-bridge          Start Pico USB CDC → MQTT bridge
EOF
}

BROKER_HOST="${BROKER_HOST:-localhost}"
BROKER_PORT="${BROKER_PORT:-1883}"
PICO_PORT="${PICO_PORT:-/dev/ttyACM0}"
START_BROKER=false
START_BRIDGE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --broker-host) BROKER_HOST="$2"; shift 2 ;;
    --broker-port) BROKER_PORT="$2"; shift 2 ;;
    --pico-port) PICO_PORT="$2"; shift 2 ;;
    --start-broker) START_BROKER=true; shift ;;
    --start-bridge) START_BRIDGE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

echo "=========================================="
echo "3-Device Heterogeneous Network Test Setup"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  MQTT Broker: $BROKER_HOST:$BROKER_PORT"
echo "  Pico W2: $PICO_PORT"
echo ""

# Start Mosquitto broker if requested
if [ "$START_BROKER" = "true" ]; then
  echo "[1/3] Starting Mosquitto MQTT broker..."
  if ! docker ps | grep -q mosquitto; then
    docker run -d --name bicf-mosquitto \
      -p "$BROKER_PORT:1883" \
      -p 9001:9001 \
      eclipse-mosquitto:latest
    echo "  Broker started on port $BROKER_PORT"
  else
    echo "  Broker already running"
  fi
fi

# Start Pico bridge if requested
if [ "$START_BRIDGE" = "true" ]; then
  echo "[2/3] Starting Pico USB CDC → MQTT bridge..."
  if [ ! -e "$PICO_PORT" ]; then
    echo "error: Pico port not found: $PICO_PORT" >&2
    exit 2
  fi
  
  # Check if paho-mqtt is installed
  if ! python3 -c "import paho.mqtt.client" 2>/dev/null; then
    echo "Installing paho-mqtt..."
    pip install paho-mqtt
  fi
  
  echo "  Bridge: $PICO_PORT → MQTT ($BROKER_HOST:$BROKER_PORT)"
  echo "  Run in background: tools/pico-mqtt-bridge.py $PICO_PORT --broker $BROKER_HOST --port $BROKER_PORT"
fi

echo ""
echo "[3/3] ESP32 Configuration"
echo ""
echo "For ESP32-S3 A and B, configure WiFi and MQTT client:"
echo "  - WiFi SSID: <your-network>"
echo "  - WiFi Password: <your-password>"
echo "  - MQTT Broker: $BROKER_HOST"
echo "  - MQTT Port: $BROKER_PORT"
echo ""
echo "ESP32 firmware should:"
echo "  1. Connect to WiFi"
echo "  2. Connect to MQTT broker"
echo "  3. Subscribe to: bicf/esp32-a/command (for ESP32 A)"
echo "  4. Subscribe to: bicf/esp32-b/command (for ESP32 B)"
echo "  5. Publish to: bicf/esp32-a/events (for ESP32 A)"
echo "  6. Publish to: bicf/esp32-b/events (for ESP32 B)"
echo ""
echo "Test topics:"
echo "  - bicf/pico/events - Pico W2 events (via bridge)"
echo "  - bicf/esp32-a/events - ESP32 A events"
echo "  - bicf/esp32-b/events - ESP32 B events"
echo "  - bicf/consensus/result - Final consensus result"
echo ""
echo "To test deterministic replay:"
echo "  1. Send same CLBC program to all 3 devices"
echo "  2. Collect transcript hashes from all devices"
echo "  3. Verify all hashes match (proves cross-architecture determinism)"
echo ""

