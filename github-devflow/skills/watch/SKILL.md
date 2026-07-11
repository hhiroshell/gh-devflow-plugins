---
description: This skill should be used when the user asks to "watch a PR", "watch PR #123", "watch for AI review comments", "auto-handle AI review", or "babysit this PR through review", or wants to continuously monitor a pull request for AI reviewer (bot) comments and automatically reply to and fix them until the reviewer reports no further comments.
argument-hint: "<pr-number>"
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# GitHub PR AI-Review Watcher

Continuously watch a pull request for review comments from AI reviewers — bot accounts such as GitHub Copilot or `coderabbitai[bot]`, as well as this plugin's own `/code-review` skill. Each time new comments appear, reply to them and apply fixes by driving the `reply` and `fix` skills, then keep watching. Stop when the reviewer signals the review is complete (e.g. a summary comment matching "there are no comments"), the PR is closed/merged, or the reviewer goes quiet (a poll window elapses with no new activity — see Step 4).

This skill orchestrates a loop; the actual reply and fix work follows the `reply` and `fix` skills' documented workflows (read and execute their `SKILL.md` files) rather than reimplementing them.

## How AI comments are detected

A review thread is **actionable** when it is unresolved and one of the following holds:

- The **latest comment is authored by an AI reviewer** — any GitHub App/Bot, detected by actor type (`Bot`) with a fallback to the `[bot]` login convention. Detecting by type matters because GitHub Copilot posts under the login `copilot-pull-request-reviewer` with **no** `[bot]` suffix — a login-only check would miss it.
- The **latest comment carries this plugin's `github-devflow:code-review` signature** — the `/code-review` skill posts under a user account (not a bot), so its comments are matched by signature instead of author type.
- The thread is an **answered question** — this skill parked a `github-devflow:watch` question on it in an earlier round (see Step 3), and the user has since replied. The user's reply carries no plugin signature, so it is recognized as the answer to act on.

Once `reply`/`fix` respond, the latest comment is one of their signed replies, so the thread stops being actionable. A still-**unanswered** parked question (latest comment is the `github-devflow:watch` question) is intentionally **not** actionable — it waits for the user. The `--author-filter` option narrows or widens the bot side of this (see Script Reference); `/code-review` threads and answered questions are detected in every mode.

## Helper Scripts

| Script | Location | Purpose |
|--------|----------|---------|
| `watch-pr-comments.sh` | `skills/watch/scripts/` | Poll the PR until there are actionable AI-reviewer threads, a stop signal, a closed PR, or a timeout |
| `fetch-review-threads.sh` | `scripts/` (plugin root) | Fetch PR review threads. Wrapped by `watch-pr-comments.sh`; also used directly by the `reply`/`fix` workflows |
| `post-reply.sh` | `scripts/` (plugin root) | Post replies to threads. Used by the `reply`/`fix` workflows, and directly by this skill (`--skill watch`) to park questions for the user |

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
| `stop` | Reviewer signalled the review is complete | Go to Step 4 |
| `closed` | PR is merged or closed | Go to Step 4 |
| `timeout` | No activity within the poll window (reviewer is quiet) | Go to Step 4 |

### Step 3: Classify and Handle Threads

When `status` is `threads`, classify each actionable thread, then act. The `reply` and `fix` skills set `disable-model-invocation: true`, so they cannot be triggered as skills from here; instead, **execute their documented workflows** — read `${CLAUDE_PLUGIN_ROOT}/skills/reply/SKILL.md` and `${CLAUDE_PLUGIN_ROOT}/skills/fix/SKILL.md` and follow their steps, which use the shared `fetch-review-threads.sh` and `post-reply.sh` scripts.

**Classify each thread:**

- **Answered question** — the thread already contains a `github-devflow:watch` question from an earlier round and the latest comment is the user's reply. The user has stated how to proceed; apply their guidance without asking again.
- **Clear-cut** — a reviewer comment whose fix is obvious (typo, missing null check, mechanical refactor).
- **Uncertain** — a reviewer comment whose fix is ambiguous, risky, touches broad or shared code, or has multiple reasonable approaches.

**For uncertain threads, ask on the PR — do not block the session for an answer.**

