#!/bin/bash
#
# Post a reply to a GitHub pull request review thread
#
# Usage: post-reply.sh <thread-id> <body>
#        post-reply.sh --file <thread-id> <body-file>
#
# Arguments:
#   thread-id   The GraphQL ID of the review thread (e.g., PRRT_xxx)
#   body        The reply message text
#   body-file   Path to a file containing the reply message (use with --file)
#
# Output: JSON with the created comment ID
#
# Examples:
#   ./post-reply.sh "PRRT_kwDONRxxx" "Thanks, I've fixed this in the latest commit."
#   ./post-reply.sh --file "PRRT_kwDONRxxx" /tmp/reply.md
#

set -euo pipefail

# Parse arguments
if [[ "${1:-}" == "--file" ]]; then
    THREAD_ID="${2:-}"
    BODY_FILE="${3:-}"

    if [[ -z "$THREAD_ID" || -z "$BODY_FILE" ]]; then
        echo "Usage: post-reply.sh --file <thread-id> <body-file>" >&2
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
        echo "Usage: post-reply.sh <thread-id> <body>" >&2
        echo "       post-reply.sh --file <thread-id> <body-file>" >&2
        exit 1
    fi
fi

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
