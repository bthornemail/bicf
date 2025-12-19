# Pico 2 (RP2350) Porting Summary (validated scope)

## ✅ Completed Components

### 1. CLBC VM
- **Status:** ✅ Complete and verified
- **Files:** `src/clbc_vm.c`, `src/clbc_vm.h`
- **Verification:** Deterministic replay validated against desktop and ESP32
- **Performance:** Benchmark with `scripts/bench-embedded-parity.sh`

### 2. Host tooling
- **Status:** ✅ Complete
- **Files:**
  - `tools/clbt-serial.py` - CLBT runner over USB CDC
  - `tools/clbt-bench.py` - CLBT benchmark over USB CDC
  - `scripts/demo-embedded-parity.sh` - Desktop ↔ Pico ↔ ESP32 parity check
  - `scripts/bench-embedded-parity.sh` - Benchmark Pico + ESP32s
  - `scripts/flash-esp32-clbc-sha.sh` - Flash helper for ESP32 CLBC demo
  - `scripts/find-esp32-vm-port.sh` - Auto-detect ESP32 UART ports
  - `tools/pico-mqtt-bridge.py` - USB CDC → MQTT bridge (optional)

## ⏳ Remaining Work

### High Priority

1. **Make CanvasL/NRR ports real** (currently experimental code, not validated)
2. **Heterogeneous network test harness** (MQTT topics + automation, if desired)

### Medium Priority

3. **Compute-only ESP32 benchmark** (avoid reset/boot in each iteration)

## Architecture Comparison

| Component | Desktop (Guile) | ESP32 | Pico 2 (RP2350) |
|-----------|----------------|----------|---------|
| **CPU** | x86_64/ARM64 | Xtensa (varies) | ARM Cortex-M33 |
| **CLBC VM** | ✅ | ✅ | ✅ |
| **NRR** | ✅ | ⏳ | ⏳ (experimental) |
| **CanvasL** | ✅ | ⏳ | ⏳ (experimental) |
| **Network** | N/A | ESP-NOW/WiFi | USB CDC (host bridge if needed) |

## Deterministic Replay Validation

**Proven:** Same CLBC program produces identical transcript hash on:
- ✅ Desktop (Guile Scheme)
- ✅ ESP32 (Xtensa)
- ✅ Pico 2 (ARM Cortex-M33)

**Test Command:**
```bash
scripts/demo-embedded-parity.sh --pico /dev/ttyACM0 --esp32 /dev/ttyUSB0
```

## Next Steps

1. **Complete FANO/PCG validation** - Port from Scheme
2. **Add ESP32 MQTT client** - Enable network consensus
3. **Run 3-device test** - Prove heterogeneous determinism
4. **Performance optimization** - Reduce memory if needed

## References

- **Pico SDK:** https://github.com/raspberrypi/pico-sdk
- **RP2350 Datasheet:** https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf
- **NRR Specification:** `dev-docs/Native Repository Runtime.md`
- **CanvasL Specification:** `dev-docs/RFC-BICF-CANVASL-POLY-001/05-canvasl-poly/RFC-0003-CanvasL-POLY.md`
- **Porting Guide:** `dev-docs/Pico-W2-Porting-Guide.md`
