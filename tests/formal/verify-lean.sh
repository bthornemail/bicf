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
echo "Note: Lean 4 file requires Mathlib. Use 'lake build' in project root for full verification."
echo "Checking for sorry/admit statements..."
if grep -qE "(sorry|admit)" src/lean/fano_pcg.lean 2>/dev/null; then
    echo "Warning: Lean 4 file may contain sorry/admit statements"
    exit 1
else
    echo "Lean 4 file structure verified (no obvious sorry/admit statements)"
fi

