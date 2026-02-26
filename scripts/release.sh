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
#   2. Updates plugin.json version to the release version
#   3. Updates marketplace.json ref to the release tag
#   4. Commits and tags the release
#   5. Bumps plugin.json to the next dev version (X.(Y+1).0-dev)
#   6. Commits the dev version bump
#   7. Pushes main and the tag
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

# --- Release commit ---

# Update version in plugin.json
echo "Updating $PLUGIN_JSON to ${VERSION} ..."
jq --arg v "$VERSION" '.version = $v' "$PLUGIN_JSON" > "${PLUGIN_JSON}.tmp"
mv "${PLUGIN_JSON}.tmp" "$PLUGIN_JSON"

# Update ref in marketplace.json
echo "Updating $MARKETPLACE_JSON ref to ${TAG} ..."
jq --arg ref "$TAG" '.plugins[0].source.ref = $ref' "$MARKETPLACE_JSON" > "${MARKETPLACE_JSON}.tmp"
mv "${MARKETPLACE_JSON}.tmp" "$MARKETPLACE_JSON"

# Commit the release version
echo "Committing release version ..."
git add "$PLUGIN_JSON" "$MARKETPLACE_JSON"
git commit -m "Bump version to ${VERSION}"

# Create the tag
echo "Creating tag $TAG ..."
git tag "$TAG"

# --- Dev version bump ---

# Calculate next dev version: increment minor, reset patch, append -dev
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
NEXT_MINOR=$((MINOR + 1))
DEV_VERSION="${MAJOR}.${NEXT_MINOR}.0-dev"

# Update plugin.json to dev version
echo "Bumping $PLUGIN_JSON to ${DEV_VERSION} for development ..."
jq --arg v "$DEV_VERSION" '.version = $v' "$PLUGIN_JSON" > "${PLUGIN_JSON}.tmp"
mv "${PLUGIN_JSON}.tmp" "$PLUGIN_JSON"

# Commit the dev version bump
git add "$PLUGIN_JSON"
git commit -m "Bump version to ${DEV_VERSION} for development"

# Push commit and tag
echo "Pushing to origin ..."
git push origin main
git push origin "$TAG"

echo ""
echo "Release $TAG pushed successfully."
echo "main is now at ${DEV_VERSION}."
echo "The GitHub Actions workflow will create the release."
