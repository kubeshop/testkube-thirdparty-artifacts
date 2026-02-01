# Stage 1: Build MongoDB tools with Go 1.25 and updated dependencies
FROM golang:1.25 AS builder

ARG TOOLS_VERSION=100.13.0

WORKDIR /build

# Install required dependencies
RUN apt-get update && apt-get install -y git

# Clone MongoDB database tools
RUN git clone --depth 1 --branch ${TOOLS_VERSION}  https://github.com/mongodb/mongo-tools.git

WORKDIR /build/mongo-tools

# Update dependencies and regenerate vendor directory
RUN go get golang.org/x/crypto@v0.35.0 && \
    go mod tidy && \
    go mod vendor

# Build each tool using updated vendor directory
RUN go build -mod=vendor -o /usr/local/bin/bsondump ./bsondump/main/bsondump.go
RUN go build -mod=vendor -o /usr/local/bin/mongodump ./mongodump/main/mongodump.go
RUN go build -mod=vendor -o /usr/local/bin/mongoexport ./mongoexport/main/mongoexport.go
RUN go build -mod=vendor -o /usr/local/bin/mongofiles ./mongofiles/main/mongofiles.go
RUN go build -mod=vendor -o /usr/local/bin/mongoimport ./mongoimport/main/mongoimport.go
RUN go build -mod=vendor -o /usr/local/bin/mongorestore ./mongorestore/main/mongorestore.go
RUN go build -mod=vendor -o /usr/local/bin/mongostat ./mongostat/main/mongostat.go
RUN go build -mod=vendor -o /usr/local/bin/mongotop ./mongotop/main/mongotop.go

# Stage 2: Template MongoDB configuration file
FROM golang:1.25 AS template-builder

RUN apt-get update && apt-get install -y git

ARG GOMODCACHE="/root/.cache/go-build"
ARG GOCACHE="/go/pkg"

WORKDIR /src
RUN git clone https://github.com/kubeshop/bitnami-render-template.git
WORKDIR /src/bitnami-render-template
RUN --mount=type=cache,target="$GOMODCACHE" \
    --mount=type=cache,target="$GOCACHE" \
    GOOS=$TARGETOS \
    GOARCH=$TARGETARCH \
    CGO_ENABLED=0 \
    go build -o /opt/bitnami/common/bin/render-template *.go

# Stage 3: Final image based on official MongoDB
# MONGODB_VERSION is updated by scripts/check-version.sh
FROM mongo:8.2.4

ARG TARGETARCH

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    APP_NAME=mongodb

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# Apply Ubuntu security patches and update vulnerable packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libbrotli1 \
        libcom-err2 \
        libcurl4 \
        libffi8 \
        libgcc-s1 \
        libgmp10 \
        libgnutls30 \
        libgssapi-krb5-2 \
        libhogweed6 \
        libidn2-0 \
        libk5crypto3 \
        libkeyutils1 \
        libkrb5-3 \
        libkrb5support0 \
        libldap2 \
        libnettle8 \
        libnghttp2-14 \
        libp11-kit0 \
        libpsl5 \
        librtmp1 \
        libsasl2-2 \
        libssh2-1 \
        libssl3 \
        libtasn1-6 \
        libunistring5 \
        libzstd1 \
        numactl \
        procps \
        zlib1g \
        yq \
        wait-for-it \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# TODO: replace with our own wait-for-port if needed
# Install Bitnami wait-for-port utility.
RUN curl -fsSL "https://github.com/bitnami/wait-for-port/releases/download/v1.0.10/wait-for-port-linux-${OS_ARCH}.tar.gz" -o /tmp/wait-for-port.tar.gz \
  && tar -xzf /tmp/wait-for-port.tar.gz -C /tmp \
  && install -m 0755 "$(find /tmp -maxdepth 1 -type f -name 'wait-for-port*' | head -n1)" /usr/local/bin/wait-for-port \
  && find /tmp -maxdepth 1 -type f -name 'wait-for-port*' -delete \
  && rm -f /tmp/wait-for-port.tar.gz

# Copy render template binary
COPY --from=template-builder /opt/bitnami/common/bin/render-template /opt/bitnami/common/bin/render-template

RUN mkdir -p /opt/bitnami/mongodb

# Copy recompiled binaries with updated dependencies
COPY --from=builder /usr/local/bin/mongo* /usr/local/bin/bsondump /opt/bitnami/mongodb/bin/

# Copy scripts foldet to the container
COPY scripts /opt/bitnami/scripts

COPY ./templates /opt/bitnami/mongodb/templates

RUN chmod -R g+rwX /opt/bitnami
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

# Post unpacking scripts
RUN /opt/bitnami/scripts/postunpack.sh

# Metadata
LABEL maintainer="Testkube Team" \
  version="8.0.15-testkube" \
  description="MongoDB 8.0.15 - Testkube Edition - Based on official"

# Volumes for data persistence and certificates
VOLUME [ "/volume/mongodb/data/db", "/certs" ]

EXPOSE 27017

# Set the user to run the container
USER 1001

ENTRYPOINT ["/opt/bitnami/scripts/entrypoint.sh"]
CMD ["/opt/bitnami/scripts/run.sh"]
