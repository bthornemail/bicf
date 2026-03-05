#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper for local monorepo usage:
# CanvasL JSONL -> seam envelopes -> append into a port-matroid store dir.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PM_ROOT="${PM_ROOT:-$ROOT/../port-matroid}"

if [ $# -ne 2 ]; then
  echo "usage: append-to-port-matroid.sh <canvasl.jsonl> <port-matroid-store-dir>" >&2
  exit 2
fi

facts="$1"
store="$2"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

python3 "$ROOT/scripts/emit-seam-envelopes.py" --input "$facts" >"$tmp"

(cd "$PM_ROOT" && cabal -v0 run port-matroid-tool -- append-envelope "$store" "$tmp")

