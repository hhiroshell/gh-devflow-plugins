#!/bin/bash
#
# Post a pull request review with line-specific comments to GitHub
#
# Usage: post-review.sh <pr-number> <review-body-file> <comments-json-file>
#
# Arguments:
#   pr-number         The pull request number
#   review-body-file  Path to a file containing the review summary body (markdown)
#   comments-json-file Path to a JSON file containing the array of review comments
#
# Comments JSON format:
#   [
#     {
#       "path": "src/main.py",
#       "line": 42,
#       "start_line": 40,  (optional, for multi-line comments)
#       "body": "Comment text..."
#     },
#     ...
#   ]
#
# Note: A "Claude Code" signature is automatically appended to the review body.
# The review is posted with COMMENT event (no approve/reject).
#
# Output: JSON with the created review details
#
# Examples:
#   ./post-review.sh 123 /tmp/review-body.md /tmp/comments.json
#

set -euo pipefail

PR_NUMBER="${1:-}"
REVIEW_BODY_FILE="${2:-}"
COMMENTS_JSON_FILE="${3:-}"

if [[ -z "$PR_NUMBER" || -z "$REVIEW_BODY_FILE" || -z "$COMMENTS_JSON_FILE" ]]; then
    echo "Usage: post-review.sh <pr-number> <review-body-file> <comments-json-file>" >&2
    exit 1
fi

# Validate PR number is a positive integer
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: PR number must be a positive integer, got: $PR_NUMBER" >&2
    exit 1
fi

# Validate file paths are within /tmp/github-devflow:code-review/
if ! [[ "$REVIEW_BODY_FILE" =~ ^/tmp/github-devflow:code-review/ ]]; then
    echo "Error: Review body file must be in /tmp/github-devflow:code-review/ directory" >&2
    exit 1
fi

if ! [[ "$COMMENTS_JSON_FILE" =~ ^/tmp/github-devflow:code-review/ ]]; then
    echo "Error: Comments JSON file must be in /tmp/github-devflow:code-review/ directory" >&2
    exit 1
fi

if [[ ! -f "$REVIEW_BODY_FILE" ]]; then
    echo "Error: Review body file not found: $REVIEW_BODY_FILE" >&2
    exit 1
fi

if [[ ! -f "$COMMENTS_JSON_FILE" ]]; then
    echo "Error: Comments JSON file not found: $COMMENTS_JSON_FILE" >&2
    exit 1
fi

# Read review body and append skill-specific signature
REVIEW_BODY=$(cat "$REVIEW_BODY_FILE")
SIGNATURE=$'\n\n---\n*Review generated with [Claude Code](https://claude.ai/code) - github-devflow:code-review*'
REVIEW_BODY="${REVIEW_BODY}${SIGNATURE}"

# Read comments JSON
COMMENTS_JSON=$(cat "$COMMENTS_JSON_FILE")

# Validate comments JSON is an array with required fields
if ! echo "$COMMENTS_JSON" | jq -e 'type == "array"' > /dev/null 2>&1; then
    echo "Error: Comments file must contain a JSON array" >&2
    exit 1
fi

# Validate each comment has required fields (path, line, body)
if ! echo "$COMMENTS_JSON" | jq -e 'all(has("path") and has("line") and has("body"))' > /dev/null 2>&1; then
    echo "Error: Each comment must have 'path', 'line', and 'body' fields" >&2
    exit 1
fi

# Get repository owner and name
REPO_INFO=$(gh repo view --json owner,name --jq '"\(.owner.login) \(.name)"')
OWNER=$(echo "$REPO_INFO" | cut -d' ' -f1)
REPO=$(echo "$REPO_INFO" | cut -d' ' -f2)

# Get the PR's latest commit SHA (required for review API)
COMMIT_SHA=$(gh pr view "$PR_NUMBER" --json commits --jq '.commits[-1].oid // empty')
if [[ -z "$COMMIT_SHA" ]]; then
    echo "Error: PR has no commits" >&2
    exit 1
fi

# Build the review comments array for the API
# Transform from our format to GitHub's API format
# Supports optional start_line for multi-line comments
API_COMMENTS=$(echo "$COMMENTS_JSON" | jq '[.[] | {
    path: .path,
    line: .line,
    body: .body,
    side: "RIGHT"
} + (if .start_line then {start_line: .start_line, start_side: "RIGHT"} else {} end)]')

# Post the review using REST API
RESULT=$(gh api \
    "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
    --method POST \
    --input <(jq -n \
        --arg body "$REVIEW_BODY" \
        --arg commit "$COMMIT_SHA" \
        --argjson comments "$API_COMMENTS" \
        '{body: $body, commit_id: $commit, event: "COMMENT", comments: $comments}'))

# Check for success by verifying the response has an id field
if ! echo "$RESULT" | jq -e '.id' > /dev/null 2>&1; then
    echo "Error posting review:" >&2
    echo "$RESULT" | jq '.' >&2
    exit 1
fi

# Output success response
echo "$RESULT" | jq '{
    success: true,
    review: {
        id: .id,
        html_url: .html_url,
        state: .state,
        submitted_at: .submitted_at,
        comments_count: (.comments // [] | length)
    }
}'
