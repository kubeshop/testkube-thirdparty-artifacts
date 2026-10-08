#!/usr/bin/env bash
# Sign a released image in Docker Hub and GAR.
#
# Both registries serve the same digest (see push-to-gar.sh), which is
# resolved from Docker Hub and must already exist in GAR. Image names come from
# the `dockerhub_image` and `gar_image` keys of <service>/service.yaml.
#
# Usage: ./scripts/sign-image.sh <service> <version>

set -euo pipefail

SERVICE_NAME="${1:-}"
VERSION="${2:-}"

if [ -z "$SERVICE_NAME" ] || [ -z "$VERSION" ]; then
  echo "Usage: $0 <service> <version>"
  exit 1
fi

if ! [[ "$VERSION" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "Error: invalid version '${VERSION}'"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../${SERVICE_NAME}/service.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found: $CONFIG_FILE"
  exit 1
fi

parse_config() {
  local key="$1"
  grep "^${key}:" "$CONFIG_FILE" | sed "s/${key}: //" | tr -d '"' | tr -d "'" | tr -d '[:space:]'
}

SOURCE_IMAGE="$(parse_config "dockerhub_image")"
GAR_IMAGE="$(parse_config "gar_image")"

if [ -z "$SOURCE_IMAGE" ] || [ -z "$GAR_IMAGE" ]; then
  echo "Error: ${CONFIG_FILE} must define dockerhub_image and gar_image"
  exit 1
fi

get_digest() {
  docker buildx imagetools inspect "$1" --format '{{json .Manifest.Digest}}' | tail -n 1 | tr -d '"'
}

DIGEST="$(get_digest "${SOURCE_IMAGE}:${VERSION}")"
GAR_DIGEST="$(get_digest "${GAR_IMAGE}:${VERSION}")"

if [ "$DIGEST" != "$GAR_DIGEST" ]; then
  echo "Error: ${GAR_IMAGE}:${VERSION} (${GAR_DIGEST}) does not match Docker Hub (${DIGEST})"
  exit 1
fi

"${SCRIPT_DIR}/cosign-sign.sh" "$SOURCE_IMAGE" "$DIGEST"
"${SCRIPT_DIR}/cosign-sign.sh" "$GAR_IMAGE" "$DIGEST"
