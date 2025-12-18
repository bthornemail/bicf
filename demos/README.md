# Demos

## ESP-NOW A/B/C (terminal + asciinema)

- Path: `demos/asciinema/espnow-abc/`
- What it shows: 3 ESP32 boards negotiating deterministically over ESP-NOW:
  - A = NRR (RESET/APPEND/REPLAY)
  - B = verifier (VERIFY → VM transcript hash)
  - C = orchestrator (DISCOVER → RESET → APPEND → REPLAY → VERIFY → `DEMO_PASS=1`)
- Entry points:
  - Flash: `demos/asciinema/espnow-abc/flash.sh`
  - Run: `demos/asciinema/espnow-abc/demo.sh`
  - Record: `demos/asciinema/espnow-abc/record.sh`
  - Render GIF/MP4: `demos/asciinema/espnow-abc/render.sh`

## ESP-NOW “Agreed Policy” (Three.js + replay)

- Path: `demos/threejs/espnow-policy-visualizer/`
- What it shows: 3 ESP32 boards converge on a civic template policy, rendered in a Three.js scene.
- Architecture:
  - A/B/C print deterministic envelope JSONL over serial
  - `bridge.py` reads serial, broadcasts via SSE, and persists `events.jsonl`
  - The browser viewer connects to `/events` (live) or replays from a saved `events.jsonl`
- Entry points:
  - Bridge: `demos/threejs/espnow-policy-visualizer/bridge.py`
  - Viewer: open `http://127.0.0.1:8765/`
  - Replay: `bridge.py --replay <events.jsonl>`
  - Benchmark/validator: `demos/threejs/espnow-policy-visualizer/bench_events.py`

## Serial port mapping

CP2102 adapters often share the same USB serial number, so prefer stable ports under:

- `/dev/serial/by-path/*`

