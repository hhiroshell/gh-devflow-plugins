#!/bin/bash
#
# Fetch review threads from a GitHub pull request
#
# Usage: fetch-review-threads.sh <pr-number> [--filter-actionable]
#
# Options:
#   --filter-actionable  Filter to show only threads requiring action:
#                        - Unresolved threads
#                        - Latest comment is from another user
#
# Output: JSON array of review threads
#
# Example:
#   ./fetch-review-threads.sh 123
#   ./fetch-review-threads.sh 123 --filter-actionable
#

set -euo pipefail

PR_NUMBER="${1:-}"
FILTER_ACTIONABLE="${2:-}"

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: fetch-review-threads.sh <pr-number> [--filter-actionable]" >&2
    exit 1
fi

# Get repository owner and name
REPO_INFO=$(gh repo view --json owner,name --jq '"\(.owner.login) \(.name)"')
OWNER=$(echo "$REPO_INFO" | cut -d' ' -f1)
REPO=$(echo "$REPO_INFO" | cut -d' ' -f2)

# Get current user login for filtering
CURRENT_USER=$(gh api user --jq '.login')

# Fetch review threads with pagination support
fetch_threads() {
    local after=""
    local all_threads="[]"

    while true; do
        local after_param=""
        if [[ -n "$after" ]]; then
            after_param=", after: \"$after\""
        fi

        local result
        result=$(gh api graphql -f query="
query {
  repository(owner: \"$OWNER\", name: \"$REPO\") {
    pullRequest(number: $PR_NUMBER) {
      id
      reviewThreads(first: 100$after_param) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          isResolved
          path
          line
          startLine
          diffSide
          comments(last: 1) {
            nodes {
              id
              author { login }
              body
              createdAt
            }
          }
        }
      }
    }
  }
}")

        # Extract threads from this page
        local threads
        threads=$(echo "$result" | jq '.data.repository.pullRequest.reviewThreads.nodes')

        # Merge with all_threads
        all_threads=$(echo "$all_threads $threads" | jq -s 'add')

        # Check for next page
        local has_next
        has_next=$(echo "$result" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')

        if [[ "$has_next" != "true" ]]; then
            break
        fi

        after=$(echo "$result" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
    done

    echo "$all_threads"
}

# Fetch all threads
THREADS=$(fetch_threads)

# Apply filter if requested
if [[ "$FILTER_ACTIONABLE" == "--filter-actionable" ]]; then
    THREADS=$(echo "$THREADS" | jq --arg user "$CURRENT_USER" '
        [.[] | select(
            .isResolved == false and
            (.comments.nodes[0].author.login != $user)
        )]
    ')
fi

# Output result with metadata
jq -n \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    --argjson pr "$PR_NUMBER" \
    --arg currentUser "$CURRENT_USER" \
    --argjson threads "$THREADS" \
    '{
        owner: $owner,
        repo: $repo,
        prNumber: $pr,
        currentUser: $currentUser,
        threads: $threads,
        totalCount: ($threads | length)
    }'
