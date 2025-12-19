#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

need() { command -v "$1" >/dev/null 2>&1; }
RG_BIN="rg"
if ! need rg; then RG_BIN="grep"; fi

# Keep Guile deterministic and sandbox-friendly (no writes to ~/.cache).
export GUILE_AUTO_COMPILE=0
export GUILE_AUTO_COMPILE_VERBOSE=0
export GUILE_LOAD_COMPILED_PATH=

TMP="$(mktemp /tmp/bicf-mini.XXXXXX.canbc)"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

guile -s tools/can-asm.scm tests/canisa/canisa-mini.input.scm "$TMP" >/dev/null

# Run twice and ensure hash is identical.
h1="$(guile -s tools/can-run.scm "$TMP" | $RG_BIN '^state-hash:' | awk '{print $2}')"
h2="$(guile -s tools/can-run.scm "$TMP" | $RG_BIN '^state-hash:' | awk '{print $2}')"

if [ -z "$h1" ] || [ -z "$h2" ]; then
  echo "missing state-hash output" >&2
  exit 2
fi

if [ "$h1" != "$h2" ]; then
  echo "non-deterministic hash: $h1 vs $h2" >&2
  exit 1
fi

echo "$h1"
