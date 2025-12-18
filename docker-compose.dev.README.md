# Docker Compose Development Environment

This Docker Compose setup provides a complete development and testing environment for the BICF Production System, including formal verification (Coq+Dune, Lean 4), end-to-end testing, and demo modeling.

## Services

### 1. Coq+Dune Builder (`coq-dune-builder`)
- **Purpose**: Compiles Coq proofs using Dune
- **Image**: `coqorg/coq:8.18`
- **Build artifacts**: Stored in `./src/coq/_build/`

### 2. Lean 4 Verifier (`lean-verifier`)
- **Purpose**: Verifies Lean 4 proofs with Mathlib
- **Image**: `leanprover/lean4:v4.26.0`
- **Cache**: Lake build cache stored in `./.lake/`

### 3. Formal Verification Orchestrator (`formal-verification`)
- **Purpose**: Runs both Coq and Lean verification scripts
- **Depends on**: `coq-dune-builder`, `lean-verifier`
- **Runs**: `tests/formal/verify-coq.sh` and `tests/formal/verify-lean.sh`

### 4. E2E Testing Service (`e2e-tester`)
- **Purpose**: Runs full test suite
- **Command**: `scripts/test.sh`
- **Environment**: Testing mode with info-level logging

### 5. Demo Bridge Service (`demo-bridge`)
- **Purpose**: Three.js visualizer bridge (serial → WebSocket)
- **Ports**: `8765:8765` (WebSocket)
- **Modes**: 
  - `replay`: Replay from `events.jsonl`
  - `live`: Connect to ESP32 devices (requires `PORT_A`, `PORT_B`, `PORT_C`)

### 6. Demo Viewer Service (`demo-viewer`)
- **Purpose**: Serves Three.js visualizer web interface
- **Image**: `nginx:alpine`
- **Ports**: `8080:80` (HTTP)
- **URL**: http://localhost:8080

### 7. Asciinema Recorder (`asciinema-recorder`)
- **Purpose**: Records asciinema demos of ESP32 negotiation
- **Requires**: `PORT_A`, `PORT_B`, `PORT_C` environment variables
- **Output**: `demos/asciinema/espnow-abc/espnow-abc.cast`

## Quick Start

### Run Formal Verification
```bash
docker-compose -f docker-compose.dev.yml up coq-dune-builder lean-verifier formal-verification
```

### Run E2E Tests
```bash
docker-compose -f docker-compose.dev.yml up e2e-tester
```

### Run Demo (Replay Mode)
```bash
docker-compose -f docker-compose.dev.yml up demo-bridge demo-viewer
# Then open http://localhost:8080
```

### Run Demo (Live Mode with ESP32)
```bash
export PORT_A=/dev/ttyUSB0
export PORT_B=/dev/ttyUSB1
export PORT_C=/dev/ttyUSB2
docker-compose -f docker-compose.dev.yml up demo-bridge demo-viewer
```

### Record Asciinema Demo
```bash
export PORT_A=/dev/ttyUSB0
export PORT_B=/dev/ttyUSB1
export PORT_C=/dev/ttyUSB2
docker-compose -f docker-compose.dev.yml up asciinema-recorder
```

## Environment Variables

- `BRIDGE_MODE`: `replay` or `live` (default: `replay`)
- `EVENTS_FILE`: Path to events JSONL file (default: `/app/events.jsonl`)
- `PORT_A`, `PORT_B`, `PORT_C`: Serial device paths for ESP32 boards
- `BICF_ENV`: `testing`, `development`, or `production`
- `BICF_LOG_LEVEL`: `debug`, `info`, `warn`, or `error`

## Volumes

- `./src/coq/_build`: Coq build artifacts (read-write)
- `./.lake`: Lean 4 Lake cache (read-write)
- `./demos/threejs/espnow-policy-visualizer/events.jsonl`: Event log (read-write)
- All other volumes are read-only for safety

## Network

All services are connected to the `bicf-dev` bridge network for inter-service communication.

## Troubleshooting

### Coq compilation fails
- Check that `src/coq/dune-project` and `src/coq/dune` are present
- Ensure Coq version matches (8.18)

### Lean verification fails
- Check that `lakefile.lean` and `lean-toolchain` are present
- Mathlib may take time to download on first run

### Demo bridge can't connect to serial devices
- Ensure devices are accessible (may need `--privileged` or device mappings)
- Check that `PORT_A`, `PORT_B`, `PORT_C` are set correctly

### Asciinema recorder can't access serial devices
- The service includes device mappings for `/dev/ttyUSB0-2`
- For other devices, modify the `devices:` section in `docker-compose.dev.yml`

## Notes

- The Coq and Lean services run independently and can be used separately
- The formal verification orchestrator waits for both to complete
- Demo services can run in isolation for development
- All services use read-only mounts where possible for safety

