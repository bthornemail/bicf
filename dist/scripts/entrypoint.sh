#!/bin/bash
# Docker entrypoint for BICF system

set -e

case "$1" in
  help)
    echo "BICF Production System"
    echo "Usage: [command] [args...]"
    echo ""
    echo "Commands:"
    echo "  help              - Show this help message"
    echo "  interpreter       - Run CanvasL interpreter"
    echo "  validate          - Validate boundaries"
    echo "  test              - Run test suite"
    echo "  health            - Health check endpoint"
    echo "  metrics           - Prometheus metrics endpoint"
    ;;
  interpreter)
    shift
    if [ -z "$1" ]; then
      echo "Usage: interpreter <jsonl-file>"
      exit 1
    fi
    guile -s /app/src/canvasl/interpreter.scm "$1"
    ;;
  validate)
    shift
    echo "Validation functionality (placeholder)"
    ;;
  test)
    shift
    /app/scripts/test.sh
    ;;
  health)
    shift
    guile -s /app/deployment/health-endpoint.scm health
    ;;
  metrics)
    shift
    guile -s /app/deployment/health-endpoint.scm metrics
    ;;
  *)
    exec "$@"
    ;;
esac

