#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

: "${PORT_A:?set PORT_A=/dev/serial/by-path/...}"
: "${PORT_B:?set PORT_B=/dev/serial/by-path/...}"
: "${PORT_C:?set PORT_C=/dev/serial/by-path/...}"

OUT="$ROOT/demos/asciinema/espnow-abc/espnow-abc.cast"

# asciinema requires captured env values to be strings; ensure TERM is set.
: "${TERM:=xterm-256color}"
export TERM

# Playback-friendly capture:
# - limit long pauses
# - fixed terminal size
asciinema rec \
  --overwrite \
  --title "BICF ESP32 ESP-NOW negotiation (A/B/C)" \
  --idle-time-limit 1.0 \
  --cols 110 \
  --rows 32 \
  --env TERM \
  -c "bash demos/asciinema/espnow-abc/demo.sh" \
  "$OUT"

echo "Wrote: $OUT"
