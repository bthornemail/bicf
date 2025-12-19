#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDK_DIR="${PICO_SDK_DIR:-$ROOT/.deps/pico-sdk}"
DEPS_DIR="$ROOT/.deps"
TOOLCHAIN_DIR="${PICO_TOOLCHAIN_DIR:-$DEPS_DIR/arm-gnu-toolchain}"
NINJA_DIR="${PICO_NINJA_DIR:-$DEPS_DIR/ninja}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

curl_fetch() {
  local url="$1"
  local out="$2"
  # -q ignores ~/.curlrc (which may pin a stale proxy).
  if [ -n "${HTTPS_PROXY:-}" ]; then
    curl -q -L -x "$HTTPS_PROXY" "$url" -o "$out"
  else
    curl -q -L "$url" -o "$out"
  fi
}

if [ ! -d "$SDK_DIR" ]; then
  mkdir -p "$(dirname "$SDK_DIR")"
  git clone --depth 1 https://github.com/raspberrypi/pico-sdk.git "$SDK_DIR"
  (cd "$SDK_DIR" && git submodule update --init --depth 1)
fi

export PICO_SDK_PATH="$SDK_DIR"

if ! need_cmd arm-none-eabi-gcc; then
  mkdir -p "$TOOLCHAIN_DIR"
  if [ ! -x "$TOOLCHAIN_DIR/bin/arm-none-eabi-gcc" ]; then
    echo "arm-none-eabi-gcc not found; downloading Arm GNU Toolchain into $TOOLCHAIN_DIR ..."
    TARBALL="$DEPS_DIR/arm-gnu-toolchain.tar.xz"
    URL="https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi.tar.xz"
    mkdir -p "$DEPS_DIR"
    curl_fetch "$URL" "$TARBALL"
    rm -rf "$TOOLCHAIN_DIR"
    mkdir -p "$TOOLCHAIN_DIR"
    tar -xJf "$TARBALL" -C "$TOOLCHAIN_DIR" --strip-components=1
  fi
  export PICO_TOOLCHAIN_PATH="$TOOLCHAIN_DIR/bin"
  export PATH="$PICO_TOOLCHAIN_PATH:$PATH"
fi

if ! need_cmd ninja; then
  mkdir -p "$NINJA_DIR"
  if [ ! -x "$NINJA_DIR/ninja" ]; then
    echo "ninja not found; downloading into $NINJA_DIR ..."
    ZIP="$DEPS_DIR/ninja-linux.zip"
    URL="https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-linux.zip"
    mkdir -p "$DEPS_DIR"
    curl_fetch "$URL" "$ZIP"
    python3 - <<PY
import zipfile
z = zipfile.ZipFile("$ZIP")
z.extractall("$NINJA_DIR")
PY
    chmod +x "$NINJA_DIR/ninja"
  fi
  export PATH="$NINJA_DIR:$PATH"
fi

cd "$ROOT/embedded/pico2-clbc-test"
cmake -S . -B build -G Ninja -DPICO_BOARD=pico2
cmake --build build

echo "UF2: $ROOT/embedded/pico2-clbc-test/build/pico2_clbc_test.uf2"
