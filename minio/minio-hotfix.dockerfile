# Use a lightweight Alpine Linux base image
FROM alpine:3.22

# Metadata
LABEL maintainer="Testkube Team"
LABEL version="2025-testkube"
LABEL description="Minio 2025 - Testkube Edition - Installed from binaries"

# Install required packages
RUN apk add --no-cache \
    ca-certificates \
    curl \
    jq \
    minio-client \
    procps \
    tini

# Create a non-root user for security
RUN addgroup -S minio-group && adduser -S -G minio-group minio-user

# Download the Minio binary and make it executable
RUN curl -o /usr/local/bin/minio https://dl.min.io/community/server/minio/hotfixes/linux-linux/minio && \
    chmod +x /usr/local/bin/minio

# Create a data directory and set permissions
RUN mkdir -p /data && \
    chown -R minio-user:minio-group /data

# Create a directory for Minio client configuration
RUN mkdir -p /home/minio-user/.mc && \
    chown -R minio-user:minio-group /home/minio-user/.mc

# Expose the Minio API and Console ports
EXPOSE 9000 9001

# Set the user to run the container
USER minio-user

# Set the entrypoint to run Minio server with tini
ENTRYPOINT ["/sbin/tini", "--"]

# Start the Minio server, pointing to the data directory
CMD ["minio", "server", "/data", "--console-address", ":9001"]
