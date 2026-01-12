#!/bin/bash
set -e

# Generic script to check for version updates
# Usage: ./check-version.sh <service_name> [--update-files]

SERVICE_NAME="${1:-}"
UPDATE_FILES=false

if [ -z "$SERVICE_NAME" ]; then
  echo "Usage: $0 <service_name> [--update-files]"
  echo "Services: minio, mongodb, postgresql, kubectl"
  exit 1
fi

if [ "$2" = "--update-files" ]; then
  UPDATE_FILES=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
SERVICE_DIR="${REPO_ROOT}/${SERVICE_NAME}"
CONFIG_FILE="${SERVICE_DIR}/service.yaml"
CHART_YAML="${SERVICE_DIR}/helm/Chart.yaml"

# Parse service.yaml config
parse_config() {
  local key="$1"
  grep "^${key}:" "$CONFIG_FILE" | sed "s/${key}: //" | tr -d '"' | tr -d "'"
}

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found: $CONFIG_FILE"
  exit 1
fi

SOURCE=$(parse_config "source")
SOURCE_IMAGE=$(parse_config "source_image")
VERSION_PATTERN=$(parse_config "version_pattern")
DISPLAY_NAME=$(parse_config "display_name")

echo "Checking for ${DISPLAY_NAME} updates..."
echo "Source: ${SOURCE}/${SOURCE_IMAGE}"

# Get current version
get_current_version() {
  case "$SERVICE_NAME" in
    minio)
      # For MinIO, read from Dockerfile (full RELEASE version)
      local dockerfile="${SERVICE_DIR}/minio-release.dockerfile"
      if [ ! -f "$dockerfile" ]; then
        echo "Error: Dockerfile not found: $dockerfile" >&2
        return 1
      fi
      grep -E "^(ARG|ENV)\s+MINIO_SERVER_VERSION=" "$dockerfile" | head -n 1 | sed -E 's/.*=(RELEASE\.[^[:space:]]+).*/\1/' | tr -d '[:space:]'
      ;;
    *)
      # For other services, read from Chart.yaml
      if [ ! -f "$CHART_YAML" ]; then
        echo "Error: Chart.yaml not found: $CHART_YAML" >&2
        return 1
      fi
      grep "^appVersion:" "$CHART_YAML" | sed 's/appVersion: //' | tr -d '"'
      ;;
  esac
}

# Get latest version from Docker Hub
get_latest_version_dockerhub() {
  local image="$1"
  local pattern="$2"
  
  echo "Querying Docker Hub for latest version..." >&2
  
  # Handle different image formats
  if [[ "$image" == *"/"* ]]; then
    local api_url="https://hub.docker.com/v2/repositories/${image}/tags?page_size=100"
  else
    local api_url="https://hub.docker.com/v2/repositories/library/${image}/tags?page_size=100"
  fi
  
  local version=""
  
  case "$SERVICE_NAME" in
    minio)
      # MinIO uses RELEASE.YYYY-MM-DDTHH-MM-SSZ format
      version=$(curl -s "$api_url" | jq -r '.results[] | select(.name | test("^RELEASE\\.[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}Z$")) | .name' | sort -r | head -n 1)
      ;;
    mongodb)
      # MongoDB uses X.Y.Z format
      version=$(curl -s "$api_url" | jq -r '.results[] | select(.name | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name' | sort -V | tail -n 1)
      ;;
    postgresql)
      # PostgreSQL uses X.Y format (major.minor)
      version=$(curl -s "$api_url" | jq -r '.results[] | select(.name | test("^[0-9]+\\.[0-9]+$")) | .name' | sort -V | tail -n 1)
      ;;
    kubectl)
      # kubectl uses X.Y.Z format
      version=$(curl -s "$api_url" | jq -r '.results[] | select(.name | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) | .name' | sort -V | tail -n 1)
      ;;
    *)
      echo "Unknown service: $SERVICE_NAME" >&2
      return 1
      ;;
  esac
  
  if [ -z "$version" ]; then
    echo "Error: Could not get version from Docker Hub" >&2
    return 1
  fi
  
  echo "$version"
}

