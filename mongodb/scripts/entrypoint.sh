#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /home/mongo-user/scripts/lib/utils.sh

# Load environment
. /home/mongo-user/scripts/lib/mongodb-env.sh

debug "Copying files from $MONGODB_DEFAULT_CONF_DIR to $MONGODB_CONF_DIR"
# --update=none mimics -n so we avoid the non-portable flag warning from BusyBox cp
cp -r --update=none "$MONGODB_DEFAULT_CONF_DIR"/. "$MONGODB_CONF_DIR"

if [[ "$1" = "/home/mongo-user/scripts/mongodb/run.sh" ]]; then
    info "** Starting MongoDB setup **"
    /home/mongo-user/scripts/setup.sh
    info "** MongoDB setup finished! **"
fi

echo ""
exec "$@"
