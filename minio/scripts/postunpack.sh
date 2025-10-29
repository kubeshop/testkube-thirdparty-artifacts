#!/bin/bash

# shellcheck disable=SC1090,SC1091

# Load libraries
. /home/minio-user/scripts/lib/utils.sh

# Load MinIO environment
. /home/minio-user/scripts/lib/minio-env.sh

# Load MinIO Client environment
. /home/minio-user/scripts/lib/minio-client-env.sh

for dir in "$MINIO_CLIENT_BASE_DIR" "$MINIO_CLIENT_CONF_DIR"; do
    ensure_dir_exists "$dir"
done
chmod -R g+rwX "$MINIO_CLIENT_BASE_DIR" "$MINIO_CLIENT_CONF_DIR"

# Ensure non-root user has write permissions on a set of directories
for dir in "$MINIO_DATA_DIR" "$MINIO_CERTS_DIR" "$MINIO_LOGS_DIR" "$MINIO_TMP_DIR" "$MINIO_SECRETS_DIR"; do
    ensure_dir_exists "$dir"
done
chmod -R g+rwX "$MINIO_DATA_DIR" "$MINIO_CERTS_DIR" "$MINIO_LOGS_DIR" "$MINIO_SECRETS_DIR" "$MINIO_TMP_DIR"

# Redirect all logging to stdout/stderr
ln -sf /dev/stdout "$MINIO_LOGS_DIR/minio-http.log"
