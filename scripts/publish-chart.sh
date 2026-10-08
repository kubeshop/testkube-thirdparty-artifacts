#!/usr/bin/env bash
# Package, push and sign a Helm chart in an OCI registry.
#
# A chart version that is already published is not pushed again: helm stamps
# the push time into the OCI manifest, so every re-push moves the tag to a new
# digest and GAR's delete-untagged policy removes the previous one (and orphans
# its signature). The published digest is signed either way.
#
# Usage: ./scripts/publish-chart.sh <chart-dir> <oci-repository>
# Example: ./scripts/publish-chart.sh nats/helm oci://us-east1-docker.pkg.dev/my-project/testkube
# Requires helm, cosign, docker buildx and being logged in to the registry.

set -euo pipefail

CHART_DIR="${1:-}"
OCI_REPOSITORY="${2:-}"

if [ -z "$CHART_DIR" ] || [ -z "$OCI_REPOSITORY" ]; then
  echo "Usage: $0 <chart-dir> <oci-repository>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CHART_META="$(helm show chart "$CHART_DIR")"
CHART_NAME="$(echo "$CHART_META" | awk '/^name:/ {print $2}')"
CHART_VERSION="$(echo "$CHART_META" | awk '/^version:/ {print $2}')"
REPOSITORY="${OCI_REPOSITORY#oci://}/${CHART_NAME}"
CHART_REF="${REPOSITORY}:${CHART_VERSION}"

if output="$(docker buildx imagetools inspect "$CHART_REF" --format '{{json .Manifest.Digest}}' 2>&1)"; then
  DIGEST="$(echo "$output" | tail -n 1 | tr -d '"')"
  echo "${CHART_REF} is already published (${DIGEST}), not pushing it again"
elif echo "$output" | grep -q "${CHART_REF}: not found"; then
  PACKAGE_DIR="$(mktemp -d)"
  helm package "$CHART_DIR" -d "$PACKAGE_DIR"
  PUSH_OUTPUT="$(helm push "${PACKAGE_DIR}/${CHART_NAME}-${CHART_VERSION}.tgz" "$OCI_REPOSITORY" 2>&1)"
  echo "$PUSH_OUTPUT"
  DIGEST="$(echo "$PUSH_OUTPUT" | awk '/^Digest:/ {print $2}')"
  rm -rf "$PACKAGE_DIR"
else
  echo "Error: failed to inspect ${CHART_REF}:"
  echo "$output"
  exit 1
fi

"${SCRIPT_DIR}/cosign-sign.sh" "$REPOSITORY" "$DIGEST"
