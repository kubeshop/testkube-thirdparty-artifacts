#!/bin/bash

# Environment configuration for minio

# Load logging library
# shellcheck disable=SC1090,SC1091

. /opt/bitnami/scripts/lib/utils.sh

export ROOT_DIR="/opt/bitnami"
export VOLUME_DIR="/bitnami"

# Logging configuration
export MODULE="${MODULE:-minio}"
export DEBUG="${DEBUG:-false}"

# By setting an environment variable matching *_FILE to a file path, the prefixed environment
# variable will be overridden with the value specified in that file
minio_env_vars=(
    MINIO_DATA_DIR
    MINIO_API_PORT_NUMBER
    MINIO_CONSOLE_PORT_NUMBER
    MINIO_SCHEME
    MINIO_SKIP_CLIENT
    MINIO_DISTRIBUTED_MODE_ENABLED
    MINIO_DEFAULT_BUCKETS
    MINIO_STARTUP_TIMEOUT
    MINIO_SERVER_URL
    MINIO_APACHE_CONSOLE_HTTP_PORT_NUMBER
    MINIO_APACHE_CONSOLE_HTTPS_PORT_NUMBER
    MINIO_APACHE_API_HTTP_PORT_NUMBER
    MINIO_APACHE_API_HTTPS_PORT_NUMBER
    MINIO_FORCE_NEW_KEYS
    MINIO_ROOT_USER
    MINIO_ROOT_PASSWORD
)
for env_var in "${minio_env_vars[@]}"; do
    file_env_var="${env_var}_FILE"
    if [[ -n "${!file_env_var:-}" ]]; then
        if [[ -r "${!file_env_var:-}" ]]; then
            export "${env_var}=$(< "${!file_env_var}")"
            unset "${file_env_var}"
        else
            warn "Skipping export of '${env_var}'. '${!file_env_var:-}' is not readable."
        fi
    fi
done
unset minio_env_vars

# Paths
export MINIO_BASE_DIR="${ROOT_DIR}/minio"
export MINIO_BIN_DIR="${MINIO_BASE_DIR}/bin"
export MINIO_CERTS_DIR="/certs"
export MINIO_LOGS_DIR="${MINIO_BASE_DIR}/log"
export MINIO_TMP_DIR="${MINIO_BASE_DIR}/tmp"
export MINIO_SECRETS_DIR="${MINIO_BASE_DIR}/secrets"
export MINIO_DATA_DIR="${MINIO_DATA_DIR:-/home/minio-user/data}"
export MINIO_LOG_FILE="${MINIO_LOGS_DIR}/minio.log"
export MINIO_PID_FILE="${MINIO_TMP_DIR}/minio.pid"
export PATH="${MINIO_BIN_DIR}:${PATH}"

# System users (when running with a privileged user)
export MINIO_DAEMON_USER="minio"
export MINIO_DAEMON_GROUP="minio"

# MinIO configuration
export MINIO_API_PORT_NUMBER="${MINIO_API_PORT_NUMBER:-9000}"
export MINIO_CONSOLE_PORT_NUMBER="${MINIO_CONSOLE_PORT_NUMBER:-9001}"
export MINIO_SCHEME="${MINIO_SCHEME:-http}"
export MINIO_SKIP_CLIENT="${MINIO_SKIP_CLIENT:-no}"
export MINIO_DISTRIBUTED_MODE_ENABLED="${MINIO_DISTRIBUTED_MODE_ENABLED:-no}"
export MINIO_DEFAULT_BUCKETS="${MINIO_DEFAULT_BUCKETS:-}"
export MINIO_STARTUP_TIMEOUT="${MINIO_STARTUP_TIMEOUT:-10}"
export MINIO_SERVER_URL="${MINIO_SERVER_URL:-$MINIO_SCHEME://localhost:$MINIO_API_PORT_NUMBER}"

# MinIO apache proxy ports
export MINIO_APACHE_CONSOLE_HTTP_PORT_NUMBER="${MINIO_APACHE_CONSOLE_HTTP_PORT_NUMBER:-80}"
export MINIO_APACHE_CONSOLE_HTTPS_PORT_NUMBER="${MINIO_APACHE_CONSOLE_HTTPS_PORT_NUMBER:-443}"
export MINIO_APACHE_API_HTTP_PORT_NUMBER="${MINIO_APACHE_API_HTTP_PORT_NUMBER:-9000}"
export MINIO_APACHE_API_HTTPS_PORT_NUMBER="${MINIO_APACHE_API_HTTPS_PORT_NUMBER:-9443}"

# MinIO security
export MINIO_FORCE_NEW_KEYS="${MINIO_FORCE_NEW_KEYS:-no}"
export MINIO_ROOT_USER="${MINIO_ROOT_USER:-minio}"
export MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-miniosecret}"

# Custom environment variables may be defined below
