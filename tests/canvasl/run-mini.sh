#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

export GUILE_AUTO_COMPILE=0
export GUILE_AUTO_COMPILE_VERBOSE=0
export GUILE_LOAD_COMPILED_PATH=

OUT="$(guile -s tools/canvasl-run-jsonl.scm tests/canvasl/mini.jsonl)"

echo "$OUT" | grep -q '^phase: 2$'
echo "$OUT" | grep -q '^transcript: '

# Ensure deterministic transcript hash across runs.
OUT2="$(guile -s tools/canvasl-run-jsonl.scm tests/canvasl/mini.jsonl)"
test "$OUT" = "$OUT2"

echo "ok"
