#!/bin/bash
set -e

# Generic script to generate PR descriptions using OpenAI
# Usage: ./generate-pr-description.sh --service <name> --current-version <ver> --new-version <ver> --output <file>

SERVICE_NAME=""
CURRENT_VERSION=""
NEW_VERSION=""
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/pr-description.md}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --service) SERVICE_NAME="$2"; shift 2 ;;
    --current-version) CURRENT_VERSION="$2"; shift 2 ;;
    --new-version) NEW_VERSION="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --service <name> --current-version <ver> --new-version <ver> --output <file>"
      echo ""
      echo "Options:"
      echo "  --service          Service name (minio, mongodb, postgresql, kubectl)"
      echo "  --current-version  Current version"
      echo "  --new-version      New version"
      echo "  --output           Output file path"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$SERVICE_NAME" ] || [ -z "$CURRENT_VERSION" ] || [ -z "$NEW_VERSION" ]; then
  echo "Error: Missing required arguments"
  echo "Usage: $0 --service <name> --current-version <ver> --new-version <ver> --output <file>"
  exit 1
fi

if [ -z "$OPENAI_API_KEY" ]; then
  echo "Warning: OPENAI_API_KEY not set, will generate basic description"
fi

# Service-specific configuration
get_service_config() {
  case "$SERVICE_NAME" in
    minio)
      GITHUB_REPO="minio/minio"
      DOCKER_IMAGE="minio/minio"
      DISPLAY_NAME="MinIO"
      DOCS_URL="https://min.io/docs/minio/linux/index.html"
      # MinIO uses RELEASE.YYYY-MM-DD format, convert to semantic
      SEMANTIC_VERSION=$(echo "$NEW_VERSION" | sed -E 's/RELEASE\.([0-9]{4})-([0-9]{2}).*/\1.\2/')
      VERSION_VAR="MINIO_SERVER_VERSION"
      ;;
    mongodb)
      GITHUB_REPO="mongodb/mongo"
      DOCKER_IMAGE="mongo"
      DISPLAY_NAME="MongoDB"
      DOCS_URL="https://www.mongodb.com/docs/manual/release-notes/"
      SEMANTIC_VERSION="$NEW_VERSION"
      VERSION_VAR="MONGODB_VERSION"
      ;;
    postgresql)
      GITHUB_REPO="postgres/postgres"
      DOCKER_IMAGE="postgres"
      DISPLAY_NAME="PostgreSQL"
      DOCS_URL="https://www.postgresql.org/docs/release/"
      SEMANTIC_VERSION="$NEW_VERSION"
      VERSION_VAR="POSTGRESQL_VERSION"
      ;;
    kubectl)
      GITHUB_REPO="kubernetes/kubectl"
      DOCKER_IMAGE="bitnami/kubectl"
      DISPLAY_NAME="kubectl"
      DOCS_URL="https://kubernetes.io/docs/reference/kubectl/"
      SEMANTIC_VERSION="$NEW_VERSION"
      VERSION_VAR="KUBECTL_VERSION"
      ;;
    *)
      echo "Error: Unknown service: $SERVICE_NAME"
      exit 1
      ;;
  esac
}

# Fetch release info from GitHub API
get_release_info() {
  local repo="$1"
  local tag="$2"
  
  # Try different tag formats
  for tag_format in "$tag" "v$tag" "release-$tag"; do
    local result=$(curl -s "https://api.github.com/repos/${repo}/releases/tags/${tag_format}" 2>/dev/null)
    if echo "$result" | jq -e '.tag_name' > /dev/null 2>&1; then
      echo "$result"
      return 0
    fi
  done
  
  echo '{}'
}

# Fetch changelog between versions
get_changelog() {
  local repo="$1"
  curl -s "https://api.github.com/repos/${repo}/releases?per_page=10" 2>/dev/null | \
    jq '[.[] | {tag_name, name, published_at, body}]' 2>/dev/null || echo '[]'
}

# Generate description with OpenAI
generate_ai_description() {
  local prompt="$1"
  
  if [ -z "$OPENAI_API_KEY" ]; then
    echo ""
    return
  fi
  
  curl -s https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d @- <<EOF | jq -r '.choices[0].message.content // ""'
{
  "model": "gpt-4-turbo-preview",
  "messages": [
    {"role": "system", "content": "You are a DevOps expert specialized in technical documentation. Be concise and focus on important changes."},
    {"role": "user", "content": $(echo "$prompt" | jq -Rs .)}
  ],
  "temperature": 0.7,
  "max_tokens": 2000
}
EOF
}

