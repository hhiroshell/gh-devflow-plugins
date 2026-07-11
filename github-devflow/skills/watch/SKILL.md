---
description: This skill should be used when the user asks to "watch a PR", "watch PR #123", "watch for AI review comments", "auto-handle AI review", or "babysit this PR through review", or wants to continuously monitor a pull request for AI reviewer (bot) comments and automatically reply to and fix them until the reviewer reports no further comments.
argument-hint: "<pr-number>"
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
---

# GitHub PR AI-Review Watcher

Continuously watch a pull request for review comments from AI reviewers — bot accounts such as GitHub Copilot or `coderabbitai[bot]`, as well as this plugin's own `/code-review` skill. Each time new comments appear, reply to them and apply fixes by driving the `reply` and `fix` skills, then keep watching. Stop when the reviewer signals the review is complete (e.g. a summary comment matching "there are no comments") or the PR is closed/merged.

This skill orchestrates a loop; the actual reply and fix work follows the `reply` and `fix` skills' documented workflows (read and execute their `SKILL.md` files) rather than reimplementing them.

## How AI comments are detected

A review thread is **actionable** when it is unresolved and the **latest comment** either:

- is **authored by an AI reviewer** — any GitHub App/Bot, detected by actor type (`Bot`) with a fallback to the `[bot]` login convention. Detecting by type matters because GitHub Copilot posts under the login `copilot-pull-request-reviewer` with **no** `[bot]` suffix — a login-only check would miss it; or
- carries this plugin's **`github-devflow:code-review` signature** — the `/code-review` skill posts under a user account (not a bot), so its comments are matched by signature instead of author type.

Either way, once `reply`/`fix` respond, the latest comment is one of their signed replies, so the thread stops being actionable. The `--author-filter` option narrows or widens the bot side of this (see Script Reference); `/code-review` threads are detected in every mode.

## Helper Scripts

| Script | Location | Purpose |
|--------|----------|---------|
| `watch-pr-comments.sh` | `skills/watch/scripts/` | Poll the PR until there are actionable AI-reviewer threads, a stop signal, a closed PR, or a timeout |
| `fetch-review-threads.sh` | `scripts/` (plugin root) | Fetch PR review threads. Wrapped by `watch-pr-comments.sh`; also used directly by the `reply`/`fix` workflows |
| `post-reply.sh` | `scripts/` (plugin root) | Post replies to threads. Used by the `reply`/`fix` workflows |

`watch-pr-comments.sh` owns all timing and detection so the loop stays deterministic. A single invocation polls for a bounded window and returns a JSON `status`; this skill re-invokes it to keep watching.

## Workflow

### Step 1: Validate Input

Confirm a PR number was provided as `$ARGUMENTS`. If missing, ask the user which PR to watch. Verify `gh` is authenticated (`gh auth status`); if not, tell the user to run `gh auth login`.

### Step 2: Poll for Activity

Run the watch script. It blocks until something actionable happens, so allow the full Bash time budget:

```bash
PR_NUMBER=$ARGUMENTS
bash ${CLAUDE_PLUGIN_ROOT}/skills/watch/scripts/watch-pr-comments.sh $PR_NUMBER
```

The script self-bounds each invocation to `--max-wait` (default 480s / 8 min) and returns `timeout` on its own. Invoke this Bash call with a `timeout` of `600000` (10 min) as a ceiling — the headroom above 480s ensures the script returns before Bash cuts it off.

The script prints a JSON object with a `status` field:

| `status` | Meaning | Next action |
|----------|---------|-------------|
| `threads` | Actionable AI-reviewer threads are waiting | Go to Step 3 |
| `stop` | Reviewer signalled the review is complete | Go to Step 5 |
| `closed` | PR is merged or closed | Go to Step 5 |
| `timeout` | No activity within the poll window | Go to Step 4 |

### Step 3: Reply, Then Fix

