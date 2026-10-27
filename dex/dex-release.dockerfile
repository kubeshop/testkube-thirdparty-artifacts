# Dex Dockerfile - Testkube Edition
# DEX_VERSION is updated by scripts/check-version.sh
#
# The upstream dexidp/dex releases still ship known CRITICAL/HIGH CVEs that live
# inside the compiled Go binaries,
# which cannot be fixed by patching OS packages alone. To remediate them we:
#   1. Rebuild the dex binaries from source with a patched Go toolchain.
#   2. Rebuild gomplate (shipped in the upstream alpine image) the same way.
#   3. Update the remaining vulnerable Go modules.
#   4. Reuse the upstream alpine image layout and patch OS packages (openssl, ...).

ARG DEX_VERSION=v2.46.1
ARG GO_IMAGE=golang:1.27.3-alpine3.24
# gomplate version shipped by the upstream dex alpine image.
ARG GOMPLATE_VERSION=v5.2.0

# ---------------------------------------------------------------------------
# Build dex + docker-entrypoint from source with a patched toolchain.
# ---------------------------------------------------------------------------
FROM ${GO_IMAGE} AS builder

ARG DEX_VERSION

RUN apk --no-cache upgrade \
 && apk add --no-cache git make bash gcc "musl-dev>=1.2.6-r3"

WORKDIR /usr/local/src
RUN git clone --depth 1 --branch "${DEX_VERSION}" https://github.com/dexidp/dex.git

WORKDIR /usr/local/src/dex

# Patch x/net in both modules; retain the newer dependencies supplied by Dex.
RUN cd api/v2 && go get golang.org/x/net@v0.60.0 && go mod tidy
RUN go get golang.org/x/net@v0.60.0 && go mod tidy

# Build static binaries. -buildvcs=false avoids stamping a "+dirty" pseudo
# version (which otherwise breaks module version detection during CVE scans).
RUN CGO_ENABLED=1 go build -buildvcs=false -o /go/bin/dex \
      -ldflags "-w -X main.version=${DEX_VERSION} -extldflags \"-static\"" \
      ./cmd/dex \
 && CGO_ENABLED=0 go build -buildvcs=false -o /go/bin/docker-entrypoint \
      -ldflags "-w -extldflags \"-static\"" \
      ./cmd/docker-entrypoint

# ---------------------------------------------------------------------------
# Rebuild gomplate from source with patched dependencies and toolchain.
# ---------------------------------------------------------------------------
FROM ${GO_IMAGE} AS gomplate-builder

ARG GOMPLATE_VERSION

RUN apk add --no-cache git

WORKDIR /usr/local/src
RUN git clone --depth 1 --branch "${GOMPLATE_VERSION}" https://github.com/hairyhenderson/gomplate.git

WORKDIR /usr/local/src/gomplate
RUN go get google.golang.org/grpc@v1.84.0 golang.org/x/net@v0.60.0 \
      github.com/go-git/go-git/v5@v5.19.2 \
      go.opentelemetry.io/otel/sdk@v1.45.0 \
 && go mod tidy
RUN CGO_ENABLED=0 go build -buildvcs=false -o /go/bin/gomplate \
      -ldflags "-w -X github.com/hairyhenderson/gomplate/v5/version.Version=${GOMPLATE_VERSION}" \
      ./cmd/gomplate

# ---------------------------------------------------------------------------
# Final image reuses the upstream alpine layout (web assets, config, user).
# ---------------------------------------------------------------------------
FROM dexidp/dex:${DEX_VERSION}-alpine

LABEL maintainer="Testkube Team" \
      description="Dex - Testkube Edition"

USER root

# Apply available Alpine security patches (openssl, etc.) on top of upstream.
RUN apk --no-cache upgrade \
 && apk add --no-cache "libcrypto3>=3.5.9-r0" "libssl3>=3.5.9-r0" \
      "musl>=1.2.6-r3" "zlib>=1.3.2-r1" "ca-certificates-bundle>=20261020-r0"

# Keep dependency manifests consistent with the rebuilt binaries.
COPY --from=builder /usr/local/src/dex/go.mod /usr/local/src/dex/go.sum /usr/local/src/dex/
COPY --from=builder /usr/local/src/dex/api/v2/go.mod /usr/local/src/dex/api/v2/go.sum /usr/local/src/dex/api/v2/

# Replace upstream binaries with versions rebuilt against patched dependencies.
COPY --from=builder /go/bin/dex /usr/local/bin/dex
COPY --from=builder /go/bin/docker-entrypoint /usr/local/bin/docker-entrypoint
COPY --from=gomplate-builder /go/bin/gomplate /usr/local/bin/gomplate

USER dex:dex
