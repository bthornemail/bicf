#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${PORT:=/dev/ttyUSB0}"
: "${BAUD:=115200}"

if [ ! -e "$PORT" ]; then
  echo "error: PORT not found: $PORT" >&2
  exit 2
fi

source ./esp-idf/export.sh

cd embedded/esp32-clbc-sha
idf.py -p "$PORT" build
idf.py -p "$PORT" -b "$BAUD" flash

echo "Flashed esp32-clbc-sha to $PORT (baud $BAUD)."

