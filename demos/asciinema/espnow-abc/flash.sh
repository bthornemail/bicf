#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

: "${PORT_A:?set PORT_A=/dev/serial/by-path/...}"
: "${PORT_B:?set PORT_B=/dev/serial/by-path/...}"
: "${PORT_C:?set PORT_C=/dev/serial/by-path/...}"

source "$ROOT/esp-idf/export.sh" >/dev/null 2>&1

flash_one() {
  local port="$1"
  local proj="$2"
  local baud="${3:-115200}"
  local binname="$4"
  python -m esptool --chip esp32 -p "$port" -b "$baud" --before default_reset --after hard_reset write_flash \
    0x1000 "$ROOT/$proj/build/bootloader/bootloader.bin" \
    0x8000 "$ROOT/$proj/build/partition_table/partition-table.bin" \
    0x10000 "$ROOT/$proj/build/$binname"
}

echo "Building A/B/C (one time)..."
(cd embedded/esp32-espnow-nodeA && idf.py build)
(cd embedded/esp32-espnow-nodeB && idf.py build)
(cd embedded/esp32-espnow-nodeC && idf.py build)

echo "Flashing Node A -> $PORT_A"
flash_one "$PORT_A" embedded/esp32-espnow-nodeA 115200 esp32_espnow_nodeA.bin

echo "Flashing Node B -> $PORT_B"
flash_one "$PORT_B" embedded/esp32-espnow-nodeB 115200 esp32_espnow_nodeB.bin

echo "Flashing Node C -> $PORT_C (fallback baud 57600 if needed)"
if ! flash_one "$PORT_C" embedded/esp32-espnow-nodeC 115200 esp32_espnow_nodeC.bin; then
  flash_one "$PORT_C" embedded/esp32-espnow-nodeC 57600 esp32_espnow_nodeC.bin
fi

echo "Flash complete."
