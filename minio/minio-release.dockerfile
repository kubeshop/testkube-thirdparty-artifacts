# Use a lightweight Debian minimal image
FROM debian:bullseye-slim

ARG TARGETARCH

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}"

# Metadata
LABEL maintainer="Testkube Team" \
      version="2025-testkube" \
      description="Minio 2025 - Testkube Edition"

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    jq \
    procps \
    bash && \
    rm -rf /var/lib/apt/lists/*

# Use bash shell with strict error handling
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

# TODO: replace with our own wait-for-port if needed
# Install Bitnami wait-for-port utility.
RUN curl -o /usr/local/bin/wait-for-port https://github.com/bitnami/wait-for-port/releases/download/v1.0.10/wait-for-port-linux-${OS_ARCH}.tar.gz \
&& chmod +x /usr/local/bin/wait-for-port

# Create a non-root user for security
RUN groupadd -r minio-group && useradd -r -g minio-group minio-user

# Download the Minio Client binary and make it executable
RUN curl -o /usr/local/bin/mc https://dl.min.io/community/client/mc/release/linux-${OS_ARCH}/mc && \
    chmod +x /usr/local/bin/mc

# Download the Minio binary and make it executable
RUN curl -o /usr/local/bin/minio https://dl.min.io/community/server/minio/release/linux-${OS_ARCH}/minio && \
    chmod +x /usr/local/bin/minio

# Create a data directory and set permissions
RUN mkdir -p /home/minio-user/data && \
    chown -R minio-user:minio-group /home/minio-user/data

# Create a directory for Minio client configuration
RUN mkdir -p /home/minio-user/.mc && \
    chown -R minio-user:minio-group /home/minio-user/.mc

# Remove setuid and setgid permissions for security hardening
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

# Copy scripts foldet to the container
COPY --chown=minio-user:minio-group scripts /home/minio-user/scripts

# Post unpacking scripts
RUN chmod -R +x /home/minio-user/scripts/ && /home/minio-user/scripts/postunpack.sh

# Environment variables for Minio configuration
ENV APP_VERSION=2025-10-18.hotfix \
    APP_NAME=minio

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
