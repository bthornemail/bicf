#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

: "${BROKER:=127.0.0.1}"
: "${PORT:=1883}"
: "${DISCOVERY:=mqtt}" # mqtt|udp

OUT="$ROOT/demos/asciinema/canbc-3esp/canbc-3esp.cast"

if ! command -v asciinema >/dev/null 2>&1; then
  echo "asciinema is required"
  exit 1
fi

: "${TERM:=xterm-256color}"
export TERM BROKER PORT DISCOVERY

asciinema rec \
  --overwrite \
  --title "BICF CANBC: 3×ESP32 deterministic parity (MQTT + discovery)" \
  --idle-time-limit 1.0 \
  --cols 110 \
  --rows 28 \
  --env TERM,BROKER,PORT,DISCOVERY \
  -c "bash demos/asciinema/canbc-3esp/demo.sh" \
  "$OUT"

echo "Wrote: $OUT"

