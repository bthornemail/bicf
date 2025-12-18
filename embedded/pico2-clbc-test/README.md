# Pico 2 (RP2350) CLBT demo firmware

Minimal Raspberry Pi Pico 2 firmware that exposes the **CLBT** (CanvasL/CLBC Bytecode Test) protocol over **USB CDC**.

It accepts a CLBC container as bytes (`LOAD_PROGRAM`) and responds with the deterministic transcript SHA-256 produced by the embedded CLBC VM (`RUN`).

## Build

Prereqs:

- `pico-sdk` installed (RP2350 support requires a recent pico-sdk)
- ARM GCC toolchain (`arm-none-eabi-gcc`)
- `cmake`, `ninja` (or `make`)

Quick start (downloads pico-sdk into `./.deps/` and builds):

```bash
./embedded/pico2-clbc-test/bootstrap.sh
```

Build:

```bash
export PICO_SDK_PATH=/path/to/pico-sdk
cd embedded/pico2-clbc-test
mkdir -p build && cd build
cmake .. -DPICO_BOARD=pico2
cmake --build .
```

Output UF2:

- `embedded/pico2-clbc-test/build/pico2_clbc_test.uf2`

## Flash

1. Hold **BOOTSEL** while plugging the Pico 2 in.
2. Copy the UF2 to the mounted drive (usually `/media/$USER/RP2350`):

```bash
cp embedded/pico2-clbc-test/build/pico2_clbc_test.uf2 /media/$USER/RP2350/ && sync
```

After reboot, the device should enumerate as `/dev/ttyACM*`.

## Demo run (host-driven)

Generate a small `.clbc` test program and run it on the Pico over USB CDC:

```bash
pip install pyserial

TMP_CLBC=/tmp/mini.clbc
guile -s tools/canvasl-to-clbc.scm tests/clbc/mini-validation.input.scm "$TMP_CLBC"

python3 tools/clbt-serial.py /dev/ttyACM0 "$TMP_CLBC"
guile -s tools/clbc-run.scm "$TMP_CLBC" | rg '^transcript-hash:'
```
