#!/usr/bin/env bash
# Auto-bump patch version in version.json and package.json for each checkin

VERSION_FILE="web_control_center/version.json"
PKG_FILE="web_control_center/package.json"

if [ ! -f "$VERSION_FILE" ]; then
  echo "Error: $VERSION_FILE not found"
  exit 1
fi

CURRENT_VER=$(node -e "console.log(require('./$VERSION_FILE').version)")
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "main")
BUILD_DATE=$(date -u +"%Y.%m.%d.%H%M")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Parse major, minor, patch
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VER"
NEW_PATCH=$((PATCH + 1))
NEW_VER="${MAJOR}.${MINOR}.${NEW_PATCH}"

echo "Bumping version: v${CURRENT_VER} -> v${NEW_VER} (Commit: ${COMMIT_HASH})"

# Update version.json
node -e "
const fs = require('fs');
const vPath = '$VERSION_FILE';
const data = JSON.parse(fs.readFileSync(vPath, 'utf-8'));
data.version = '$NEW_VER';
data.buildNumber = '$BUILD_DATE';
data.gitCommit = '$COMMIT_HASH';
data.timestamp = '$TIMESTAMP';
fs.writeFileSync(vPath, JSON.stringify(data, null, 2) + '\n');
"

# Update package.json
node -e "
const fs = require('fs');
const pPath = '$PKG_FILE';
const data = JSON.parse(fs.readFileSync(pPath, 'utf-8'));
data.version = '$NEW_VER';
fs.writeFileSync(pPath, JSON.stringify(data, null, 2) + '\n');
"

echo "✅ Version successfully bumped to v${NEW_VER}!"