# Main
get_service_config

echo "Generating PR description for ${DISPLAY_NAME}..."
echo "Current version: ${CURRENT_VERSION}"
echo "New version: ${NEW_VERSION}"

# Gather release information
RELEASE_INFO=$(get_release_info "$GITHUB_REPO" "$NEW_VERSION")
CHANGELOG=$(get_changelog "$GITHUB_REPO")
RELEASE_BODY=$(echo "$RELEASE_INFO" | jq -r '.body // "No release notes available"')

# Build prompt for OpenAI
PROMPT="You are a DevOps expert. Generate a professional description for a PR that updates ${DISPLAY_NAME} from ${CURRENT_VERSION} to ${NEW_VERSION} in Testkube.

Release notes:
${RELEASE_BODY}

Recent releases:
${CHANGELOG}

Structure your response with these sections:
### Executive Summary
(2-3 lines describing the main change)

### 🔒 Security Updates
(CVEs or security improvements, or 'No security updates in this release' if none)

### ✨ New Features
(Relevant features, or 'No new features in this release' if none)

### 🐛 Bug Fixes
(Important bugs, or 'No notable bug fixes' if none)

### ⚡ Performance Improvements
(If applicable, or skip this section)

### ⚠️ Important Notes
(Breaking changes or considerations, or 'No breaking changes' if none)

Be concise. Maximum 500 words total."

# Generate AI description
AI_RESPONSE=$(generate_ai_description "$PROMPT")

# Fallback if OpenAI fails or is not configured
if [ -z "$AI_RESPONSE" ]; then
  AI_RESPONSE="### Executive Summary

Update ${DISPLAY_NAME} from \`${CURRENT_VERSION}\` to \`${NEW_VERSION}\`.

### 📋 Details

This is an automated update. Please review the official release notes for detailed information about changes in this version.

### ⚠️ Important Notes

- Review the official release notes before merging
- Ensure all tests pass"
fi

# Determine dockerfile name
case "$SERVICE_NAME" in
  minio) DOCKERFILE="${SERVICE_NAME}-release.dockerfile" ;;
  mongodb) DOCKERFILE="mongo-8.dockerfile" ;;
  postgresql) DOCKERFILE="postgresql-release.dockerfile" ;;
  kubectl) DOCKERFILE="kubectl-release.dockerfile" ;;
esac

# Build final PR description
cat > "$OUTPUT_FILE" <<EOF
## 🚀 ${DISPLAY_NAME} Automatic Update

> 📦 **Version:** \`${CURRENT_VERSION}\` → \`${NEW_VERSION}\`  
> 🤖 **Generated:** $(date -u +"%Y-%m-%d %H:%M UTC")

---

${AI_RESPONSE}

---

## 📦 Changes in this PR

| File | Change |
|------|--------|
| \`${DOCKERFILE}\` | \`${VERSION_VAR}=${NEW_VERSION}\` |
| \`helm/Chart.yaml\` | \`appVersion: "${SEMANTIC_VERSION}"\` |

## 📊 Versions

| Component | Previous | New |
|-----------|----------|-----|
| ${DISPLAY_NAME} | \`${CURRENT_VERSION}\` | \`${NEW_VERSION}\` |
| Helm Chart | Auto | \`${SEMANTIC_VERSION}-X\` |

## 🔗 References

- [GitHub Releases](https://github.com/${GITHUB_REPO}/releases)
- [Docker Hub](https://hub.docker.com/r/${DOCKER_IMAGE}/tags)
- [Documentation](${DOCS_URL})

## ✅ Testing

- [x] 🔍 Version check passed
- [ ] 🏗️ Docker image build
- [ ] 🧪 Regression tests

## 🚦 Next Steps

1. Review changes
2. Approve if everything is correct
3. Merge to \`main\` to publish

---

**🤖 Generated with OpenAI GPT-4** | [Workflow](.github/workflows/thirdparty-updates.yaml)
EOF

echo "PR description generated: $OUTPUT_FILE"

