#!/bin/bash
# Docker Compose Development Helper Script

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

COMPOSE_FILE="docker-compose.dev.yml"

usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
  verify          Run formal verification (Coq + Lean)
  test            Run E2E test suite
  demo-replay     Run demo in replay mode (Three.js viewer)
  demo-live       Run demo in live mode (requires PORT_A, PORT_B, PORT_C)
  record          Record asciinema demo (requires PORT_A, PORT_B, PORT_C)
  build           Build Coq and Lean services
  clean           Clean build artifacts and volumes
  logs <service>  Show logs for a service
  help            Show this help message

Examples:
  $0 verify
  $0 demo-replay
  PORT_A=/dev/ttyUSB0 PORT_B=/dev/ttyUSB1 PORT_C=/dev/ttyUSB2 $0 demo-live
  PORT_A=/dev/ttyUSB0 PORT_B=/dev/ttyUSB1 PORT_C=/dev/ttyUSB2 $0 record
EOF
}

case "${1:-help}" in
    verify)
        echo "Running formal verification..."
        docker-compose -f "$COMPOSE_FILE" up --build coq-dune-builder lean-verifier formal-verification
        ;;
    test)
        echo "Running E2E tests..."
        docker-compose -f "$COMPOSE_FILE" up --build e2e-tester
        ;;
    demo-replay)
        echo "Starting demo in replay mode..."
        docker-compose -f "$COMPOSE_FILE" up --build demo-bridge demo-viewer
        echo ""
        echo "Demo viewer available at: http://localhost:8080"
        ;;
    demo-live)
        if [ -z "$PORT_A" ] || [ -z "$PORT_B" ] || [ -z "$PORT_C" ]; then
            echo "Error: PORT_A, PORT_B, and PORT_C must be set for live mode"
            echo "Example: PORT_A=/dev/ttyUSB0 PORT_B=/dev/ttyUSB1 PORT_C=/dev/ttyUSB2 $0 demo-live"
            exit 1
        fi
        export BRIDGE_MODE=live
        echo "Starting demo in live mode with ports: $PORT_A, $PORT_B, $PORT_C"
        docker-compose -f "$COMPOSE_FILE" up --build demo-bridge demo-viewer
        echo ""
        echo "Demo viewer available at: http://localhost:8080"
        ;;
    record)
        if [ -z "$PORT_A" ] || [ -z "$PORT_B" ] || [ -z "$PORT_C" ]; then
            echo "Error: PORT_A, PORT_B, and PORT_C must be set for recording"
            echo "Example: PORT_A=/dev/ttyUSB0 PORT_B=/dev/ttyUSB1 PORT_C=/dev/ttyUSB2 $0 record"
            exit 1
        fi
        echo "Recording asciinema demo with ports: $PORT_A, $PORT_B, $PORT_C"
        docker-compose -f "$COMPOSE_FILE" up --build asciinema-recorder
        ;;
    build)
        echo "Building Coq and Lean services..."
        docker-compose -f "$COMPOSE_FILE" build coq-dune-builder lean-verifier
        ;;
    clean)
        echo "Cleaning build artifacts..."
        docker-compose -f "$COMPOSE_FILE" down -v
        rm -rf src/coq/_build .lake
        echo "Clean complete"
        ;;
    logs)
        if [ -z "$2" ]; then
            echo "Error: Service name required"
            echo "Available services: coq-dune-builder, lean-verifier, formal-verification, e2e-tester, demo-bridge, demo-viewer, asciinema-recorder"
            exit 1
        fi
        docker-compose -f "$COMPOSE_FILE" logs -f "$2"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac

