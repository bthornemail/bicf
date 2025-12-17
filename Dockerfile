# BICF Production System Dockerfile
# Multi-stage build for BICF implementation with optimization

# Stage 1: Base image with Scheme interpreter and build tools
FROM ubuntu:22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    guile-3.0 \
    python3 \
    python3-pip \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Build stage with all dependencies
FROM base AS build

# Install build dependencies
RUN apt-get update && apt-get install -y \
    make \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy source files
COPY src/ ./src/
COPY schemas/ ./schemas/
COPY scripts/ ./scripts/
COPY tests/ ./tests/
COPY package.json ./

# Validate schemas
RUN python3 -m json.tool schemas/canvasl-schema.json > /dev/null || true

# Run build script
RUN chmod +x scripts/build.sh && \
    scripts/build.sh || true

# Stage 3: Runtime stage (optimized)
FROM base AS runtime

WORKDIR /app

# Create non-root user
RUN useradd -m -u 1000 bicf && \
    mkdir -p /app && \
    chown -R bicf:bicf /app

# Copy built artifacts
COPY --from=build --chown=bicf:bicf /build/src ./src
COPY --from=build --chown=bicf:bicf /build/schemas ./schemas
COPY --from=build --chown=bicf:bicf /build/scripts ./scripts
COPY --from=build --chown=bicf:bicf /build/tests ./tests

# Set up entry point
COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD guile -c "(display \"health\")" || exit 1

# Switch to non-root user
USER bicf

# Default command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["help"]