Post the question as a reply on that thread so the user can answer inline on GitHub, and leave the code unchanged for that thread this round:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/post-reply.sh --skill watch "<thread-id>" "<question stating the options and what needs to be decided>"
```

The question's `github-devflow:watch` signature becomes the thread's latest comment, so the `reply` and `fix` workflows automatically skip it until the user replies (and the watch poller does not re-surface it while it waits).

**For clear-cut and answered-question threads, reply then fix:**

1. **Reply**: Execute the reply workflow in `${CLAUDE_PLUGIN_ROOT}/skills/reply/SKILL.md`. It posts thoughtful responses without changing code.
2. **Fix**: Execute the fix workflow in `${CLAUDE_PLUGIN_ROOT}/skills/fix/SKILL.md`. It makes code changes, commits, pushes, and posts a per-thread report. For answered-question threads, apply the approach the user chose in their reply.

**Notify about parked questions.**

If any questions were posted this round, tell the user which threads await a reply — include each comment URL returned by `post-reply.sh` (the `comment.url` field). For example: "Posted 2 questions on PR #123 — reply on these threads and I'll apply your decision on the next check: <url1>, <url2>."

After the fix pass pushes, return to **Step 2** to watch for the reviewer's next round. If the reviewer re-reviews within the poll window, handle that round; if the window elapses with no new activity, the watch ends (Step 4). When the user replies to a parked question, a later round detects it as an *answered question* and applies the fix.

Keep a **running tally across all rounds** — replies posted, fixes committed (with SHAs), issues created, and questions parked (with URLs) — so the end-of-watch summary in Step 4 can cover the whole session.

### Step 4: Finish

The watch loop ends on any of `stop`, `closed`, or `timeout`:

- `stop` — the reviewer signalled the review is complete.
- `closed` — the PR was merged or closed.
- `timeout` — the poll window elapsed with no new activity. Treat this as the reviewer having gone quiet and **stop watching** rather than polling again. (AI reviewers such as Copilot often do not re-review new commits unless their review is re-requested; if that is the case, re-request the review on GitHub and run `/watch` again.)

On any of these, report an activity summary **in the Claude Code session — do not post it as a PR comment.** The per-thread replies, fixes, and questions were already posted to the PR during the rounds; this end-of-watch summary is for the session only.

Draw it from the running tally kept across rounds (Step 3) and cover the whole watch:

- Why watching ended (reviewer signalled completion, quoting the matched comment; PR closed/merged; or reviewer went quiet after a timeout)
- Total watch rounds handled, and replies posted across all rounds
- Fixes committed and pushed across all rounds (with commit SHAs), and any issues created by `fix`
- **Any parked questions still awaiting the user's reply** (with their thread URLs) — a review can end while a question is still open, so call these out explicitly rather than letting them be forgotten
- Any threads left unaddressed or errors encountered

## Important Guidelines

### Confirmation Policy

- Proceed autonomously on clear-cut fixes (obvious bugs, typos, missing null checks, mechanical refactors).
- When a fix is ambiguous, risky, touches broad/shared code, or has multiple reasonable approaches, **do not change code and do not block the session waiting for an answer**. Instead, post the question as a reply on that PR thread (signed `github-devflow:watch`) and notify the user that a thread awaits their reply. Pick the fix up on a later round once they answer.
- Never apply a fix the user declined; if they decline in their reply, note it in the thread and summary and move on.

### Loop Safety

- The loop stops on the reviewer's stop signal, a closed/merged PR, an inactivity timeout (the reviewer went quiet), or the user ending the session — it does not poll indefinitely.
- Respect the user if they ask to stop watching at any point.
- Do not lower the poll interval below a minute; frequent polling wastes API calls without helping.

### Stop Signal Tuning

The default stop pattern matches phrases like "no comments", "no further comments", "no issues found", and "LGTM" in reviewer summary/issue comments. If a specific reviewer uses different wording, pass a custom `--stop-pattern` (see Script Reference).

### Error Handling

- If `gh` is not authenticated, tell the user to run `gh auth login`.
- If the PR number is invalid, report the error clearly and stop.
- If the `reply` or `fix` step fails for a round, report the error and stop rather than silently looping.

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
