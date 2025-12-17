# BICF Production System Dockerfile
# Multi-stage build for BICF implementation

# Stage 1: Base image with Scheme interpreter
FROM ubuntu:22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    guile-3.0 \
    python3 \
    python3-pip \
    nodejs \
    npm \
    git \
    make \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Build stage
FROM base AS build

WORKDIR /build

# Copy source files
COPY src/ ./src/
COPY schemas/ ./schemas/
COPY scripts/ ./scripts/
COPY package.json ./

# Validate schemas
RUN python3 -m json.tool schemas/canvasl-schema.json > /dev/null

# Stage 3: Runtime stage
FROM base AS runtime

WORKDIR /app

# Copy built artifacts
COPY --from=build /build/src ./src
COPY --from=build /build/schemas ./schemas
COPY --from=build /build/scripts ./scripts

# Set up entry point
COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Default command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["help"]

