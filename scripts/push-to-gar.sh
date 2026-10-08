#!/usr/bin/env bash
# Copy an image already published on Docker Hub to Google Artifact Registry.
#
# The copy is digest-preserving (no rebuild), so GAR and Docker Hub serve the
# exact same multi-arch image. Source and destination come from the
# `dockerhub_image` and `gar_image` keys of <service>/service.yaml.
#
# An existing GAR tag is never overwritten: retagging would leave the previous
# digest untagged, and the repository's delete-untagged cleanup policy would
# remove it.
#
# Usage: ./scripts/push-to-gar.sh <service> <version>
# Requires being logged in to both registries (docker login).

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

SOURCE_REF="${SOURCE_IMAGE}:${VERSION}"
GAR_REF="${GAR_IMAGE}:${VERSION}"

# Prints the manifest digest of a reference, or nothing if the tag does not
# exist. Any other registry error aborts the script.
get_digest() {
  local ref="$1" output
  if output="$(docker buildx imagetools inspect "$ref" --format '{{json .Manifest.Digest}}' 2>&1)"; then
    echo "$output" | tail -n 1 | tr -d '"'
    return 0
  fi
  if echo "$output" | grep -q "${ref}: not found"; then
    return 0
  fi
  echo "Error: failed to inspect ${ref}:" >&2
  echo "$output" >&2
  return 1
}

SOURCE_DIGEST="$(get_digest "$SOURCE_REF")"
if [ -z "$SOURCE_DIGEST" ]; then
  echo "Error: ${SOURCE_REF} does not exist"
  exit 1
fi

GAR_DIGEST="$(get_digest "$GAR_REF")"
if [ "$GAR_DIGEST" = "$SOURCE_DIGEST" ]; then
  echo "${GAR_REF} is already in sync (${SOURCE_DIGEST})"
  exit 0
fi
if [ -n "$GAR_DIGEST" ]; then
  echo "Error: ${GAR_REF} already exists with a different digest"
  echo "  Docker Hub: ${SOURCE_DIGEST}"
  echo "  GAR:        ${GAR_DIGEST}"
  echo "Refusing to overwrite it."
  exit 1
fi

echo "Copying ${SOURCE_REF} -> ${GAR_REF}"
docker buildx imagetools create --tag "$GAR_REF" "$SOURCE_REF"

PUSHED_DIGEST="$(get_digest "$GAR_REF")"
if [ "$PUSHED_DIGEST" != "$SOURCE_DIGEST" ]; then
  echo "Error: digest mismatch after copy (expected ${SOURCE_DIGEST}, got ${PUSHED_DIGEST:-none})"
  exit 1
fi

echo "Pushed ${GAR_REF} (${SOURCE_DIGEST})"
