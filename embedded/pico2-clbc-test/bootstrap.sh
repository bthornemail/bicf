#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDK_DIR="${PICO_SDK_DIR:-$ROOT/.deps/pico-sdk}"

if [ ! -d "$SDK_DIR" ]; then
  mkdir -p "$(dirname "$SDK_DIR")"
  git clone --depth 1 https://github.com/raspberrypi/pico-sdk.git "$SDK_DIR"
  (cd "$SDK_DIR" && git submodule update --init --depth 1)
fi

export PICO_SDK_PATH="$SDK_DIR"

cd "$ROOT/embedded/pico2-clbc-test"
cmake -S . -B build -DPICO_BOARD=pico2
cmake --build build

echo "UF2: $ROOT/embedded/pico2-clbc-test/build/pico2_clbc_test.uf2"

