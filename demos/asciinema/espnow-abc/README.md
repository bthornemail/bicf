# ESP-NOW A/B/C Negotiation Demo (asciinema)

Single-pane asciinema demo showing 3 ESP32 boards negotiating over ESP-NOW:

- **A**: NRR node (RESET/APPEND/REPLAY)
- **B**: Verifier node (VERIFY → VM transcript hash)
- **C**: Orchestrator (DISCOVER → RESET → APPEND → REPLAY → VERIFY → `DEMO_PASS=1`)

## Prereqs

- 3 ESP32 boards connected via USB
- Ports available under `/dev/serial/by-path/*`
- `python3` with `pyserial` (`python3 -c 'import serial'` must succeed)
- `asciinema` (v2+)
- ESP-IDF installed in this repo (`./esp-idf/`) and `source ./esp-idf/export.sh` works

## Flash once (A/B/C)

Pick a stable mapping from physical USB ports:

- A: `/dev/serial/by-path/pci-...-usb-0:1:1.0-port0`
- B: `/dev/serial/by-path/pci-...-usb-0:3:1.0-port0`
- C: `/dev/serial/by-path/pci-...-usb-0:4:1.0-port0`

Then:

```bash
export PORT_A=/dev/serial/by-path/...
export PORT_B=/dev/serial/by-path/...
export PORT_C=/dev/serial/by-path/...

bash demos/asciinema/espnow-abc/flash.sh
```

## Run the demo (human-readable)

```bash
export PORT_A=/dev/serial/by-path/...
export PORT_B=/dev/serial/by-path/...
export PORT_C=/dev/serial/by-path/...

bash demos/asciinema/espnow-abc/demo.sh
```

## Record with asciinema (single pane)

```bash
export PORT_A=/dev/serial/by-path/...
export PORT_B=/dev/serial/by-path/...
export PORT_C=/dev/serial/by-path/...

bash demos/asciinema/espnow-abc/record.sh
```

The recording is saved to `demos/asciinema/espnow-abc/espnow-abc.cast`.

## Themes (playback)

Terminal playback (`asciinema play`) does not apply themes. To showcase different themes:

- Upload the `.cast` to asciinema.org (or self-host a player) and choose a player theme.
- `asciinema-player` themes commonly include: `asciinema`, `tango`, `solarized-dark`, `solarized-light`, `monokai`.

## Portable GIF/MP4 renders

Generate portable outputs (GIF + MP4) at fixed durations (15s, 30s, 60s, 300s):

```bash
THEME=dracula bash demos/asciinema/espnow-abc/render.sh
```

Outputs are written to `demos/asciinema/espnow-abc/render/`.
