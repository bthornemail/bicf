#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

need() { command -v "$1" >/dev/null 2>&1; }
RG_BIN="rg"
if ! need rg; then RG_BIN="grep"; fi

usage() {
  cat <<'EOF'
usage: scripts/demo-embedded-parity.sh [options]

Builds a CLBC test program, runs it on:
  - desktop CLBC VM (guile)
  - Pico 2 over USB CDC (CLBT protocol)
  - optional ESP32 over UART (esp32-clbc-sha firmware output)

options:
  --input <file.scm>     CanvasL input program (default: tests/clbc/mini-validation.input.scm)
  --pico <port>          Pico CDC port (default: /dev/ttyACM0 if present)
  --esp32 <port|auto>    ESP32 UART port (optional; "auto" to detect)
  --esp32-baud <baud>    ESP32 baud (default: 115200)
EOF
}

INPUT="tests/clbc/mini-validation.input.scm"
PICO_PORT=""
ESP32_PORT=""
ESP32_BAUD="115200"

while [ $# -gt 0 ]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --pico) PICO_PORT="$2"; shift 2 ;;
    --esp32) ESP32_PORT="$2"; shift 2 ;;
    --esp32-baud) ESP32_BAUD="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$PICO_PORT" ] && [ -e /dev/ttyACM0 ]; then
  PICO_PORT=/dev/ttyACM0
fi
if [ -z "$PICO_PORT" ] || [ ! -e "$PICO_PORT" ]; then
  echo "error: Pico port not found; pass --pico /dev/ttyACM0" >&2
  exit 2
fi

TMP_CLBC="$(mktemp /tmp/bicf-mini.XXXXXX.clbc)"
cleanup() { rm -f "$TMP_CLBC"; }
trap cleanup EXIT

echo "[1/4] Build CLBC: $INPUT -> $TMP_CLBC"
guile -s tools/canvasl-to-clbc.scm "$INPUT" "$TMP_CLBC" >/dev/null

echo "[2/4] Desktop reference (guile) ..."
DESKTOP_HASH="$(guile -s tools/clbc-run.scm "$TMP_CLBC" | $RG_BIN '^transcript-hash:' | awk '{print $2}')"
DESKTOP_EVENTS="$(guile -s tools/clbc-run.scm "$TMP_CLBC" | $RG_BIN '^events:' | awk '{print $2}')"
echo "desktop events=$DESKTOP_EVENTS hash=$DESKTOP_HASH"

echo "[3/4] Pico 2 (USB CDC) on $PICO_PORT ..."
PICO_OUT="$(python3 tools/clbt-serial.py "$PICO_PORT" "$TMP_CLBC")"
PICO_OK="$(printf '%s\n' "$PICO_OUT" | $RG_BIN '^ok:' | awk '{print $2}')"
PICO_EVENTS="$(printf '%s\n' "$PICO_OUT" | $RG_BIN '^events:' | awk '{print $2}')"
PICO_HASH="$(printf '%s\n' "$PICO_OUT" | $RG_BIN '^transcript-hash:' | awk '{print $2}')"
echo "pico ok=$PICO_OK events=$PICO_EVENTS hash=$PICO_HASH"

PASS=1
if [ "$PICO_OK" != "1" ]; then PASS=0; fi
if [ "$PICO_EVENTS" != "$DESKTOP_EVENTS" ]; then PASS=0; fi
if [ "$PICO_HASH" != "$DESKTOP_HASH" ]; then PASS=0; fi

if [ -n "$ESP32_PORT" ]; then
  if [ "$ESP32_PORT" = "auto" ]; then
    if ESP32_PORT="$(scripts/find-esp32-vm-port.sh --timeout 2.5 --baud "$ESP32_BAUD" --exclude "${PICO_PORT:-}")"; then
      echo "auto-detected esp32 port: $ESP32_PORT"
    else
      echo "warn: ESP32 auto-detect failed; skipping ESP32 validation (flash embedded/esp32-clbc-sha first)" >&2
      ESP32_PORT=""
    fi
  fi
  if [ -n "$ESP32_PORT" ]; then
    echo "[4/4] ESP32 UART on $ESP32_PORT (baud $ESP32_BAUD) ..."
    ESP32_KV="$(python3 tools/esp32-vm-serial.py "$ESP32_PORT" --baud "$ESP32_BAUD" --timeout 8.0 --reset --reset-delay 0.5)"
    ESP32_OK="$(printf '%s\n' "$ESP32_KV" | $RG_BIN '^VM_OK=' | cut -d= -f2-)"
    ESP32_EVENTS="$(printf '%s\n' "$ESP32_KV" | $RG_BIN '^VM_EVENTS=' | cut -d= -f2-)"
    ESP32_HASH="$(printf '%s\n' "$ESP32_KV" | $RG_BIN '^VM_TRANSCRIPT_SHA256=' | cut -d= -f2-)"
    echo "esp32 ok=$ESP32_OK events=$ESP32_EVENTS hash=$ESP32_HASH"
    if [ "$ESP32_OK" != "1" ]; then PASS=0; fi
    if [ "$ESP32_EVENTS" != "$DESKTOP_EVENTS" ]; then PASS=0; fi
    if [ "$ESP32_HASH" != "$DESKTOP_HASH" ]; then PASS=0; fi
  fi
fi

if [ "$PASS" = "1" ]; then
  echo "PASS: embedded transcript hash matches desktop."
  exit 0
else
  echo "FAIL: mismatch between embedded and desktop." >&2
  exit 1
fi
