#!/bin/bash
#
# Re-request a review from a pull request's bot reviewer(s) so they re-review
# the latest commits. GitHub Copilot in particular does not re-review new
# commits on its own — its review has to be requested again.
#
# By default, the reviewers to re-request are auto-detected from the PR's
# review-request history (bot reviewers previously requested, e.g. "Copilot").
# If none are found, it falls back to "Copilot". Override with --reviewer.
#
# Usage: rerequest-review.sh <pr-number> [--reviewer <login>]...
#
# Options:
#   --reviewer <login>   Reviewer login to re-request (repeatable). When given,
#                        auto-detection is skipped.
#
# Output: JSON { requested: [logins], skipped: [logins], errors: [strings] }
#
# Examples:
#   ./rerequest-review.sh 123
#   ./rerequest-review.sh 123 --reviewer Copilot
#

set -euo pipefail

PR_NUMBER="${1:-}"
shift || true

REVIEWERS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --reviewer)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --reviewer requires a login argument" >&2
                exit 1
            fi
            REVIEWERS+=("$2")
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: rerequest-review.sh <pr-number> [--reviewer <login>]..." >&2
    exit 1
fi

REPO_INFO=$(gh repo view --json owner,name --jq '"\(.owner.login) \(.name)"')
OWNER=$(echo "$REPO_INFO" | cut -d' ' -f1)
REPO=$(echo "$REPO_INFO" | cut -d' ' -f2)

# Auto-detect bot reviewers previously requested on this PR when none were given.
if [[ ${#REVIEWERS[@]} -eq 0 ]]; then
    while IFS= read -r login; do
        [[ -n "$login" ]] && REVIEWERS+=("$login")
    done < <(gh api "repos/$OWNER/$REPO/issues/$PR_NUMBER/timeline" --paginate \
        --jq '.[] | select(.event=="review_requested") | select(.requested_reviewer.type=="Bot") | .requested_reviewer.login' 2>/dev/null \
        | sort -u)

    # Fall back to Copilot if the PR has no prior bot review requests.
    if [[ ${#REVIEWERS[@]} -eq 0 ]]; then
        REVIEWERS+=("Copilot")
    fi
fi

requested=()
skipped=()
errors=()

for reviewer in "${REVIEWERS[@]}"; do
    body=$(jq -n --arg r "$reviewer" '{reviewers: [$r]}')
    if result=$(gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/requested_reviewers" \
            --method POST --input <(printf '%s' "$body") 2>&1); then
        requested+=("$reviewer")
    else
        # A reviewer already pending re-review is not an error worth failing on.
        if echo "$result" | grep -qi "already requested\|review has already been requested"; then
            skipped+=("$reviewer")
        else
            errors+=("$reviewer: $(echo "$result" | tr '\n' ' ' | sed 's/"/'"'"'/g')")
        fi
    fi
done

jq -n \
    --argjson requested "$(printf '%s\n' "${requested[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')" \
    --argjson skipped "$(printf '%s\n' "${skipped[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')" \
    --argjson errors "$(printf '%s\n' "${errors[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')" \
    '{requested: $requested, skipped: $skipped, errors: $errors}'
