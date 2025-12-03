#!/bin/bash
set -e

# Parse command line arguments
CURRENT_VERSION=""
NEW_VERSION=""
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/pr-description.md}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --current-version) CURRENT_VERSION="$2"; shift 2 ;;
    --new-version) NEW_VERSION="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$CURRENT_VERSION" ] || [ -z "$NEW_VERSION" ] || [ -z "$OPENAI_API_KEY" ]; then
  echo "Error: Missing required arguments or OPENAI_API_KEY"
  exit 1
fi

SEMANTIC_VERSION=$(echo "$NEW_VERSION" | sed -E 's/RELEASE\.([0-9]{4})-([0-9]{2}).*/\1.\2/')

# Fetch release info from GitHub API
get_release_info() {
  curl -s "https://api.github.com/repos/minio/minio/releases/tags/$1" 2>/dev/null || echo '{}'
}

# Fetch changelog between versions
get_changelog() {
  curl -s "https://api.github.com/repos/minio/minio/releases?per_page=20" 2>/dev/null | \
    jq --arg from "$1" --arg to "$2" '[.[] | select(.tag_name >= $from and .tag_name <= $to)]' 2>/dev/null || echo '[]'
}

# Gather release information
RELEASE_INFO=$(get_release_info "$NEW_VERSION")
CHANGELOG=$(get_changelog "$CURRENT_VERSION" "$NEW_VERSION")
RELEASE_BODY=$(echo "$RELEASE_INFO" | jq -r '.body // "No release notes"')

# Generate PR description using OpenAI
PROMPT="You are a DevOps expert. Generate a professional description for a PR that updates MinIO from $CURRENT_VERSION to $NEW_VERSION in Testkube.

Release notes:
$RELEASE_BODY

Changelog:
$CHANGELOG

Structure:
### Executive Summary
(2-3 lines describing the main change)

### 🔒 Security Updates
(CVEs or security improvements)

### ✨ New Features
(Relevant features)

### 🐛 Bug Fixes
(Important bugs)

### ⚡ Performance Improvements
(If applicable)

### ⚠️ Important Notes
(Breaking changes or considerations)

Only generate the content of these sections, maximum 600 words."

AI_RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d @- <<EOF | jq -r '.choices[0].message.content // ""'
{
  "model": "gpt-4-turbo-preview",
  "messages": [
    {"role": "system", "content": "You are a DevOps expert specialized in technical documentation."},
    {"role": "user", "content": $(echo "$PROMPT" | jq -Rs .)}
  ],
  "temperature": 0.7,
  "max_tokens": 2000
}
EOF
)

# Fallback if OpenAI fails
if [ -z "$AI_RESPONSE" ]; then
  AI_RESPONSE="### Executive Summary

MinIO update from $CURRENT_VERSION to $NEW_VERSION.

⚠️ Could not generate AI description. Please check MinIO release notes for details."
fi

# Build final PR description
cat > "$OUTPUT_FILE" <<EOF
## 🚀 MinIO Automatic Update

> 📦 **Version:** \`${CURRENT_VERSION}\` → \`${NEW_VERSION}\`  
> 🤖 **Generated:** $(date -u +"%Y-%m-%d %H:%M UTC")

---

${AI_RESPONSE}

---

## 📦 Changes in this PR

| File | Change |
|------|--------|
| \`minio-release.dockerfile\` | \`MINIO_SERVER_VERSION=${NEW_VERSION}\` |
| \`helm/Chart.yaml\` | \`appVersion: "${SEMANTIC_VERSION}"\` |
| \`helm/values.yaml\` | \`image.tag: "${SEMANTIC_VERSION}"\` |

## 📊 Versions

| Component | Previous | New |
|-----------|----------|-----|
| MinIO Server | \`${CURRENT_VERSION}\` | \`${NEW_VERSION}\` |
| Helm Chart | Auto | \`${SEMANTIC_VERSION}-X\` |

## 🔗 References

- [Release Notes](https://github.com/minio/minio/releases/tag/${NEW_VERSION})
- [Docker Hub](https://hub.docker.com/r/minio/minio/tags?name=${NEW_VERSION})
- [MinIO Docs](https://min.io/docs/minio/linux/index.html)

## ✅ Testing

- [ ] 🏗️ Docker image build
- [ ] 🔍 Helm charts lint
- [ ] 🧪 Regression tests (coming soon)

## 🚦 Next Steps

1. Review changes
2. Approve if everything is correct
3. Merge to \`main\` to publish

<details>
<summary>Full changelog</summary>

\`\`\`json
${CHANGELOG}
\`\`\`

</details>

---

**🤖 Generated with OpenAI GPT-4** | [Workflow](.github/workflows/check-minio-updates.yaml)
EOF

echo "PR description generated: $OUTPUT_FILE"
