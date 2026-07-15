---
description: Creates an implementation plan for a GitHub issue and posts it as a comment. Triggered when the user provides a GitHub issue number for planning.
argument-hint: "<issue-number>"
disable-model-invocation: true
context: fork
agent: general-purpose
allowed-tools: Bash, Read, Grep, Glob, WebFetch
---

# GitHub Issue Implementation Planner

Create a structured implementation plan for a GitHub issue by analyzing the issue requirements and the codebase, then post the plan directly as a comment on the issue for review on GitHub.

## Workflow

### Step 1: Fetch Issue Details

Retrieve the GitHub issue information using the `gh` CLI:

```bash
gh issue view $ARGUMENTS --json title,body,labels,assignees,milestone,comments
```

Parse the response to understand:
- Issue title and description
- Labels (bug, feature, enhancement, etc.)
- Any linked PRs or related issues mentioned in the body
- **All comments**: Review the entire comment thread for:
  - Additional requirements or clarifications
  - Design decisions or constraints discussed
  - Feedback on previous approaches
  - Questions that need to be addressed in the plan

### Step 2: Detect Mode — Initial Plan vs. Replan

Search the comment thread for an existing plan comment posted by this skill (identified by the signature `github-devflow:plan` in the body).

**If an existing plan comment is found AND reviewer comments exist after it → Replan mode.**
Otherwise → Initial plan mode.

In replan mode, extract:
- The existing plan comment's **database ID** and its full body text
- All reviewer comments posted **after** the existing plan comment (these are the replan instructions)

To get a comment's database ID, list issue comments via the API:

```bash
gh api repos/{owner}/{repo}/issues/$ARGUMENTS/comments
```

### Step 3: Analyze Requirements

**Initial plan mode:**
Based on the issue requirements, explore the codebase to understand:

1. **Relevant files**: Use Glob and Grep to find files related to the issue
2. **Architecture**: Understand how the relevant components are structured
3. **Patterns**: Identify existing patterns that should be followed
4. **Dependencies**: Note any dependencies or related code that may be affected

Focus the analysis on areas directly relevant to the issue. Avoid broad codebase exploration unless necessary.

**Replan mode:**
Review all reviewer comments after the existing plan. Understand what changes are requested: new requirements, corrections, clarifications, or rejected approaches. Perform any additional codebase exploration needed to address the feedback.

### Step 4: Generate Implementation Plan

Create a structured implementation plan in Markdown format with these sections:

```markdown
## Implementation Plan for #<issue-number>

### Overview
Brief summary of the approach and key decisions.

### Affected Files
List of files that will need to be created or modified:
- `path/to/file1.ts` - Description of changes
- `path/to/file2.ts` - Description of changes

### Implementation Steps
1. **Step title**
   - Detailed description
   - Code patterns to follow

2. **Step title**
   - Detailed description
   - Code patterns to follow

### Testing Approach
- Unit tests to add
- Integration tests to consider
- Manual testing steps

### Potential Risks
- Risk 1 and mitigation
- Risk 2 and mitigation

---
*Plan generated with [Claude Code](https://claude.ai/code) - github-devflow:plan*
```

### Step 5: Post or Update the Plan

**Initial plan mode:**

Post the generated plan as a new comment:

```bash
gh issue comment $ARGUMENTS --body "<plan-content>"
```

**Replan mode:**

First, edit the original plan comment in-place with the updated plan:

```bash
gh api repos/{owner}/{repo}/issues/comments/<comment-id> \
  --method PATCH \
  --field body="<updated-plan-content>"
```

Then, post a follow-up comment that summarizes what changed between the old plan and the new plan:

```markdown
## Plan Updated

Revised the plan in response to reviewer feedback. Summary of changes:

### Added
- <description of newly added sections or steps>

### Changed
- <description of modified sections or steps, with before/after if helpful>

### Removed
- <description of removed sections or steps>

---
*Plan updated with [Claude Code](https://claude.ai/code) - github-devflow:plan*
```

After posting, report success with the issue URL so the user can review the plan on GitHub.

## Important Guidelines

### Issue Analysis
- Read the full issue description carefully
- **Review all comments** on the issue for additional context, clarifications, and evolving requirements
- Consider labels to understand issue type (bug vs feature)
- Check for any acceptance criteria or requirements mentioned
- Look for related issues or PRs mentioned
- Note any disagreements or open questions in the comment thread that may affect the plan

### Replan Detection
- Identify the existing plan comment by the `github-devflow:plan` signature in the comment body
- Only treat comments posted **after** the existing plan comment as reviewer feedback
- If multiple plan comments exist (e.g., from earlier replans), use the **most recent** one as the baseline

### Codebase Exploration
- Start with targeted searches based on issue keywords
- Look at similar existing implementations for patterns
- Check test files to understand testing conventions
- Review documentation for architectural guidance

### Plan Quality
- Be specific about file paths and changes
- Reference existing patterns in the codebase
- Include concrete code examples where helpful
- Identify potential edge cases and risks
- Keep the plan actionable and clear

### Error Handling
- If `gh` CLI is not authenticated, inform the user
- If issue number is invalid, report the error clearly
- If codebase analysis reveals blockers, include them in the plan
