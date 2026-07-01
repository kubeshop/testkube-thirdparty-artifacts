# Dex Dockerfile - Testkube Edition
# DEX_VERSION is updated by scripts/check-version.sh
#
# The upstream dexidp/dex releases still ship known CRITICAL/HIGH CVEs that live
# inside the compiled Go binaries (Go stdlib crypto/tls and google.golang.org/grpc),
# which cannot be fixed by patching OS packages alone. To remediate them we:
#   1. Rebuild the dex binaries from source with a patched Go toolchain.
#   2. Rebuild gomplate (shipped in the upstream alpine image) the same way.
#   3. Bump the vulnerable Go modules (gRPC) above the fixed versions.
#   4. Reuse the upstream alpine image layout and patch OS packages (openssl, ...).

ARG DEX_VERSION=v2.45.1
# Go >= 1.25.7 / 1.26.0 fixes CVE-2025-68121 (crypto/tls).
ARG GO_IMAGE=golang:1.26.0-alpine3.22
# gRPC >= 1.79.3 fixes CVE-2026-33186 (authorization bypass).
ARG GRPC_VERSION=v1.79.3
# gomplate version shipped by the upstream dex alpine image.
ARG GOMPLATE_VERSION=v5.0.0

# ---------------------------------------------------------------------------
# Build dex + docker-entrypoint from source with a patched toolchain.
# ---------------------------------------------------------------------------
FROM ${GO_IMAGE} AS builder

ARG DEX_VERSION
ARG GRPC_VERSION

RUN apk add --no-cache git make bash

WORKDIR /usr/local/src
RUN git clone --depth 1 --branch "${DEX_VERSION}" https://github.com/dexidp/dex.git

WORKDIR /usr/local/src/dex

# Patch the vulnerable gRPC dependency in both the root and api/v2 modules.
RUN cd api/v2 && go get google.golang.org/grpc@${GRPC_VERSION} && go mod tidy
RUN go get google.golang.org/grpc@${GRPC_VERSION} && go mod tidy

# Build static binaries. -buildvcs=false avoids stamping a "+dirty" pseudo
# version (which otherwise breaks module version detection during CVE scans).
RUN CGO_ENABLED=0 go build -buildvcs=false -o /go/bin/dex \
      -ldflags "-w -X main.version=${DEX_VERSION} -extldflags \"-static\"" \
      ./cmd/dex \
 && CGO_ENABLED=0 go build -buildvcs=false -o /go/bin/docker-entrypoint \
      -ldflags "-w -extldflags \"-static\"" \
      ./cmd/docker-entrypoint

# ---------------------------------------------------------------------------
# Rebuild gomplate from source with the same patched toolchain + gRPC bump.
# ---------------------------------------------------------------------------
FROM ${GO_IMAGE} AS gomplate-builder

ARG GOMPLATE_VERSION
ARG GRPC_VERSION

RUN apk add --no-cache git

WORKDIR /usr/local/src
RUN git clone --depth 1 --branch "${GOMPLATE_VERSION}" https://github.com/hairyhenderson/gomplate.git

WORKDIR /usr/local/src/gomplate
RUN go get google.golang.org/grpc@${GRPC_VERSION} && go mod tidy
RUN CGO_ENABLED=0 go build -buildvcs=false -o /go/bin/gomplate ./cmd/gomplate

# ---------------------------------------------------------------------------
# Final image reuses the upstream alpine layout (web assets, config, user).
# ---------------------------------------------------------------------------
FROM dexidp/dex:${DEX_VERSION}-alpine

LABEL maintainer="Testkube Team" \
      description="Dex - Testkube Edition"

USER root

# Apply available Alpine security patches (openssl, etc.) on top of upstream.
RUN apk --no-cache upgrade

# Replace upstream binaries with versions rebuilt against patched Go + gRPC.
COPY --from=builder /go/bin/dex /usr/local/bin/dex
COPY --from=builder /go/bin/docker-entrypoint /usr/local/bin/docker-entrypoint
COPY --from=gomplate-builder /go/bin/gomplate /usr/local/bin/gomplate

USER dex:dex
