#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/embedded/pico2w-mqtt-clbc/bootstrap.sh" >/dev/null

UF2="$ROOT/embedded/pico2w-mqtt-clbc/build/pico2w_mqtt_clbc.uf2"
if [ ! -f "$UF2" ]; then
  echo "error: UF2 not found: $UF2" >&2
  exit 2
fi

MOUNTPOINT="$(
  lsblk -nrpo LABEL,MOUNTPOINT 2>/dev/null \
    | awk '($1 ~ /(RP2350|RPI-RP2)/) && $2 != "" {print $2; exit}'
)"

if [ -z "${MOUNTPOINT:-}" ]; then
  cat >&2 <<'EOF'
error: Pico BOOTSEL drive not mounted.

1) Unplug Pico 2 W
2) Hold BOOTSEL, plug it back in
3) Wait for the RP2350 (or RPI-RP2) drive to appear
4) Re-run this script
EOF
  exit 2
fi

cp -f "$UF2" "$MOUNTPOINT/"
sync
echo "Flashed: $UF2 -> $MOUNTPOINT/"

