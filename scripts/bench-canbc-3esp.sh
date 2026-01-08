#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'EOF'
usage: scripts/bench-canbc-3esp.sh [options]

Assembles a `.canbc` program and benchmarks it over MQTT on 3×ESP32 devices:
  esp32-a, esp32-b, esp32-c

options:
  --broker <host>       MQTT broker host (default: 127.0.0.1)
  --port <port>         MQTT broker port (default: 1883)
  --input <file.scm>    CAN-ISA program (Scheme s-expr) (default: tests/canisa/canisa-mini.input.scm)
  --out <file.canbc>    Output `.canbc` path (default: /tmp/bicf-bench.canbc)
  --runs <n>            Number of runs (default: 25)
  --pause <seconds>     Pause between runs (default: 0)
  --reload-each-run     Republish load_canbc before each run
  --auto                Auto-discover 3 ESP32 devices via `bicf/announce/<id>`
  --udp                 Auto-discover 3 ESP32 devices via UDP multicast (no MQTT announce needed)
EOF
}

BROKER="127.0.0.1"
PORT="1883"
INPUT="tests/canisa/canisa-mini.input.scm"
OUT="/tmp/bicf-bench.canbc"
RUNS="25"
PAUSE="0"
RELOAD_EACH_RUN="0"
AUTO="0"
UDP="0"

while [ $# -gt 0 ]; do
  case "$1" in
    --broker) BROKER="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --pause) PAUSE="$2"; shift 2 ;;
    --reload-each-run) RELOAD_EACH_RUN="1"; shift 1 ;;
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

echo "[2/2] MQTT benchmark on esp32-a/esp32-b/esp32-c via $BROKER:$PORT ($RUNS runs)"
ARGS=(--no-pico --broker "$BROKER" --port "$PORT" --canbc "$OUT" --retain-load --runs "$RUNS" --pause "$PAUSE")
if [ "$UDP" = "1" ]; then
  ARGS+=(--udp-discover-esp32 3)
elif [ "$AUTO" = "1" ]; then
  ARGS+=(--auto-esp32 3)
else
  ARGS+=(--esp32-c esp32-c)
fi
if [ "$RELOAD_EACH_RUN" = "1" ]; then
  ARGS+=(--reload-each-run)
fi
python3 tools/mqtt-canbc-3device.py "${ARGS[@]}"
