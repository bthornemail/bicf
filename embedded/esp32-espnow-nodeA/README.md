# ESP32 ESPNOW Node A (NRR)

Role: **A** = append-only NRR log service over ESPNOW.

Build/flash:

```bash
source ../../esp-idf/export.sh
cd embedded/esp32-espnow-nodeA
idf.py build
idf.py -p /dev/ttyUSBX flash monitor
```

