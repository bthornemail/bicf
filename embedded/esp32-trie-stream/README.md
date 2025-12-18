# ESP32 Semantic Trie Stream Demo

Builds a deterministic semantic trie keyed by:

`mkey = "rpc/" + method_name + "@schema/" + schema_id`

Then computes two deterministic stream IDs (chirality):

- `STREAM_LEFT_SHA256` = trie traversal children ascending
- `STREAM_RIGHT_SHA256` = trie traversal children descending

Both are deterministic functions of the inserted `(mkey, rid)` pairs.

## Build/flash

```bash
source ../../esp-idf/export.sh
cd embedded/esp32-trie-stream
idf.py build
idf.py -p /dev/ttyUSB0 flash monitor
```

## Determinism check

```bash
python3 embedded/esp32-trie-stream/check_determinism.py \
  --port /dev/serial/by-path/pci-0000:00:14.0-usb-0:4:1.0-port0 \
  --runs 5
```
