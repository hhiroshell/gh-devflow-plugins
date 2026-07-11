#!/bin/bash
#
# Watch a GitHub pull request for AI-reviewer (bot) comments.
#
# Polls the PR at a fixed interval until ONE of the following happens, then
# prints a JSON result to stdout and exits 0:
#
#   - "threads":  one or more actionable review threads are waiting for a
#                 response (latest comment authored by an AI reviewer).
#   - "stop":     the reviewer posted a summary/issue comment matching the
#                 stop pattern (e.g. "there are no comments") and no threads
#                 are actionable — the review is finished.
#   - "closed":   the PR is no longer OPEN (merged or closed).
#   - "timeout":  the max wait elapsed with no activity. The caller is
#                 expected to re-invoke to keep watching.
#
# A single invocation is bounded by --max-wait so it stays within the Bash
# tool's per-call time limit; the calling skill re-invokes on "timeout".
#
# Usage: watch-pr-comments.sh <pr-number> [options]
#
# Options:
#   --interval <seconds>       Poll interval (default: 180)
#   --max-wait <seconds>       Max time to poll in this invocation (default: 480)
#   --author-filter <value>    Which authors count as "AI reviewer":
#                                bot     - any GitHub App/Bot (login ends with
#                                          "[bot]"). Default.
#                                any     - any author (excludes threads already
#                                          answered by this plugin's skills).
#                                <login> - a specific reviewer login.
#   --stop-pattern <regex>     Case-insensitive regex marking "no more comments"
#                              in a reviewer summary/issue comment. Has a sensible
#                              default (see below).
#
# Output: JSON object with a "status" field (threads|stop|closed|timeout) plus
#         status-specific fields. For "threads": owner, repo, prNumber, threads,
#         totalCount (same thread shape as fetch-review-threads.sh).
#
# Examples:
#   ./watch-pr-comments.sh 123
#   ./watch-pr-comments.sh 123 --interval 120 --max-wait 480
#   ./watch-pr-comments.sh 123 --author-filter copilot[bot]
#

set -euo pipefail

PR_NUMBER="${1:-}"
shift || true

INTERVAL=180
MAX_WAIT=480
AUTHOR_FILTER="bot"
STOP_PATTERN='(no (more |further |additional |remaining )?(comments|feedback|issues|suggestions|concerns))|(^|[^a-z])lgtm([^a-z]|$)|looks good to me|no issues found|nothing to (comment|add)'

while [[ $# -gt 0 ]]; do
    case "$1" in
        --interval)
            INTERVAL="${2:-}"; shift 2 ;;
        --max-wait)
            MAX_WAIT="${2:-}"; shift 2 ;;
        --author-filter)
            AUTHOR_FILTER="${2:-}"; shift 2 ;;
        --stop-pattern)
            STOP_PATTERN="${2:-}"; shift 2 ;;
        *)
            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$PR_NUMBER" ]]; then
    echo "Usage: watch-pr-comments.sh <pr-number> [--interval <s>] [--max-wait <s>] [--author-filter <bot|any|login>] [--stop-pattern <regex>]" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# skills/watch/scripts -> plugin root is three levels up
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
FETCH_THREADS="$PLUGIN_ROOT/scripts/fetch-review-threads.sh"

if [[ ! -f "$FETCH_THREADS" ]]; then
    echo "Error: could not locate fetch-review-threads.sh at $FETCH_THREADS" >&2
    exit 1
fi

# A thread from this plugin's own /code-review is authored under a user account,
# not a bot, so it is matched by its signature rather than by author type.
CODE_REVIEW_MATCH='((.comments.nodes[-1].body // "") | test("github-devflow:code-review"; "i"))'

