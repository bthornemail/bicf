#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TMP_CLBC="$(mktemp)"
trap 'rm -f "$TMP_CLBC"' EXIT

guile -s tools/canvasl-to-clbc.scm tests/clbc/mini-validation.input.scm "$TMP_CLBC" >/dev/null

# Run VM and print transcript-hash only (stable for golden tests)
HASH_LINE="$(guile -s tools/clbc-run.scm "$TMP_CLBC" | grep '^transcript-hash:' | awk '{print $2}')"
echo "$HASH_LINE"


