#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
#set -o xtrace

# Load libraries
. /opt/bitnami/scripts/lib/utils.sh

if [[ "$*" = *"/opt/bitnami/scripts/run.sh"* ]]; then
    info "** Starting MinIO setup **"
    /opt/bitnami/scripts/setup.sh
    info "** MinIO setup finished! **"
fi

echo ""
exec "$@"
