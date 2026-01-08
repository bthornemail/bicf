#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

CAST="$ROOT/demos/asciinema/canbc-3esp/canbc-3esp.cast"
OUTDIR="$ROOT/demos/asciinema/canbc-3esp/render"
mkdir -p "$OUTDIR"

THEME="${THEME:-dracula}"
FPS_CAP="${FPS_CAP:-30}"

if [ ! -f "$CAST" ]; then
  echo "missing cast: $CAST"
  exit 1
fi

if ! command -v agg >/dev/null 2>&1; then
  echo "agg is required (https://docs.asciinema.org/manual/agg/usage/)"
  exit 1
fi

GIF="$OUTDIR/canbc-3esp-${THEME}.gif"

agg \
  --theme "$THEME" \
  --fps-cap "$FPS_CAP" \
  --idle-time-limit 1 \
  "$CAST" \
  "$GIF"

echo "wrote: $GIF"

