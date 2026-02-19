---
description: This skill should be used when the user asks to "fix PR comments", "fix review feedback", "fix PR #123", "address review comments", "resolve PR feedback", "apply review suggestions", "handle PR feedback", or wants to automatically process unresolved review threads on a pull request by fixing code, creating issues, or dismissing comments.
argument-hint: "<pr-number>"
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# GitHub PR Review Fixer

Process unresolved review threads on a pull request by analyzing each thread and taking the appropriate action: fix the code, create a new issue, or dismiss with no action. After all actions are taken, reply to each thread reporting the results.

**Action types:**

| Action | Description |
|--------|-------------|
| **fix** | Make code changes to address the reviewer's concern and commit |
| **new issue** | Create a GitHub issue to track the problem for later |
| **won't fix** | No action needed (minor suggestion, style preference, or already addressed) |

## Helper Scripts

This skill reuses helper scripts from the `reply` skill:

| Script | Purpose |
|--------|---------|
| `reply/scripts/fetch-review-threads.sh` | Fetch review threads from a PR with optional filtering |
| `reply/scripts/post-reply.sh` | Post a reply to a review thread |

## Workflow

### Step 1: Fetch Actionable Threads

Fetch unresolved review threads that need attention:

```bash
PR_NUMBER=$ARGUMENTS
bash ${CLAUDE_PLUGIN_ROOT}/skills/reply/scripts/fetch-review-threads.sh $PR_NUMBER --filter-resolved --filter-skill fix
```

This returns JSON with:
- `owner`, `repo`, `prNumber`: Repository context
- `threads`: Array of threads requiring action
- `totalCount`: Number of actionable threads

Each thread contains:
- `id`: Thread ID for posting replies (e.g., `PRRT_xxx`)
- `path`: File path in the repository
- `line`, `startLine`: Line numbers in the file
- `comments.nodes`: Array of all comments in the thread

If no actionable threads are found (`totalCount: 0`), report that no action is needed.

### Step 2: Analyze Each Thread and Decide Action

For each thread, read all comments and examine the code context to decide the appropriate action.

1. **Read all comments**: Parse `comments.nodes` to understand the full conversation
2. **Examine the code**: Read the file at `path` around `line` to understand the context
3. **Analyze the codebase**: Use Grep and Glob to understand related patterns
4. **Decide action**: Choose one of:
   - **fix** - The concern is valid and can be addressed with a code change now
   - **new issue** - The concern is valid but requires broader changes, is out of scope for this PR, or needs further discussion
   - **won't fix** - The suggestion is a minor style preference, already addressed, or not applicable

### Step 3: Execute Actions

Process each thread according to its decided action. Track all actions taken for the summary.

#### Action: fix

1. Read the file and understand the issue
2. Make the necessary code changes using Edit or Write tools
3. Commit the change with a descriptive message:

```bash
git add <changed-files>
git commit -m "Fix: <brief description of the fix>

Addresses review comment on <file>:<line> in PR #$PR_NUMBER"
```

4. Record: file changed, line, brief description of fix

#### Action: new issue

Create a GitHub issue with context from the review thread:

```bash
gh issue create --title "<concise title describing the problem>" --body "$(cat <<EOF
## Context

Raised in review of PR #$PR_NUMBER

**File**: `<path>`
**Line**: <line>

## Problem

<description from the review comment>

## Suggested Approach

<any suggestions from the thread or initial thoughts on how to address>

---
*Issue created with [Claude Code](https://claude.ai/code) - github-devflow:fix*
EOF
)"
```

Record: issue number, issue URL, brief description

#### Action: won't fix

No code changes or issue creation needed. Record: brief reason why no action was taken.

### Step 4: Reply to Each Thread

After executing all actions, reply to each thread reporting what was done.

For **fix** actions:

```
Fixed in commit <sha>.

<brief description of the change made>
```

For **new issue** actions:

```
Created issue #<number> to track this.

<issue URL>
```

For **won't fix** actions:

```
No action taken: <brief explanation>
```

Post each reply using:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/reply/scripts/post-reply.sh --skill fix "<thread-id>" "<reply-body>"
```

Or for longer replies:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/reply/scripts/post-reply.sh --skill fix --file "<thread-id>" /tmp/reply.md
```

### Step 5: Push and Report Summary

Push all commits to the remote branch:

```bash
git push
```

Provide a summary of all actions taken:

- Total threads processed
- Number of fixes committed (with commit SHAs)
- Number of issues created (with issue numbers and URLs)
- Number of threads dismissed
- Any errors encountered

## Decision Guidelines

### When to "fix"

- Bug identified in the code
- Missing error handling or validation
- Incorrect logic or behavior
- Missing or wrong documentation in code
- Simple refactoring suggestions (rename, extract, simplify)

### When to "new issue"

- The fix requires changes outside this PR's scope
- Significant refactoring or architectural changes
- Performance improvements that need benchmarking
- Feature requests or enhancements
- Issues that need further discussion or design

### When to "won't fix"

- Pure style preferences with no functional impact
- The concern was already addressed in another commit
- The reviewer's suggestion contradicts project conventions
- Questions that were already answered in the thread
- Comments that are informational, not actionable

## Important Guidelines

### Commit Discipline

- One commit per fix for clear traceability
- Reference the PR number in each commit message
- Only stage files that were intentionally changed

### Code Quality

- Follow existing code patterns and conventions
- Make minimal, focused changes to address the specific concern
- Do not introduce unrelated changes alongside the fix

### Error Handling

- If `gh` CLI is not authenticated, inform the user to run `gh auth login`
- If the PR number is invalid, report the error clearly
- If a fix attempt fails, skip that thread, report the error, and continue with remaining threads
- If `git push` fails (e.g., due to branch protection rules or authentication), inform the user of the error and suggest manual resolution
- If posting a reply fails, report the error and continue

## Script Reference

### fetch-review-threads.sh

```
Usage: fetch-review-threads.sh <pr-number> [--filter-resolved] [--filter-skill <name>]

Options:
  --filter-resolved    Filter out resolved threads
  --filter-skill <name>  Filter out threads where the latest
                         comment contains the specified skill's signature
                         (github-devflow:<name>)

Output: JSON with repository info and thread array
```

### post-reply.sh

```
Usage: post-reply.sh [--skill <name>] <thread-id> <body>
       post-reply.sh [--skill <name>] --file <thread-id> <body-file>

Options:
  --skill <name>  Include skill identifier in signature
                  (e.g., --skill fix → "github-devflow:fix")

Arguments:
  thread-id   The GraphQL ID of the review thread (e.g., PRRT_xxx)
  body        The reply message text
  body-file   Path to a file containing the reply message

Note: Automatically appends a "Claude Code" signature to identify
      AI-generated replies for filtering in subsequent runs.

Output: JSON with success status and comment details
```
