# Build stage.
# MinIO is archived upstream, so its CVEs are fixed only by rebuilding with a current
# Go toolchain and dependencies. GOTOOLCHAIN=local forces the image's Go toolchain
# instead of the (older) version pinned in go.mod.
FROM golang:1.27.3-alpine3.24 AS build

# Build arguments
ARG TARGETOS
ARG TARGETARCH
ARG GOMODCACHE="/root/.cache/go-build"
ARG GOCACHE="/go/pkg"
ARG MINIO_SERVER_VERSION=RELEASE.2025-10-15T17-29-55Z
ARG MINIO_CLIENT_VERSION=RELEASE.2025-08-13T08-35-41Z
# gRPC >= 1.84.0 fixes CVE-2026-33186 (authorization bypass) and later gRPC findings.
ARG GRPC_VERSION=v1.84.0
ARG X_CRYPTO_VERSION=v0.58.0
ARG X_NET_VERSION=v0.62.0
# amqp091-go >= 1.13.0 fixes three critical findings in the AMQP notification target.
ARG AMQP091_VERSION=v1.13.0
ARG COMPRESS_VERSION=v1.18.7
ARG PROMETHEUS_VERSION=v0.311.3
ARG WAIT_FOR_PORT_VERSION=v1.0.11

ENV GOTOOLCHAIN=local

# Set working directory
WORKDIR /build

# Update and install required packages: git, bash, perl, and make
RUN apk update && apk add --no-cache git make bash perl

# Git clone Minio server source code
RUN git clone --depth 1 --branch "${MINIO_SERVER_VERSION}" https://github.com/minio/minio

# Build Minio server binary (bump vulnerable dependencies first)
RUN cd minio && \
    go get google.golang.org/grpc@${GRPC_VERSION} golang.org/x/crypto@${X_CRYPTO_VERSION} \
      golang.org/x/net@${X_NET_VERSION} github.com/rabbitmq/amqp091-go@${AMQP091_VERSION} \
      github.com/klauspost/compress@${COMPRESS_VERSION} \
      github.com/go-jose/go-jose/v4@v4.1.6 \
      github.com/buger/jsonparser@v1.1.2 github.com/apache/thrift@v0.24.0 && \
    go mod tidy && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    GOMODCACHE=${GOMODCACHE} GOCACHE=${GOCACHE} \
    make build && cd ..

# Git clone Minio Client source code
RUN git clone --depth 1 --branch "${MINIO_CLIENT_VERSION}" https://github.com/minio/mc

# Build Minio Client binary (bump vulnerable dependencies first)
RUN cd mc && \
    go get google.golang.org/grpc@${GRPC_VERSION} golang.org/x/crypto@${X_CRYPTO_VERSION} \
      golang.org/x/net@${X_NET_VERSION} github.com/klauspost/compress@${COMPRESS_VERSION} \
      github.com/prometheus/prometheus@${PROMETHEUS_VERSION} && go mod tidy && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    GOMODCACHE=${GOMODCACHE} GOCACHE=${GOCACHE} \
    make build && cd ..

# Build wait-for-port (used by the chart's provisioning job) from source: the
# published release binaries are built with an old Go toolchain.
RUN git clone --depth 1 --branch "${WAIT_FOR_PORT_VERSION}" https://github.com/bitnami/wait-for-port && \
    cd wait-for-port && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -buildvcs=false -trimpath -ldflags "-s -w" -o /build/bin/wait-for-port .

# Debian 13: most remaining OS findings on Debian 12 have no fix.
FROM debian:trixie-slim

ARG TARGETARCH

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    MINIO_SERVER_VERSION=RELEASE.2025-10-15T17-29-55Z \
    MINIO_CLIENT_VERSION=RELEASE.2025-08-13T08-35-41Z \
    APP_NAME=minio \
    PATH="/opt/bitnami/common/bin:/opt/bitnami/minio-client/bin:/opt/bitnami/minio/bin:$PATH"

# Metadata
LABEL maintainer="Testkube Team" \
      version="2025.10" \
      description="Minio Server - Testkube Edition"

# Install required packages and apply available OS security patches
# (fixes CVE-2026-31789 openssl, CVE-2026-33845/42010 gnutls, perl-base, ...).
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    ca-certificates \
    jq \
    curl \
    procps \
    bash \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Use bash shell with strict error handling
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

COPY --from=build /build/bin/wait-for-port /usr/local/bin/wait-for-port

# Create a non-root user for security
# RUN groupadd -r minio-group && useradd -r -g minio-group minio-user

# Copy Minio Client binary from build stage and set permissions
COPY --from=build /build/mc/mc /opt/bitnami/common/bin/mc
RUN chmod +x /opt/bitnami/common/bin/mc

# Copy Minio Server binary from build stage and set permissions
COPY --from=build /build/minio/minio /opt/bitnami/common/bin/minio
RUN chmod +x /opt/bitnami/common/bin/minio

# Create a data directory and set permissions
# RUN mkdir -p /bitnami/minio/data && \
#     chown -R minio-user:minio-group /bitnami/minio/data

# Create a tmp directory and chown it so PID process can be created without requiring root
# RUN mkdir -p /bitnami/minio/minio/tmp && \
#     chown -R minio-user:minio-group /home/minio-user

# Create a directory for Minio client configuration
# RUN mkdir -p /bitnami/minio/.mc && \
#     chown -R minio-user:minio-group /bitnami/minio/.mc

RUN chmod g+rwX /opt/bitnami

# Remove setuid and setgid permissions for security hardening
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

# Copy scripts foldet to the container
COPY scripts /opt/bitnami/scripts

# Post unpacking scripts
RUN /opt/bitnami/scripts/postunpack.sh

# Volumes for data persistence and certificates
VOLUME [ "/bitnami/minio/data", "/certs" ]

# Expose the Minio API and Console ports
EXPOSE 9000 9001

# Set the user to run the container
USER 1001

# Set the entrypoint to run Minio server
ENTRYPOINT ["/opt/bitnami/scripts/entrypoint.sh"]

# Start the Minio server
CMD ["/opt/bitnami/scripts/run.sh"]
