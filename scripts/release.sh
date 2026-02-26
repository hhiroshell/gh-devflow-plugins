#!/bin/bash
#
# Automate the release flow for gh-devflow-plugins
#
# Usage: release.sh <version>
#
# Arguments:
#   version   The version to release in X.Y.Z format (e.g., 0.5.0)
#
# This script:
#   1. Validates the version format and prerequisites
#   2. Updates version in both manifest files
#   3. Commits the version bump
#   4. Creates and pushes the tag
#
# The GitHub Actions workflow then validates version consistency
# and creates a GitHub Release with auto-generated notes.
#

set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
    echo "Usage: release.sh <version>" >&2
    echo "  version: X.Y.Z format (e.g., 0.5.0)" >&2
    exit 1
fi

# Validate version format (semver-like: X.Y.Z)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid version format '$VERSION'. Expected X.Y.Z (e.g., 0.5.0)" >&2
    exit 1
fi

# Ensure we're on the main branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "Error: Must be on 'main' branch (currently on '$CURRENT_BRANCH')" >&2
    exit 1
fi

# Ensure working tree is clean
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: Working tree is not clean. Commit or stash changes first." >&2
    exit 1
fi

# Check that untracked files won't interfere (optional, but good practice)
if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    echo "Error: There are untracked files. Commit or remove them first." >&2
    exit 1
fi

# Ensure the tag doesn't already exist
TAG="v${VERSION}"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: Tag '$TAG' already exists" >&2
    exit 1
fi

# Paths to manifest files
PLUGIN_JSON="github-devflow/.claude-plugin/plugin.json"
MARKETPLACE_JSON=".claude-plugin/marketplace.json"

# Update version in plugin.json
echo "Updating $PLUGIN_JSON ..."
jq --arg v "$VERSION" '.version = $v' "$PLUGIN_JSON" > "${PLUGIN_JSON}.tmp"
mv "${PLUGIN_JSON}.tmp" "$PLUGIN_JSON"

# Update version in marketplace.json
echo "Updating $MARKETPLACE_JSON ..."
jq --arg v "$VERSION" '.plugins[0].version = $v' "$MARKETPLACE_JSON" > "${MARKETPLACE_JSON}.tmp"
mv "${MARKETPLACE_JSON}.tmp" "$MARKETPLACE_JSON"

# Commit the version bump
echo "Committing version bump ..."
git add "$PLUGIN_JSON" "$MARKETPLACE_JSON"
git commit -m "Bump version to ${VERSION}"

# Create the tag
echo "Creating tag $TAG ..."
git tag "$TAG"

# Push commit and tag
echo "Pushing to origin ..."
git push origin main
git push origin "$TAG"

echo ""
echo "Release $TAG pushed successfully."
echo "The GitHub Actions workflow will create the release."
