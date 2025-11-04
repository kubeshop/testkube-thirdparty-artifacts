#!/bin/bash

# Environment configuration for minio-client

# Load logging library
# shellcheck disable=SC1090,SC1091
. /home/minio-user/scripts/lib/utils.sh

export ROOT_DIR="/home/minio-user"

# Logging configuration
export MODULE="${MODULE:-minio-client}"
export DEBUG="${DEBUG:-false}"

# By setting an environment variable matching *_FILE to a file path, the prefixed environment
# variable will be overridden with the value specified in that file
minio_client_env_vars=(
    MINIO_CLIENT_CONF_DIR
    MINIO_SERVER_HOST
    MINIO_SERVER_PORT_NUMBER
    MINIO_SERVER_SCHEME
    MINIO_SERVER_ROOT_USER
    MINIO_SERVER_ROOT_PASSWORD
    MINIO_CLIENT_ACCESS_KEY
    MINIO_SERVER_ACCESS_KEY
    MINIO_CLIENT_SECRET_KEY
    MINIO_SERVER_SECRET_KEY
)
for env_var in "${minio_client_env_vars[@]}"; do
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
unset minio_client_env_vars

# Paths
export MINIO_CLIENT_BASE_DIR="${ROOT_DIR}/minio-client"
export MINIO_CLIENT_BIN_DIR="${MINIO_CLIENT_BASE_DIR}/bin"
export MINIO_CLIENT_CONF_DIR="${MINIO_CLIENT_CONF_DIR:-/.mc}"
export PATH="${MINIO_CLIENT_BIN_DIR}:${PATH}"

# MinIO Client configuration
export MINIO_SERVER_HOST="${MINIO_SERVER_HOST:-}"
export MINIO_SERVER_PORT_NUMBER="${MINIO_SERVER_PORT_NUMBER:-9000}"
export MINIO_SERVER_SCHEME="${MINIO_SERVER_SCHEME:-http}"

# MinIO Client security
MINIO_SERVER_ROOT_USER="${MINIO_SERVER_ROOT_USER:-"${MINIO_CLIENT_ACCESS_KEY:-}"}"
MINIO_SERVER_ROOT_USER="${MINIO_SERVER_ROOT_USER:-"${MINIO_SERVER_ACCESS_KEY:-}"}"
export MINIO_SERVER_ROOT_USER="${MINIO_SERVER_ROOT_USER:-}"
MINIO_SERVER_ROOT_PASSWORD="${MINIO_SERVER_ROOT_PASSWORD:-"${MINIO_CLIENT_SECRET_KEY:-}"}"
MINIO_SERVER_ROOT_PASSWORD="${MINIO_SERVER_ROOT_PASSWORD:-"${MINIO_SERVER_SECRET_KEY:-}"}"
export MINIO_SERVER_ROOT_PASSWORD="${MINIO_SERVER_ROOT_PASSWORD:-}"

# System users (when running with a privileged user)
export MINIO_DAEMON_USER="minio-user"
export MINIO_DAEMON_GROUP="minio-group"

# Custom environment variables may be defined below
