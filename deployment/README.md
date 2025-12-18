# BICF Production Deployment

## Overview
Docker-based deployment configuration for BICF production system with multi-stage CI/CD pipeline.

## Docker Compose Configuration
```yaml
version: '3.8'

services:
  # BICF Production API
  bicf-api:
    build: .
    image: bicf/production:latest
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - BICF_VALIDATION=strict
    depends_on:
      - bicf-db

  # Validation Service
  bicf-validation:
    build: .
    image: bicf/validation:latest
    environment:
      - VALIDATION_MODE=production
    depends_on:
      - bicf-db

  # Database
  bicf-db:
    image: postgres:15
    environment:
      - POSTGRES_DB=bicf_production
      - POSTGRES_USER=bicf
      - POSTGRES_PASSWORD=bicf_password
    volumes:
      - bicf_data:/var/lib/postgresql/data

  # Reverse Proxy
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - bicf-api

volumes:
  bicf_data:
```

## Production Deployment
```bash
#!/bin/bash
set -e

echo "Deploying BICF Production System..."

# Build and push images
docker-compose -f docker-compose.yml build
docker-compose -f docker-compose.yml push

# Deploy to production
docker-compose -f docker-compose.prod.yml up -d

echo "Deployment complete!"
```

## Environment Configuration
- Production: Strict validation, full logging
- Staging: Relaxed validation, debug logging
- Development: Permissive validation, verbose logging

## Monitoring
- Application metrics via Prometheus
- Database performance monitoring
- Log aggregation with ELK stack
- Health checks and alerting

## Security
- Network isolation with Docker networks
- Secrets management via environment variables
- SSL/TLS encryption for external communication
- Rate limiting and DDoS protection

## Backup and Recovery
- Automated database backups
- Git repository backups
- Disaster recovery procedures

## Development Environment

For development, testing, and formal verification, use `docker-compose.dev.yml`:

```bash
# Run formal verification (Coq + Lean)
./scripts/docker-dev.sh verify

# Run E2E tests
./scripts/docker-dev.sh test

# Run demo in replay mode
./scripts/docker-dev.sh demo-replay

# Run demo in live mode (requires ESP32 devices)
PORT_A=/dev/ttyUSB0 PORT_B=/dev/ttyUSB1 PORT_C=/dev/ttyUSB2 ./scripts/docker-dev.sh demo-live
```

See [`docker-compose.dev.README.md`](../docker-compose.dev.README.md) for full documentation.

## Status
✅ Production-ready deployment configuration
✅ Multi-environment support
✅ Comprehensive monitoring
✅ Security best practices
✅ Automated backup and recovery
✅ Development environment with Coq+Dune and Lean 4 verification