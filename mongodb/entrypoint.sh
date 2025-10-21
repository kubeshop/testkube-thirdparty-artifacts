#!/bin/bash
# Testkube MongoDB Entrypoint Script
# Based on Bitnami's approach for handling permissions and initialization

set -o errexit
set -o nounset
set -o pipefail

# Load environment variables
MONGODB_DATA_DIR="${MONGODB_DATA_DIR:-/data/db}"
MONGODB_DAEMON_USER="${MONGODB_DAEMON_USER:-mongodb}"
MONGODB_DAEMON_GROUP="${MONGODB_DAEMON_GROUP:-mongodb}"
MONGODB_VOLUME_DIR="${MONGODB_VOLUME_DIR:-/data}"
MONGODB_LOG_DIR="${MONGODB_LOG_DIR:-/data/logs}"
MONGODB_TMP_DIR="${MONGODB_TMP_DIR:-/data/tmp}"

# Function to ensure directory exists (without changing permissions on mounted volumes)
ensure_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi
    
    # Note: We don't change permissions here as they should be set by the Helm chart
    # via fsGroup and runAsUser/runAsGroup. Changing permissions on mounted volumes
    # will fail with "Operation not permitted" or "Read-only file system"
}

# Function to check if we're running as the correct user
check_user() {
    local current_user="$(id -u)"
    local expected_user="1001"  # mongodb user UID (matches Bitnami chart)
    
    if [[ "$current_user" != "$expected_user" ]]; then
        echo "Warning: Running as user $current_user, expected $expected_user"
    fi
}

# Main initialization function
initialize_mongodb() {
    echo "Initializing MongoDB directories and permissions..."
    
    # Ensure all required directories exist with proper permissions
    ensure_dir_exists "$MONGODB_DATA_DIR"
    ensure_dir_exists "$MONGODB_LOG_DIR"
    ensure_dir_exists "$MONGODB_TMP_DIR"
    ensure_dir_exists "$MONGODB_VOLUME_DIR"
    
    # Create journal directory if it doesn't exist
    ensure_dir_exists "$MONGODB_DATA_DIR/journal"
    
    echo "MongoDB initialization completed successfully"
}

# Print welcome message
print_welcome() {
    echo ""
    echo "=========================================="
    echo "Testkube MongoDB 8.0.15 - Custom Edition"
    echo "=========================================="
    echo "Data Directory: $MONGODB_DATA_DIR"
    echo "Log Directory: $MONGODB_LOG_DIR"
    echo "User: $(id -un) ($(id -u))"
    echo "Group: $(id -gn) ($(id -g))"
    echo "=========================================="
    echo ""
}

# Main execution
main() {
    print_welcome
    check_user
    initialize_mongodb
    
    # Add extra flags if MONGODB_EXTRA_FLAGS is set
    if [[ -n "${MONGODB_EXTRA_FLAGS:-}" ]]; then
        echo "Adding extra MongoDB flags: $MONGODB_EXTRA_FLAGS"
        set -- "$@" $MONGODB_EXTRA_FLAGS
    fi
    
    echo "Starting MongoDB with command: $*"
    exec "$@"
}

# Run main function with all arguments
main "$@"
