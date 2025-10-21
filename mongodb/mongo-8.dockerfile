# Stage 1: Build MongoDB tools with Go 1.24 and updated dependencies
FROM golang:1.24 AS builder

WORKDIR /build

# Install required dependencies
RUN apt-get update && apt-get install -y git

# Clone MongoDB database tools
RUN git clone --depth 1 --branch 100.10.0 https://github.com/mongodb/mongo-tools.git

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

# Stage 2: Final image based on official mongo:8.0.15
FROM mongo:8.0.15

# Metadata
LABEL maintainer="Testkube Team"
LABEL version="8.0.15-testkube"
LABEL description="MongoDB 8.0.15 - Testkube Edition - Recompiled binaries"

USER root

# Copy recompiled binaries with updated dependencies
COPY --from=builder /usr/local/bin/bsondump /usr/bin/bsondump
COPY --from=builder /usr/local/bin/mongodump /usr/bin/mongodump
COPY --from=builder /usr/local/bin/mongoexport /usr/bin/mongoexport
COPY --from=builder /usr/local/bin/mongofiles /usr/bin/mongofiles
COPY --from=builder /usr/local/bin/mongoimport /usr/bin/mongoimport
COPY --from=builder /usr/local/bin/mongorestore /usr/bin/mongorestore
COPY --from=builder /usr/local/bin/mongostat /usr/bin/mongostat
COPY --from=builder /usr/local/bin/mongotop /usr/bin/mongotop

# Apply Ubuntu security patches and update vulnerable packages
RUN apt-get update && \
    apt-get upgrade -y && \
    # Install latest versions of packages with CVE issues to get patches
    apt-get install -y --only-upgrade \
        coreutils \
        libssl3t64 \
        openssl \
        tar \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Create entrypoint script that handles permissions like Bitnami
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set environment variables for compatibility with Bitnami-style charts
ENV MONGODB_DATA_DIR="/data/db"
ENV MONGODB_DAEMON_USER="mongodb"
ENV MONGODB_DAEMON_GROUP="mongodb"
ENV MONGODB_VOLUME_DIR="/data"
ENV MONGODB_LOG_DIR="/data/logs"
ENV MONGODB_TMP_DIR="/data/tmp"

# Configure MongoDB to listen on all interfaces (required for Kubernetes)
ENV MONGODB_EXTRA_FLAGS="--bind_ip_all"

# Create directories with proper structure
RUN mkdir -p /data/db /data/logs /data/tmp && \
    chown -R 1001:1001 /data && \
    chmod -R 755 /data

# Switch to mongodb user (UID 1001 to match Bitnami chart)
USER 1001

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD mongosh --eval "db.adminCommand('ping')" || exit 1

EXPOSE 27017
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mongod"]
