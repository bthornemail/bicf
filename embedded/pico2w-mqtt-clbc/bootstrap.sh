#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Reuse toolchain + sdk bootstrap from the CLBT project (same host deps).
"$ROOT/embedded/pico2-clbc-test/bootstrap.sh" >/dev/null

export PICO_SDK_PATH="$ROOT/.deps/pico-sdk"
export PATH="$ROOT/.deps/ninja:$ROOT/.deps/arm-gnu-toolchain/bin:$PATH"
export PICO_TOOLCHAIN_PATH="$ROOT/.deps/arm-gnu-toolchain/bin"

cd "$ROOT/embedded/pico2w-mqtt-clbc"
cmake -S . -B build -G Ninja -DPICO_BOARD=pico2_w
cmake --build build
echo "UF2: $ROOT/embedded/pico2w-mqtt-clbc/build/pico2w_mqtt_clbc.uf2"

