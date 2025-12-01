#!/bin/bash
set -e

# Test script for local PR description generation
# Usage: ./test-pr-generation.sh [current_version] [new_version]

if [ -z "$OPENAI_API_KEY" ]; then
  echo "Error: OPENAI_API_KEY not set"
  echo "Set it with: export OPENAI_API_KEY='sk-...'"
  exit 1
fi

CURRENT="${1:-RELEASE.2024-10-02T17-50-41Z}"
NEW="${2:-RELEASE.2024-11-07T00-52-20Z}"
OUTPUT="./test-pr-description.md"

echo "Testing PR generation..."
echo "  Current: $CURRENT"
echo "  New: $NEW"
echo ""

./generate-pr-description.sh \
  --current-version "$CURRENT" \
  --new-version "$NEW" \
  --output "$OUTPUT"

echo ""
echo "Done! Check: $OUTPUT"
echo ""
echo "View with: cat $OUTPUT"

