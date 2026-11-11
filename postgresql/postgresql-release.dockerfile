# PostgreSQL Dockerfile - Testkube Edition
# Based on official postgres image
# POSTGRESQL_VERSION is updated by scripts/check-version.sh

# The entrypoint drops privileges with gosu, whose upstream binary is built with an
# old Go toolchain (most of the image's findings). Rebuild the same gosu release with
# a current toolchain; GOTOOLCHAIN=local ignores the older Go pinned in its go.mod.
FROM golang:1.27.3-alpine3.24 AS gosu-builder

ARG GOSU_VERSION=1.19
ENV GOTOOLCHAIN=local

RUN apk add --no-cache git
WORKDIR /src
RUN git clone --depth 1 --branch "${GOSU_VERSION}" https://github.com/tianon/gosu.git
WORKDIR /src/gosu
RUN CGO_ENABLED=0 go build -buildvcs=false -trimpath -ldflags "-d -s -w" -o /gosu .

FROM postgres:18.6

LABEL maintainer="Testkube Team" \
      description="PostgreSQL - Testkube Edition"

# Apply Debian security updates published after the upstream image was built.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY --from=gosu-builder /gosu /usr/local/bin/gosu
RUN gosu --version && gosu nobody true
