# ESP32 A/B/C Policy Visualizer (Three.js + Replay)

This demo listens to the three ESP32 boards over serial (JSONL lines), persists an append-only `events.jsonl`, and
streams events to a browser viewer (live) or plays back a recorded run (replay).

The ESP32 firmware emits deterministic envelope events:

- `mkey = "rpc/" + method_name + "@schema/" + schema_id`
- `schema_id = sha256(canonical schema bytes)` (string `sha256:<hex>`)
- `deps` is always size 3: `[prev_state, trace_anchor, content_anchor]`

## Run (live)

1) Flash the boards (A/B/C) and connect them via USB.

2) Start the bridge server:

```bash
python3 demos/threejs/espnow-policy-visualizer/bridge.py \
  --a /dev/serial/by-path/pci-0000:00:14.0-usb-0:1:1.0-port0 \
  --b /dev/serial/by-path/pci-0000:00:14.0-usb-0:3:1.0-port0 \
  --c /dev/serial/by-path/pci-0000:00:14.0-usb-0:4:1.0-port0 \
  --out demos/threejs/espnow-policy-visualizer/events.jsonl
```

3) Open the viewer:

- `http://127.0.0.1:8765/`

## Run (replay)

```bash
python3 demos/threejs/espnow-policy-visualizer/bridge.py \
  --replay demos/threejs/espnow-policy-visualizer/events.jsonl
```

## Benchmark / validation

Validates:

- JSON is well-formed
- `schema_id` matches the envelope schema bytes
- `mkey = "rpc/<method>@schema/<schema_id>"`
- `deps` is exactly size 3
- `decision.statement_id` binds `statement_text` and `trace_id`
- per-node `prev_state` chains are consistent (handles node reboots)

Example:

```bash
python3 demos/threejs/espnow-policy-visualizer/bench_events.py \
  demos/threejs/espnow-policy-visualizer/events.jsonl \
  --allow-gaps --iters 20
```

## Note (network)

The viewer currently imports Three.js from `https://unpkg.com/` (simple “no-build” setup).
If you need offline operation, we can vendor `three.module.js` into the repo.