# Convert MinIO version to semantic
minio_to_semantic() {
  local version="$1"
  if [[ $version =~ RELEASE\.([0-9]{4})-([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  else
    echo "$version"
  fi
}

# Get semantic version for Chart.yaml
get_semantic_version() {
  local version="$1"
  case "$SERVICE_NAME" in
    minio)
      minio_to_semantic "$version"
      ;;
    *)
      echo "$version"
      ;;
  esac
}

# Compare versions
# Returns: 0 if equal, 1 if v1 > v2, 2 if v1 < v2
compare_versions() {
  local v1="$1"
  local v2="$2"
  
  if [ "$v1" = "$v2" ]; then
    echo "0"
    return
  fi
  
  case "$SERVICE_NAME" in
    minio)
      # Compare MinIO RELEASE dates
      local d1=$(echo "$v1" | sed 's/RELEASE\.//' | tr 'T' ' ' | sed 's/Z$//')
      local d2=$(echo "$v2" | sed 's/RELEASE\.//' | tr 'T' ' ' | sed 's/Z$//')
      if [[ "$d1" > "$d2" ]]; then
        echo "1"
      else
        echo "2"
      fi
      ;;
    *)
      # Compare semantic versions
      if [ "$(printf '%s\n' "$v1" "$v2" | sort -V | tail -n 1)" = "$v1" ]; then
        echo "1"
      else
        echo "2"
      fi
      ;;
  esac
}

# Update Chart.yaml
update_chart_yaml() {
  local new_version="$1"
  local semantic_version=$(get_semantic_version "$new_version")
  
  echo "Updating Chart.yaml to version: $semantic_version"
  
  # Update appVersion
  sed -i.bak "s|^appVersion:.*|appVersion: \"${semantic_version}\"|" "$CHART_YAML"
  
  # Update version (chart version)
  local current_chart_version=$(grep "^version:" "$CHART_YAML" | sed 's/version: //' | tr -d '"')
  local new_chart_version="${semantic_version}-0"
  sed -i.bak "s|^version:.*|version: ${new_chart_version}|" "$CHART_YAML"
  
  rm -f "${CHART_YAML}.bak"
  echo "Chart.yaml updated"
}

# Update Dockerfile if exists
update_dockerfile() {
  local new_version="$1"
  local dockerfile="${SERVICE_DIR}/$(parse_config 'dockerfile')"
  
  if [ ! -f "$dockerfile" ]; then
    echo "Dockerfile not found, skipping: $dockerfile"
    return 0
  fi
  
  echo "Updating Dockerfile..."
  
  case "$SERVICE_NAME" in
    minio)
      sed -i.bak "s|^ARG MINIO_SERVER_VERSION=.*|ARG MINIO_SERVER_VERSION=${new_version}|" "$dockerfile"
      sed -i.bak "s|^ENV MINIO_SERVER_VERSION=.*|ENV MINIO_SERVER_VERSION=${new_version}|" "$dockerfile"
      ;;
    mongodb)
      # Update FROM mongo:X.Y.Z line directly (ARG before FROM has issues with some build drivers)
      sed -i.bak "s|^FROM mongo:.*|FROM mongo:${new_version}|" "$dockerfile"
      ;;
    postgresql)
      # Update FROM postgres:X.Y line directly (ARG before FROM has issues with some build drivers)
      sed -i.bak "s|^FROM postgres:.*|FROM postgres:${new_version}|" "$dockerfile"
      ;;
    kubectl)
      # Update FROM alpine/kubectl:X.Y.Z line directly (ARG before FROM has issues with some build drivers)
      sed -i.bak "s|^FROM alpine/kubectl:.*|FROM alpine/kubectl:${new_version}|" "$dockerfile"
      ;;
  esac
  
  rm -f "${dockerfile}.bak"
  echo "Dockerfile updated"
}

# Main logic
main() {
  local current_version=$(get_current_version) || exit 1
  local latest_version=$(get_latest_version_dockerhub "$SOURCE_IMAGE" "$VERSION_PATTERN") || exit 1
  
  echo "Current version: $current_version"
  echo "Latest version: $latest_version"
  
  local current_semantic=$(get_semantic_version "$current_version")
  local latest_semantic=$(get_semantic_version "$latest_version")
  
  # For comparison, use the full version for MinIO, semantic for others
  local compare_current="$current_version"
  local compare_latest="$latest_version"
  
  if [ "$SERVICE_NAME" != "minio" ]; then
    compare_current="$current_semantic"
    compare_latest="$latest_semantic"
  fi
  
  local comparison=$(compare_versions "$compare_latest" "$compare_current")
  
  if [ "$comparison" = "1" ]; then
    echo ""
    echo "New version available!"
    echo "Update from: $current_version ($current_semantic)"
    echo "Update to: $latest_version ($latest_semantic)"
    
    if [ "$UPDATE_FILES" = true ]; then
      echo ""
      update_chart_yaml "$latest_version"
      update_dockerfile "$latest_version"
      echo ""
      echo "All files updated"
    fi
    
    # Exit 0 = update available
    exit 0
  else
    echo ""
    echo "Already up to date"
    # Exit 1 = no update
    exit 1
  fi
}

main

