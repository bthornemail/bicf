#!/bin/bash
set -euo pipefail

export GUILE_AUTO_COMPILE=0
export GUILE_AUTO_COMPILE_VERBOSE=0
export GUILE_LOAD_COMPILED_PATH=

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ACTUAL="$(mktemp)"
trap 'rm -f "$ACTUAL"' EXIT

guile -s tools/viz-scene.scm 3 0 1 > "$ACTUAL"

diff -u tests/viz/scene-snapshot.expected.scm "$ACTUAL" >/dev/null
echo "ok"
