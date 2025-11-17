#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
#set -o xtrace

# Load libraries
. /home/minio-user/scripts/lib/utils.sh

if [[ "$*" = *"/home/minio-user/scripts/run.sh"* ]]; then
    info "** Starting MinIO setup **"
    /home/minio-user/scripts/setup.sh
    info "** MinIO setup finished! **"
fi

echo ""
exec "$@"