# jq selector deciding whether a thread's latest comment counts as "AI reviewer".
# jq selector deciding whether a summary/issue comment's author (bound to .login) counts.
case "$AUTHOR_FILTER" in
    bot)
        # Detect bots by actor type first (reliable for GitHub Copilot, whose
        # login "copilot-pull-request-reviewer" has no "[bot]" suffix), and fall
        # back to the "[bot]" login convention used by other reviewers. Also pick
        # up this plugin's own /code-review threads by signature.
        THREAD_SELECT="(((.comments.nodes[-1].author.__typename // \"\") == \"Bot\") or ((.comments.nodes[-1].author.login // \"\") | endswith(\"[bot]\")) or $CODE_REVIEW_MATCH)"
        AUTHOR_SELECT='(((.type // "") == "Bot") or ((.login // "") | endswith("[bot]")))'
        ;;
    any)
        # Any author, but skip threads whose latest comment is already one of our
        # own replies (avoids re-processing what reply/fix/watch already handled).
        # /code-review threads are included because their signature is not in the
        # excluded set.
        THREAD_SELECT='(((.comments.nodes[-1].body // "") | test("github-devflow:(reply|fix|watch)"; "i")) | not)'
        # The "review complete" signal is only honored from bot reviewers, even in
        # "any" mode, so a human comment (or our own reply) can't stop the watch early.
        AUTHOR_SELECT='(((.type // "") == "Bot") or ((.login // "") | endswith("[bot]")))'
        ;;
    *)
        # A specific reviewer login, plus this plugin's own /code-review threads.
        THREAD_SELECT="(((.comments.nodes[-1].author.login // \"\") == \"$AUTHOR_FILTER\") or $CODE_REVIEW_MATCH)"
        AUTHOR_SELECT="((.login // \"\") == \"$AUTHOR_FILTER\")"
        ;;
esac

START_EPOCH=$(date +%s)

check_pr_closed() {
    local state
    state=$(gh pr view "$PR_NUMBER" --json state --jq '.state' 2>/dev/null || echo "")
    if [[ -n "$state" && "$state" != "OPEN" ]]; then
        jq -n --arg state "$state" '{status: "closed", prState: $state}'
        return 0
    fi
    return 1
}

# Look for a reviewer summary/issue comment signalling the review is complete.
check_stop_sentinel() {
    local owner="$1" repo="$2"
    local issue_comments reviews match

    issue_comments=$(gh api "repos/$owner/$repo/issues/$PR_NUMBER/comments" --paginate \
        --jq '[.[] | {login: .user.login, type: .user.type, body: .body}]' 2>/dev/null || echo '[]')
    reviews=$(gh api "repos/$owner/$repo/pulls/$PR_NUMBER/reviews" --paginate \
        --jq '[.[] | {login: .user.login, type: .user.type, body: .body}]' 2>/dev/null || echo '[]')

    match=$(printf '%s\n%s\n' "$issue_comments" "$reviews" | jq -s --arg pat "$STOP_PATTERN" '
        add
        | [ .[]
            | select(.body != null and .body != "")
            | select('"$AUTHOR_SELECT"')
            | select(.body | test($pat; "i")) ]
        | first // empty
    ')

    if [[ -n "$match" ]]; then
        echo "$match" | jq '{status: "stop", matched: .}'
        return 0
    fi
    return 1
}

while true; do
    # 1. Stop watching if the PR was merged/closed out from under us.
    if OUT=$(check_pr_closed); then
        echo "$OUT"
        exit 0
    fi

    # 2. Fetch unresolved threads and keep only the actionable AI-reviewer ones.
    RAW=$(bash "$FETCH_THREADS" "$PR_NUMBER" --filter-resolved)
    OWNER=$(echo "$RAW" | jq -r '.owner')
    REPO=$(echo "$RAW" | jq -r '.repo')

    ACTIONABLE=$(echo "$RAW" | jq "{owner, repo, prNumber} + {threads: [.threads[] | select($THREAD_SELECT)]}")
    COUNT=$(echo "$ACTIONABLE" | jq '.threads | length')

    if [[ "$COUNT" -gt 0 ]]; then
        echo "$ACTIONABLE" | jq '. + {status: "threads", totalCount: (.threads | length)}'
        exit 0
    fi

    # 3. No actionable threads — is the reviewer telling us it's done?
    if OUT=$(check_stop_sentinel "$OWNER" "$REPO"); then
        echo "$OUT"
        exit 0
    fi

    # 4. Nothing yet. Sleep, unless the next sleep would exceed the budget.
    NOW=$(date +%s)
    ELAPSED=$(( NOW - START_EPOCH ))
    if [[ $(( ELAPSED + INTERVAL )) -gt "$MAX_WAIT" ]]; then
        jq -n --argjson waited "$ELAPSED" '{status: "timeout", waitedSeconds: $waited}'
        exit 0
    fi

    sleep "$INTERVAL"
done
