#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

: "${BROKER:=127.0.0.1}"
: "${PORT:=1883}"
: "${DISCOVERY:=mqtt}" # mqtt|udp

OUT="/tmp/bicf-demo.canbc"
INPUT="tests/canisa/canisa-mini.input.scm"

color() { local code="$1"; shift; printf "\033[%sm%s\033[0m" "$code" "$*"; }
hdr() { echo; color "1;36" "== $* =="; echo; }

hdr "Assemble CANBC"
echo "input : $INPUT"
echo "out   : $OUT"
guile -s tools/can-asm.scm "$INPUT" "$OUT" >/dev/null
ls -l "$OUT"

hdr "Run 3×ESP32 via MQTT ($BROKER:$PORT)"
if [ "$DISCOVERY" = "udp" ]; then
  echo "discovery: UDP multicast (239.255.42.42:4242)"
  python3 tools/mqtt-canbc-3device.py \
    --no-pico \
    --udp-discover-esp32 3 \
    --broker "$BROKER" --port "$PORT" \
    --canbc "$OUT" \
    --retain-load
else
  echo "discovery: MQTT retained announce (bicf/announce/#)"
  python3 tools/mqtt-canbc-3device.py \
    --no-pico \
    --auto-esp32 3 \
    --broker "$BROKER" --port "$PORT" \
    --canbc "$OUT" \
    --retain-load
fi

