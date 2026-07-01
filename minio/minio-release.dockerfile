# Build stage.
# Go >= 1.25.7 / 1.26.0 fixes CVE-2025-68121 (crypto/tls). GOTOOLCHAIN=local
# forces the image's Go toolchain instead of the (older) version pinned in go.mod.
FROM golang:1.26.0-alpine3.22 AS build

# Build arguments
ARG TARGETOS
ARG TARGETARCH
ARG GOMODCACHE="/root/.cache/go-build"
ARG GOCACHE="/go/pkg"
ARG MINIO_SERVER_VERSION=RELEASE.2025-10-15T17-29-55Z
ARG MINIO_CLIENT_VERSION=RELEASE.2025-08-13T08-35-41Z
# gRPC >= 1.79.3 fixes CVE-2026-33186 (authorization bypass).
ARG GRPC_VERSION=v1.79.3

ENV GOTOOLCHAIN=local

# Set working directory
WORKDIR /build

# Update and install required packages: git, bash, perl, and make
RUN apk update && apk add --no-cache git make bash perl

# Git clone Minio server source code
RUN git clone --depth 1 --branch "${MINIO_SERVER_VERSION}" https://github.com/minio/minio

# Build Minio server binary (bump vulnerable gRPC dependency first)
RUN cd minio && \
    go get google.golang.org/grpc@${GRPC_VERSION} && go mod tidy && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    GOMODCACHE=${GOMODCACHE} GOCACHE=${GOCACHE} \
    make build && cd ..

# Git clone Minio Client source code
RUN git clone --depth 1 --branch "${MINIO_CLIENT_VERSION}" https://github.com/minio/mc

# Build Minio Client binary (bump vulnerable gRPC dependency first)
RUN cd mc && \
    go get google.golang.org/grpc@${GRPC_VERSION} && go mod tidy && \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    GOMODCACHE=${GOMODCACHE} GOCACHE=${GOCACHE} \
    make build

FROM debian:bookworm-slim

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

# TODO: replace with our own wait-for-port if needed
# Install Bitnami wait-for-port utility.
RUN curl -fsSL "https://github.com/bitnami/wait-for-port/releases/download/v1.0.10/wait-for-port-linux-${OS_ARCH}.tar.gz" -o /tmp/wait-for-port.tar.gz \
  && tar -xzf /tmp/wait-for-port.tar.gz -C /tmp \
  && install -m 0755 "$(find /tmp -maxdepth 1 -type f -name 'wait-for-port*' | head -n1)" /usr/local/bin/wait-for-port \
  && find /tmp -maxdepth 1 -type f -name 'wait-for-port*' -delete \
  && rm -f /tmp/wait-for-port.tar.gz

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
