# Use a lightweight Debian minimal image
FROM golang:1.25.3-alpine3.22 AS build

# Build arguments
ARG TARGETOS
ARG TARGETARCH
ARG GOMODCACHE="/root/.cache/go-build"
ARG GOCACHE="/go/pkg"
ARG MINIO_SERVER_VERSION=RELEASE.2025-10-15T17-29-55Z
ARG MINIO_CLIENT_VERSION=RELEASE.2025-08-13T08-35-41Z

# Set working directory
WORKDIR /build

# Update and install required packages: git, bash, perl, and make
RUN apk update && apk add --no-cache git make bash perl

# Git clone Minio server source code
RUN git clone --depth 1 --branch "${MINIO_SERVER_VERSION}" https://github.com/minio/minio

# Build Minio server binary
RUN cd minio && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    GOMODCACHE=${GOMODCACHE} GOCACHE=${GOCACHE} \
    make build && cd ..

# Git clone Minio Client source code
RUN git clone --depth 1 --branch "${MINIO_CLIENT_VERSION}" https://github.com/minio/mc

# Build Minio Client binary
RUN cd mc && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    GOMODCACHE=${GOMODCACHE} GOCACHE=${GOCACHE} \
    make build

FROM debian:bookworm-slim

ARG TARGETARCH

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    MINIO_SERVER_VERSION=RELEASE.2025-10-15T17-29-55Z \
    MINIO_CLIENT_VERSION=RELEASE.2025-08-13T08-35-41Z \
    APP_NAME=minio

# Metadata
LABEL maintainer="Testkube Team" \
      version="2025.10" \
      description="Minio Server - Testkube Edition"

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    jq \
    curl \
    procps \
    bash  \
    curl && \
    rm -rf /var/lib/apt/lists/*

# Use bash shell with strict error handling
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# TODO: replace with our own wait-for-port if needed
# Install Bitnami wait-for-port utility.
RUN curl -o /usr/local/bin/wait-for-port https://github.com/bitnami/wait-for-port/releases/download/v1.0.10/wait-for-port-linux-${OS_ARCH}.tar.gz \
&& chmod +x /usr/local/bin/wait-for-port

# Create a non-root user for security
RUN groupadd -r minio-group && useradd -r -g minio-group minio-user

# Copy Minio Client binary from build stage and set permissions
COPY --from=build /build/minio/mc /usr/local/bin/mc
RUN chmod +x /usr/local/bin/mc

# Copy Minio Server binary from build stage and set permissions
COPY --from=build /build/minio/minio /usr/local/bin/minio
RUN chmod +x /usr/local/bin/minio

# Create a data directory and set permissions
RUN mkdir -p /home/minio-user/data && \
    chown -R minio-user:minio-group /home/minio-user/data

# Create a tmp directory and chown it so PID process can be created without requiring root
RUN mkdir -p /home/minio-user/minio/tmp && \
    chown -R minio-user:minio-group /home/minio-user

# Create a directory for Minio client configuration
RUN mkdir -p /home/minio-user/.mc && \
    chown -R minio-user:minio-group /home/minio-user/.mc

# Remove setuid and setgid permissions for security hardening
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

# Copy scripts foldet to the container
COPY --chown=minio-user:minio-group scripts /home/minio-user/scripts

# Post unpacking scripts
RUN chmod -R +x /home/minio-user/scripts/ && /home/minio-user/scripts/postunpack.sh

# Volumes for data persistence and certificates
VOLUME [ "/home/minio-user/data", "/certs" ]

# Expose the Minio API and Console ports
EXPOSE 9000 9001

# Set the user to run the container
USER minio-user
WORKDIR /home/minio-user

# Set the entrypoint to run Minio server
ENTRYPOINT ["/home/minio-user/scripts/entrypoint.sh"]

# Start the Minio server
CMD ["/home/minio-user/scripts/run.sh"]
