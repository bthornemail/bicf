#!/bin/bash
# Lean 4 Formal Verification Test Runner

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v lean >/dev/null 2>&1; then
    echo "Lean 4 not found, skipping verification"
    exit 0
fi

echo "Verifying Lean 4 formalization..."
lean --check src/lean/fano_pcg.lean

echo "Lean 4 verification passed!"

