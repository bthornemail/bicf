#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_DIR="$ROOT/.nrr-test"
JSONL="$ROOT/tests/canvasl/sample.canvasl-1.0.jsonl"

rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR"

# Scene should be deterministic JSON
guile "$ROOT/tools/canvasl-engine-jsonl.scm" --repo "$REPO_DIR" --jsonl "$JSONL" --getScene >/dev/null

# Trace hash should be a stable string
guile "$ROOT/tools/canvasl-engine-jsonl.scm" --repo "$REPO_DIR" --jsonl "$JSONL" --getTrace \
  | python3 -c 'import json,sys; j=json.load(sys.stdin); assert "transcriptHash" in j and isinstance(j["transcriptHash"], str) and len(j["transcriptHash"])>0'

# Incidence payload should either be present with points/lines arrays
guile "$ROOT/tools/canvasl-engine-jsonl.scm" --repo "$REPO_DIR" --jsonl "$JSONL" --getIncidence \
  | python3 -c 'import json,sys; j=json.load(sys.stdin); assert j["type"]=="fano"; assert isinstance(j["present"], bool); assert isinstance(j["points"], list); assert isinstance(j["lines"], list)'

echo "ok"


