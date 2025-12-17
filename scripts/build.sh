# BICF Production Build Pipeline

## Overview
Production-grade build system for BICF implementation with testing, validation, and deployment.

## Scripts
### build.sh
```bash
#!/bin/bash
set -e

echo "Building BICF Production System..."

# Build core modules
echo "Building BICF Core..."
npm run build:core

echo "Building FANO Boundary..."
npm run build:fano

echo "Building CanvasL Schema..."
npm run build:canvasl

echo "Building PCG Consensus..."
npm run build:consensus

echo "Building Integration Layer..."
npm run build:integration

echo "Running tests..."
npm run test:unit

echo "Building Docker images..."
npm run docker:build

echo "Build complete!"
```

### docker:build.sh
```bash
#!/bin/bash
set -e

echo "Building Docker images..."

# Build production image
docker build -t bicf/production:latest .

# Build validation image
docker build -t bicf/validation:latest -f Dockerfile.validation .

echo "Docker build complete!"
```

### Dockerfile.production
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
COPY dist/ ./dist/

RUN npm ci

EXPOSE 3000

CMD ["node", "dist/index.js"]
```

### Dockerfile.validation
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
COPY dist/ ./dist/

COPY tests/ ./tests/
COPY schemas/ ./schemas/

RUN npm ci

CMD ["node", "dist/validate-cli.js"]
```

## Usage
```bash
# Production build
./scripts/build.sh

# Docker deployment
./scripts/docker:build.sh

# Run tests
./scripts/test.sh
```

## Status
✅ Build scripts created
✅ Docker configuration optimized
✅ Multi-stage deployment pipeline