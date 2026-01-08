#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
usage: scripts/demo-canbc-3esp.sh [options]

Builds a demo `.canbc` program and runs it over MQTT on 3×ESP32 devices:
  esp32-a, esp32-b, esp32-c (or auto-discovered via MQTT announce)

options:
  --broker <host>     MQTT broker host (default: 127.0.0.1)
  --port <port>       MQTT broker port (default: 1883)
  --input <file.scm>  CAN-ISA program (Scheme s-expr) (default: tests/canisa/canisa-mini.input.scm)
  --out <file.canbc>  Output `.canbc` path (default: /tmp/bicf-demo.canbc)
  --auto              Auto-discover 3 ESP32 devices via `bicf/announce/<id>`
  --udp               Auto-discover 3 ESP32 devices via UDP multicast (no MQTT announce needed)
EOF
}

BROKER="127.0.0.1"
PORT="1883"
INPUT="tests/canisa/canisa-mini.input.scm"
OUT="/tmp/bicf-demo.canbc"
AUTO="0"
UDP="0"

while [ $# -gt 0 ]; do
  case "$1" in
    --broker) BROKER="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --auto) AUTO="1"; shift 1 ;;
    --udp) UDP="1"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ ! -f "$INPUT" ]; then
  echo "error: input not found: $INPUT" >&2
  exit 2
fi

echo "[1/2] Assemble CANBC: $INPUT -> $OUT"
guile -s tools/can-asm.scm "$INPUT" "$OUT" >/dev/null

echo "[2/2] MQTT run on esp32-a/esp32-b/esp32-c via $BROKER:$PORT"
if [ "$UDP" = "1" ]; then
  python3 tools/mqtt-canbc-3device.py --no-pico --udp-discover-esp32 3 --broker "$BROKER" --port "$PORT" --canbc "$OUT" --retain-load
elif [ "$AUTO" = "1" ]; then
  python3 tools/mqtt-canbc-3device.py --no-pico --auto-esp32 3 --broker "$BROKER" --port "$PORT" --canbc "$OUT" --retain-load
else
  python3 tools/mqtt-canbc-3device.py --no-pico --esp32-c esp32-c --broker "$BROKER" --port "$PORT" --canbc "$OUT" --retain-load
fi
