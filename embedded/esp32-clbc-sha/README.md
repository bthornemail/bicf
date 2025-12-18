# ESP32 CLBC SHA-256 Smoke Test

Minimal ESP-IDF firmware that computes `sha256(CLBC_bytes)` for an embedded CLBC blob and prints it over serial.

This is the smallest deterministic validation loop:

1. Same CLBC bytes on host and device
2. Same SHA-256 result on host and device

## Build + Flash

From repo root:

```bash
./esp-idf/install.sh
. ./esp-idf/export.sh

cd embedded/esp32-clbc-sha
idf.py -p /dev/ttyUSB0 flash monitor
```

Expected output includes a line like:

```text
CLBC_SHA256=<64 hex chars>
CLBC_LEN=<n>
```

