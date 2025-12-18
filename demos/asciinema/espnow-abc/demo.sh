#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

: "${PORT_A:?set PORT_A=/dev/serial/by-path/...}"
: "${PORT_B:?set PORT_B=/dev/serial/by-path/...}"
: "${PORT_C:?set PORT_C=/dev/serial/by-path/...}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required"
  exit 1
fi

python3 -c 'import serial' >/dev/null 2>&1 || {
  echo "pyserial is required: python3 -m pip install pyserial"
  exit 1
}

color() { local code="$1"; shift; printf "\033[%sm%s\033[0m" "$code" "$*"; }
hdr() {
  echo
  color "1;36" "== $* =="
  echo
}

hdr "Ports (stable by-path)"
echo "A (NRR)   : $PORT_A"
echo "B (VERIFY): $PORT_B"
echo "C (ORCH)  : $PORT_C"

hdr "Sanity: devices present"
ls -l "$PORT_A" "$PORT_B" "$PORT_C"

hdr "Negotiation + convergence (single-pane mux)"
echo "Reading all three serial ports concurrently for ~8s and prefixing lines with [A]/[B]/[C]."
echo "Expected: C prints NODE_A/NODE_B and ends with DEMO_PASS=1."
echo

python3 demos/asciinema/espnow-abc/serial_mux.py \
  --a "$PORT_A" \
  --b "$PORT_B" \
  --c "$PORT_C" \
  --seconds 8 \
  --reset

hdr "Determinism check (re-run C quickly)"
echo "Resetting C and capturing only C output until DEMO_PASS is observed."
python3 demos/asciinema/espnow-abc/serial_mux.py \
  --c "$PORT_C" \
  --seconds 8 \
  --reset \
  --until DEMO_PASS=

hdr "Done"
echo "Tip: upload demos/asciinema/espnow-abc/espnow-abc.cast and view with different player themes."

