#!/bin/bash
#
# Fetch review threads from a GitHub pull request
#
# Usage: fetch-review-threads.sh <pr-number> [--filter-resolved] [--filter-skill <name>]
#
# Options:
#   --filter-resolved    Filter out resolved threads
#   --filter-skill <name>  Additionally filter out threads where the latest comment
#                          contains the signature of the specified skill
#                          (github-devflow:<name>). Lets each skill filter out
#                          threads it has already responded to.
#
# Output: JSON array of review threads
#
# Example:
#   ./fetch-review-threads.sh 123
#   ./fetch-review-threads.sh 123 --filter-resolved
#   ./fetch-review-threads.sh 123 --filter-resolved --filter-skill reply
#   ./fetch-review-threads.sh 123 --filter-skill fix
#

set -euo pipefail

PR_NUMBER="${1:-}"
shift || true

FILTER_RESOLVED=false
FILTER_SKILL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --filter-resolved)
            FILTER_RESOLVED=true
            shift
            ;;
        --filter-skill)
            FILTER_SKILL="${2:-}"
            if [[ -z "$FILTER_SKILL" ]]; then
                echo "Error: --filter-skill requires a name argument" >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: fetch-review-threads.sh <pr-number> [--filter-resolved] [--filter-skill <name>]" >&2
    exit 1
fi

# Get repository owner and name
REPO_INFO=$(gh repo view --json owner,name --jq '"\(.owner.login) \(.name)"')
OWNER=$(echo "$REPO_INFO" | cut -d' ' -f1)
REPO=$(echo "$REPO_INFO" | cut -d' ' -f2)

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
          comments(first: 100) {
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

# Apply filters if requested
if [[ "$FILTER_RESOLVED" == "true" ]]; then
    # Filter out resolved threads
    THREADS=$(echo "$THREADS" | jq '
        [.[] | select(.isResolved == false)]
    ')
fi

if [[ -n "$FILTER_SKILL" ]]; then
    # Filter out threads where the latest comment contains this specific skill's signature
    THREADS=$(echo "$THREADS" | jq --arg skill "$FILTER_SKILL" '
        [.[] | select(
            ((.comments.nodes[-1].body | test("github-devflow:" + $skill; "i")) | not)
        )]
    ')
fi

# Output result with metadata
jq -n \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    --argjson pr "$PR_NUMBER" \
    --argjson threads "$THREADS" \
    '{
        owner: $owner,
        repo: $repo,
        prNumber: $pr,
        threads: $threads,
        totalCount: ($threads | length)
    }'
