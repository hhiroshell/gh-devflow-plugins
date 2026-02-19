#!/bin/bash
#
# Post a reply to a GitHub pull request review thread
#
# Usage: post-reply.sh [--skill <name>] <thread-id> <body>
#        post-reply.sh [--skill <name>] --file <thread-id> <body-file>
#
# Options:
#   --skill <name>  Include skill identifier in signature (e.g., "reply", "fix")
#                   Signature becomes: *Reply generated with [Claude Code](...) - github-devflow:<name>*
#                   When omitted, uses generic signature without skill identifier.
#
# Arguments:
#   thread-id   The GraphQL ID of the review thread (e.g., PRRT_xxx)
#   body        The reply message text
#   body-file   Path to a file containing the reply message (use with --file)
#
# Note: A "Claude Code" signature is automatically appended to identify
#       AI-generated replies for filtering in subsequent runs.
#
# Output: JSON with the created comment ID
#
# Examples:
#   ./post-reply.sh --skill reply "PRRT_kwDONRxxx" "Thanks, I've fixed this."
#   ./post-reply.sh --skill fix --file "PRRT_kwDONRxxx" /tmp/reply.md
#   ./post-reply.sh "PRRT_kwDONRxxx" "Backward-compatible usage without --skill"
#

set -euo pipefail

# Parse --skill option
SKILL_NAME=""
if [[ "${1:-}" == "--skill" ]]; then
    SKILL_NAME="${2:-}"
    if [[ -z "$SKILL_NAME" ]]; then
        echo "Error: --skill requires a name argument" >&2
        exit 1
    fi
    shift 2
fi

# Parse remaining arguments
if [[ "${1:-}" == "--file" ]]; then
    THREAD_ID="${2:-}"
    BODY_FILE="${3:-}"

    if [[ -z "$THREAD_ID" || -z "$BODY_FILE" ]]; then
        echo "Usage: post-reply.sh [--skill <name>] --file <thread-id> <body-file>" >&2
        exit 1
    fi

    if [[ ! -f "$BODY_FILE" ]]; then
        echo "Error: File not found: $BODY_FILE" >&2
        exit 1
    fi

    BODY=$(cat "$BODY_FILE")
else
    THREAD_ID="${1:-}"
    BODY="${2:-}"

    if [[ -z "$THREAD_ID" || -z "$BODY" ]]; then
        echo "Usage: post-reply.sh [--skill <name>] <thread-id> <body>" >&2
        echo "       post-reply.sh [--skill <name>] --file <thread-id> <body-file>" >&2
        exit 1
    fi
fi

# Append Claude Code signature for identification in future filtering
if [[ -n "$SKILL_NAME" ]]; then
    SIGNATURE=$'\n\n---\n*Reply generated with [Claude Code](https://claude.ai/code) - github-devflow:'"${SKILL_NAME}"'*'
else
    SIGNATURE=$'\n\n---\n*Reply generated with [Claude Code](https://claude.ai/code)*'
fi
BODY="${BODY}${SIGNATURE}"

# Post the reply using GraphQL mutation
RESULT=$(gh api graphql -f query='
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: $threadId
    body: $body
  }) {
    comment {
      id
      url
      createdAt
      author {
        login
      }
    }
  }
}' -f threadId="$THREAD_ID" -f body="$BODY")

# Check for errors
if echo "$RESULT" | jq -e '.errors' > /dev/null 2>&1; then
    echo "Error posting reply:" >&2
    echo "$RESULT" | jq '.errors' >&2
    exit 1
fi

# Output success response
echo "$RESULT" | jq '{
    success: true,
    comment: .data.addPullRequestReviewThreadReply.comment
}'
