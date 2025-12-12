#!/bin/bash
set -e

# Script to check and update MinIO version from Docker Hub
# Usage: ./check-and-update-minio.sh [--dry-run] [--update-files]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINIO_DIR="${SCRIPT_DIR}/.."
DOCKERFILE="${MINIO_DIR}/minio-release.dockerfile"
CHART_YAML="${MINIO_DIR}/helm/Chart.yaml"
VALUES_YAML="${MINIO_DIR}/helm/values.yaml"

DOCKER_HUB_API="https://hub.docker.com/v2/repositories/minio/minio/tags"
DRY_RUN=false
UPDATE_FILES=false

# Get current version from Dockerfile
get_current_version() {
  local format="${1:-full}"
  local version=$(grep -E "^(ARG|ENV)\s+MINIO_SERVER_VERSION=" "$DOCKERFILE" | head -n 1 | sed -E 's/.*=(RELEASE\.[^[:space:]]+).*/\1/' | tr -d '[:space:]')
  
  if [ -z "$version" ]; then
    echo "Error: MINIO_SERVER_VERSION not found in Dockerfile" >&2
    return 1
  fi
  
  if [ "$format" = "semantic" ] && [[ $version =~ RELEASE\.([0-9]{4})-([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  else
    echo "$version"
  fi
}

# Get latest version from Docker Hub
get_latest_version() {
  local format="${1:-full}"
  echo "Querying Docker Hub for latest MinIO version..." >&2
  
  local version=$(curl -s "${DOCKER_HUB_API}?page_size=100&page=1" \
    | jq -r '.results[] | select(.name | startswith("RELEASE.")) | select(.name | test("^RELEASE\\.[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}Z$")) | .name' \
    | sort -r | head -n 1)
  
  if [ -z "$version" ]; then
    echo "Error: Could not get MinIO version from Docker Hub" >&2
    return 1
  fi
  
  if [ "$format" = "semantic" ] && [[ $version =~ RELEASE\.([0-9]{4})-([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  else
    echo "$version"
  fi
}

# Compare two MinIO tags
# Returns: -1 if tag2 > tag1, 0 if equal, 1 if tag1 > tag2
compare_tags() {
  local date1=$(echo "$1" | sed 's/RELEASE\.//' | tr 'T' ' ' | sed 's/Z$//')
  local date2=$(echo "$2" | sed 's/RELEASE\.//' | tr 'T' ' ' | sed 's/Z$//')
  
  if [ "$(printf "%s\n%s\n" "$date1" "$date2" | sort -V | head -n 1)" = "$date2" ]; then
    [ "$date1" = "$date2" ] && echo "0" || echo "-1"
  else
    echo "1"
  fi
}

# Update Dockerfile
update_dockerfile() {
  local new_version="$1"
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would update Dockerfile: MINIO_SERVER_VERSION=$new_version"
    return 0
  fi
  
  sed -i.bak "s/^ARG MINIO_SERVER_VERSION=.*/ARG MINIO_SERVER_VERSION=${new_version}/" "$DOCKERFILE"
  sed -i.bak "s/^ENV MINIO_SERVER_VERSION=.*/ENV MINIO_SERVER_VERSION=${new_version}/" "$DOCKERFILE"
  
  local semantic_version=$(get_latest_version semantic)
  sed -i.bak "s/^LABEL.*version=\".*\"/LABEL maintainer=\"Testkube Team\" \\\\
      version=\"${semantic_version}\" \\\\
      description=\"Minio Server - Testkube Edition\"/" "$DOCKERFILE"
  
  rm -f "${DOCKERFILE}.bak"
  echo "Dockerfile updated"
}

# Update Chart.yaml
update_chart_yaml() {
  local new_semantic_version="$1"
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would update Chart.yaml: appVersion=$new_semantic_version"
    return 0
  fi
  
  sed -i.bak "s/^appVersion:.*/appVersion: \"${new_semantic_version}\"/" "$CHART_YAML"
  
  local current_chart_version=$(grep "^version:" "$CHART_YAML" | sed 's/^version: //' | tr -d '"')
  local current_base_version=$(echo "$current_chart_version" | cut -d'-' -f1)
  
  if [ "$current_base_version" != "$new_semantic_version" ]; then
    sed -i.bak "s/^version:.*/version: ${new_semantic_version}-0/" "$CHART_YAML"
    echo "Version base changed, iterator reset to 0"
  fi
  
  sed -i.bak "s|image: us-east1-docker.pkg.dev/testkube-cloud-372110/testkube/minio:[0-9.]*|image: us-east1-docker.pkg.dev/testkube-cloud-372110/testkube/minio:${new_semantic_version}|" "$CHART_YAML"
  
  rm -f "${CHART_YAML}.bak"
  echo "Chart.yaml updated"
}

# Update values.yaml
update_values_yaml() {
  local new_semantic_version="$1"
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would update values.yaml: image.tag=$new_semantic_version"
    return 0
  fi
  
  sed -i.bak '/^image:/,/^[a-zA-Z]/s/^  tag:.*/  tag: "'"${new_semantic_version}"'"/' "$VALUES_YAML"
  sed -i.bak '/^clientImage:/,/^[a-zA-Z]/s/^  tag:.*/  tag: "'"${new_semantic_version}"'"/' "$VALUES_YAML"
  sed -i.bak '/^  volumePermissions:/,/^  [a-zA-Z]/s/^    tag:.*/    tag: "'"${new_semantic_version}"'"/' "$VALUES_YAML" || true
  
  rm -f "${VALUES_YAML}.bak"
  echo "values.yaml updated"
}

# Update all files
update_all_files() {
  local new_version="$1"
  local new_semantic_version=$(echo "$new_version" | sed -E 's/RELEASE\.([0-9]{4})-([0-9]{2}).*/\1.\2/')
  
  echo "Updating files to version: $new_version ($new_semantic_version)"
  
  update_dockerfile "$new_version"
  update_chart_yaml "$new_semantic_version"
  update_values_yaml "$new_semantic_version"
  
  echo "All files updated"
}

# Main
main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run) DRY_RUN=true; shift ;;
      --update-files) UPDATE_FILES=true; shift ;;
      -h|--help)
        echo "Usage: $0 [--dry-run] [--update-files]"
        echo ""
        echo "Options:"
        echo "  --dry-run      Show what would be done without making changes"
        echo "  --update-files Update files with new version"
        echo "  -h, --help     Show this help"
        exit 0
        ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  
  echo "Checking for MinIO updates..."
  
  current_version=$(get_current_version full) || exit 1
  latest_version=$(get_latest_version full) || exit 1
  
  echo "Current version: $current_version"
  echo "Latest version: $latest_version"
  
  comparison=$(compare_tags "$current_version" "$latest_version")
  
  if [ "$comparison" = "-1" ]; then
    current_semantic=$(get_current_version semantic)
    latest_semantic=$(get_latest_version semantic)
    
    echo "New version available!"
    echo "Update from: $current_version ($current_semantic)"
    echo "Update to: $latest_version ($latest_semantic)"
    
    if [ "$UPDATE_FILES" = true ]; then
      update_all_files "$latest_version"
      echo "Update completed. Please review changes and commit."
      exit 0
    elif [ "$DRY_RUN" = false ]; then
      echo "Use --update-files to update files automatically"
      exit 0
    else
      echo "[DRY RUN] Files would be updated to new version"
      update_all_files "$latest_version"
      exit 0
    fi
  elif [ "$comparison" = "0" ]; then
    echo "Already up to date"
    exit 1
  else
    echo "Warning: Current version is newer than official release"
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