When `status` is `threads`, handle the new comments in two passes. The `reply` and `fix` skills set `disable-model-invocation: true`, so they cannot be triggered as skills from here; instead, **execute their documented workflows**. Read the referenced `SKILL.md` and follow its steps, which use the shared `fetch-review-threads.sh` and `post-reply.sh` scripts.

1. **Reply**: Execute the reply workflow in `${CLAUDE_PLUGIN_ROOT}/skills/reply/SKILL.md`. It posts thoughtful responses to the outstanding threads without changing code.
2. **Confirm uncertain fixes**: Review the actionable threads returned by the watch script. For any thread whose fix is **clear-cut**, proceed. For any thread where the approach is **ambiguous, risky, or has multiple valid options**, use `AskUserQuestion` to confirm the intended approach before changing code. Do not ask about straightforward fixes.
3. **Fix**: Execute the fix workflow in `${CLAUDE_PLUGIN_ROOT}/skills/fix/SKILL.md`. It makes code changes, commits, pushes, and posts a per-thread report. Apply the approach(es) the user confirmed in the previous step.

After the fix pass pushes, the AI reviewer typically re-reviews. Return to **Step 2** to watch for the next round.

### Step 4: Handle Timeout (keep watching)

A `timeout` means no new comments arrived in the poll window — normal while a reviewer is still working. Re-invoke Step 2 to continue watching.

To avoid watching forever when a review has quietly stalled: after **3 consecutive timeouts** with no activity, use `AskUserQuestion` to ask whether to keep watching or stop. The watch script already exits with `closed` if the PR is merged/closed, so no separate check is needed.

### Step 5: Finish

When `status` is `stop` or `closed`, end the loop and report a summary:

- Why watching ended (reviewer signalled completion, quoting the matched comment; or PR closed/merged)
- Total watch rounds handled
- Fixes committed and pushed across all rounds (with commit SHAs), and any issues created by `fix`
- Any threads left unaddressed or errors encountered

## Important Guidelines

### Confirmation Policy

- Proceed autonomously on clear-cut fixes (obvious bugs, typos, missing null checks, mechanical refactors).
- Pause with `AskUserQuestion` only when a fix is ambiguous, risky, touches broad/shared code, or has multiple reasonable approaches.
- Never apply a fix the user declined; if declined, note it in the reply/summary and move on.

### Loop Safety

- Only the reviewer's stop signal, a closed/merged PR, or the user ending the session stops the loop.
- Respect the user if they ask to stop watching at any point.
- Do not lower the poll interval below a minute; frequent polling wastes API calls without helping.

### Stop Signal Tuning

The default stop pattern matches phrases like "no comments", "no further comments", "no issues found", and "LGTM" in reviewer summary/issue comments. If a specific reviewer uses different wording, pass a custom `--stop-pattern` (see Script Reference).

### Error Handling

- If `gh` is not authenticated, tell the user to run `gh auth login`.
- If the PR number is invalid, report the error clearly and stop.
- If the `reply` or `fix` step fails for a round, report the error and ask the user whether to retry or stop rather than silently looping.

## Script Reference

### watch-pr-comments.sh

```
Usage: watch-pr-comments.sh <pr-number> [options]

Options:
  --interval <seconds>     Poll interval (default: 180)
  --max-wait <seconds>     Max time to poll in this invocation (default: 480).
                           Keep below the Bash tool's per-call limit.
  --author-filter <value>  Who counts as an AI reviewer:
                             bot     - any GitHub App/Bot (actor type Bot, or a
                                       "...[bot]" login). Catches GitHub Copilot.
                                       Default.
                             any     - handle threads from any author (skips
                                       threads already answered by this plugin's
                                       skills). The stop signal is still only
                                       honored from bot reviewers.
                             <login> - a specific reviewer login.
  --stop-pattern <regex>   Case-insensitive regex marking "no more comments"
                           in a reviewer summary/issue comment.

Output: JSON with a "status" field:
  threads  -> owner, repo, prNumber, threads[], totalCount
  stop     -> matched (the reviewer comment that ended the watch)
  closed   -> prState
  timeout  -> waitedSeconds
```
