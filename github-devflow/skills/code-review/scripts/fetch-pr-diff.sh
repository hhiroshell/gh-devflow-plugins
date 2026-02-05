#!/bin/bash
#
# Fetch pull request diff and metadata from GitHub
#
# Usage: fetch-pr-diff.sh <pr-number>
#
# Output: JSON with PR metadata and diff content
#   - owner, repo, prNumber: Repository context
#   - title, body, baseRef, headRef: PR metadata
#   - changedFiles: Array of changed file paths
#   - diff: Full unified diff text
#
# Example:
#   ./fetch-pr-diff.sh 123
#

set -euo pipefail

PR_NUMBER="${1:-}"

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: fetch-pr-diff.sh <pr-number>" >&2
    exit 1
fi

if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: PR number must be a positive integer, got: $PR_NUMBER" >&2
    exit 1
fi

# Get repository owner and name
REPO_INFO=$(gh repo view --json owner,name --jq '"\(.owner.login) \(.name)"')
OWNER=$(echo "$REPO_INFO" | cut -d' ' -f1)
REPO=$(echo "$REPO_INFO" | cut -d' ' -f2)

# Fetch PR metadata
PR_META=$(gh pr view "$PR_NUMBER" --json title,body,baseRefName,headRefName,files)

TITLE=$(echo "$PR_META" | jq -r '.title')
BODY=$(echo "$PR_META" | jq -r '.body // ""')
BASE_REF=$(echo "$PR_META" | jq -r '.baseRefName')
HEAD_REF=$(echo "$PR_META" | jq -r '.headRefName')
CHANGED_FILES=$(echo "$PR_META" | jq '[.files[].path]')

# Fetch the diff
DIFF=$(gh pr diff "$PR_NUMBER")

# Output result
jq -n \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    --argjson pr "$PR_NUMBER" \
    --arg title "$TITLE" \
    --arg body "$BODY" \
    --arg baseRef "$BASE_REF" \
    --arg headRef "$HEAD_REF" \
    --argjson changedFiles "$CHANGED_FILES" \
    --arg diff "$DIFF" \
    '{
        owner: $owner,
        repo: $repo,
        prNumber: $pr,
        title: $title,
        body: $body,
        baseRef: $baseRef,
        headRef: $headRef,
        changedFiles: $changedFiles,
        diff: $diff
    }'
