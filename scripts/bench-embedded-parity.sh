#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

need() { command -v "$1" >/dev/null 2>&1; }
RG_BIN="rg"
if ! need rg; then RG_BIN="grep"; fi

usage() {
  cat <<'EOF'
usage: scripts/bench-embedded-parity.sh [options]

Generates a CLBC program, validates transcript hash against desktop,
then benchmarks embedded device(s) latency.

options:
  --input <file.scm>    CanvasL input program (default: tests/clbc/mini-validation.input.scm)
  --pico <port>         Pico CDC port (e.g. /dev/ttyACM0)
  --esp32 <port|auto>   ESP32 UART port (e.g. /dev/ttyUSB0; "auto" to detect)
  --esp32-2 <port|auto> Second ESP32 UART port (e.g. /dev/ttyUSB1; "auto" to detect)
  --esp32-baud <baud>   ESP32 baud rate (default: 115200)
  --runs <n>            Number of benchmark iterations (default: 50)
EOF
}

INPUT="tests/clbc/mini-validation.input.scm"
PICO_PORT=""
ESP32_PORT=""
ESP32_PORT_2=""
ESP32_BAUD="115200"
RUNS="50"

while [ $# -gt 0 ]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --pico) PICO_PORT="$2"; shift 2 ;;
    --esp32) ESP32_PORT="$2"; shift 2 ;;
    --esp32-2) ESP32_PORT_2="$2"; shift 2 ;;
    --esp32-baud) ESP32_BAUD="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$PICO_PORT" ] && [ -z "$ESP32_PORT" ] && [ -z "$ESP32_PORT_2" ]; then
  if [ -e /dev/ttyACM0 ]; then
    PICO_PORT=/dev/ttyACM0
  fi
fi

if [ -z "$PICO_PORT" ] && [ -z "$ESP32_PORT" ] && [ -z "$ESP32_PORT_2" ]; then
  echo "error: No device ports specified. Pass --pico, --esp32, or --esp32-2" >&2
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

BENCH_COUNT=0
TOTAL_STEPS=3
if [ -n "$PICO_PORT" ] && [ -e "$PICO_PORT" ]; then
  BENCH_COUNT=$((BENCH_COUNT + 1))
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi
if [ -n "$ESP32_PORT" ]; then
  BENCH_COUNT=$((BENCH_COUNT + 1))
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi
if [ -n "$ESP32_PORT_2" ]; then
  BENCH_COUNT=$((BENCH_COUNT + 1))
  TOTAL_STEPS=$((TOTAL_STEPS + 1))
fi

STEP_NUM=3
if [ -n "$PICO_PORT" ] && [ -e "$PICO_PORT" ]; then
  STEP_NUM=$((STEP_NUM + 1))
  echo "[$STEP_NUM/$TOTAL_STEPS] Pico benchmark on $PICO_PORT ..."
  python3 tools/clbt-bench.py "$PICO_PORT" "$TMP_CLBC" --expected-hash "$DESKTOP_HASH" --expected-events "$DESKTOP_EVENTS" --runs "$RUNS"
fi

if [ -n "$ESP32_PORT" ] && [ "$ESP32_PORT" = "auto" ]; then
  # Avoid brittle `set -e` interactions with `if var="$(cmd)"` on some bash versions.
  ESP32_PORT="$(scripts/find-esp32-vm-port.sh --timeout 2.5 --baud "$ESP32_BAUD" --exclude "${PICO_PORT:-}" 2>/dev/null || true)"
  if [ -n "$ESP32_PORT" ]; then
    echo "auto-detected esp32 port: $ESP32_PORT"
  else
    echo "warn: ESP32 auto-detect failed; skipping ESP32 benchmark (flash embedded/esp32-clbc-sha first)" >&2
  fi
fi

if [ -n "$ESP32_PORT" ] && [ -e "$ESP32_PORT" ]; then
  STEP_NUM=$((STEP_NUM + 1))
  echo "[$STEP_NUM/$TOTAL_STEPS] ESP32 benchmark on $ESP32_PORT (baud $ESP32_BAUD) ..."
  echo "Note: ESP32 firmware must be flashed with matching CLBC program"
  python3 tools/esp32-vm-bench.py "$ESP32_PORT" --baud "$ESP32_BAUD" --expected-hash "$DESKTOP_HASH" --expected-events "$DESKTOP_EVENTS" --runs "$RUNS"
fi

if [ -n "$ESP32_PORT_2" ] && [ "$ESP32_PORT_2" = "auto" ]; then
  EX1="${ESP32_PORT:-}"
  ESP32_PORT_2="$(scripts/find-esp32-vm-port.sh --timeout 2.5 --baud "$ESP32_BAUD" --exclude "${PICO_PORT:-}" --exclude "${EX1:-}" 2>/dev/null || true)"
  if [ -n "$ESP32_PORT_2" ]; then
    echo "auto-detected esp32 #2 port: $ESP32_PORT_2"
  else
    echo "warn: ESP32 #2 auto-detect failed; skipping ESP32 #2 benchmark" >&2
  fi
fi

if [ -n "$ESP32_PORT_2" ] && [ -e "$ESP32_PORT_2" ]; then
  STEP_NUM=$((STEP_NUM + 1))
  echo "[$STEP_NUM/$TOTAL_STEPS] ESP32 #2 benchmark on $ESP32_PORT_2 (baud $ESP32_BAUD) ..."
  echo "Note: ESP32 firmware must be flashed with matching CLBC program"
  python3 tools/esp32-vm-bench.py "$ESP32_PORT_2" --baud "$ESP32_BAUD" --expected-hash "$DESKTOP_HASH" --expected-events "$DESKTOP_EVENTS" --runs "$RUNS"
fi

if [ "$BENCH_COUNT" -eq 0 ]; then
  echo "error: No valid device ports found" >&2
  exit 2
fi
