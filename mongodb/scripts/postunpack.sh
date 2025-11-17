#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail

# Load libraries
. /opt/bitnami/scripts/lib/utils.sh

# Load environment
. /opt/bitnami/scripts/lib/mongodb-env.sh

for dir in "$MONGODB_TMP_DIR" "$MONGODB_LOG_DIR" "$MONGODB_CONF_DIR" "$MONGODB_DEFAULT_CONF_DIR" "$MONGODB_DATA_DIR" "$MONGODB_VOLUME_DIR" "$MONGODB_INITSCRIPTS_DIR"; do
    ensure_dir_exists "$dir"
done
chmod -R g+rwX "$MONGODB_TMP_DIR" "$MONGODB_LOG_DIR" "$MONGODB_CONF_DIR" "$MONGODB_DATA_DIR" "$MONGODB_VOLUME_DIR" "$MONGODB_INITSCRIPTS_DIR"

render-template "$MONGODB_MONGOD_TEMPLATES_FILE" > "$MONGODB_CONF_FILE"

# Create .dbshell file to avoid error message
touch "$MONGODB_DB_SHELL_FILE" && chmod g+rw "$MONGODB_DB_SHELL_FILE"
# Create .mongorc.js file to avoid error message
touch "$MONGODB_RC_FILE" && chmod g+rw "$MONGODB_RC_FILE"
# Create .mongoshrc.js file to avoid error message
touch "$MONGOSH_RC_FILE" && chmod g+rw "$MONGOSH_RC_FILE"
# Create .mongodb folder to avoid error message
mkdir "$MONGOSH_DIR" && chmod g+rwX "$MONGOSH_DIR"

chmod 660 "$MONGODB_CONF_FILE"

# Redirect all logging to stdout
ln -sf /dev/stdout "$MONGODB_LOG_FILE"

# Copy all initially generated configuration files to the default directory
# (this is to avoid breaking when entrypoint is being overridden)
cp -r "${MONGODB_CONF_DIR}/"* "$MONGODB_DEFAULT_CONF_DIR"
chmod o+r -R "$MONGODB_DEFAULT_CONF_DIR"
