#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TIMEOUT="${TIMEOUT:-2.0}"
BAUD="${BAUD:-115200}"
EXCLUDES=()

usage() {
  cat <<'EOF'
usage: scripts/find-esp32-vm-port.sh [--timeout <seconds>] [--baud <baud>] [--exclude <port>]...

Tries each /dev/serial/by-path/*ttyUSB* (fallback: /dev/ttyUSB*) and prints the
first port that looks like an ESP32 running embedded/esp32-clbc-sha (VM_* lines).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --baud) BAUD="$2"; shift 2 ;;
    --exclude) EXCLUDES+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

shopt -s nullglob
ports=(/dev/serial/by-path/*ttyUSB*)
if [ ${#ports[@]} -eq 0 ]; then
  ports=(/dev/ttyUSB*)
fi

for p in "${ports[@]}"; do
  [ -e "$p" ] || continue
  skip=0
  rp="$(readlink -f "$p" 2>/dev/null || echo "$p")"
  for ex in "${EXCLUDES[@]}"; do
    rex="$(readlink -f "$ex" 2>/dev/null || echo "$ex")"
    if [ "$rp" = "$rex" ]; then
      skip=1
      break
    fi
  done
  if [ "$skip" = "1" ]; then
    continue
  fi
  if python3 tools/esp32-vm-serial.py "$p" --baud "$BAUD" --timeout "$TIMEOUT" --reset --reset-delay 0.5 >/dev/null 2>&1; then
    echo "$p"
    exit 0
  fi
done

echo "no ESP32 VM port found (expected VM_OK/VM_EVENTS/VM_TRANSCRIPT_SHA256 output)" >&2
exit 1
