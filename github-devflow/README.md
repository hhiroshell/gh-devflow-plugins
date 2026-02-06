# GitHub DevFlow

A Claude Code plugin for GitHub issue-driven development workflows. Plan and implement GitHub issues with structured workflows.

## Features

### Planning (`/plan`)

- Fetches GitHub issue details using `gh` CLI
- Analyzes your codebase to create context-aware implementation plans
- Generates structured plans with:
  - Overview and approach
  - Affected files
  - Implementation steps
  - Testing approach
  - Potential risks
- Posts the plan directly as an issue comment for review on GitHub

### Implementation (`/implement`)

- **Fetch Implementation Plans**: Reads implementation plans from GitHub issue descriptions, comments, and replies
- **Automated Implementation**: Implements code changes following the plan
- **PR Creation**: Creates a pull request with proper linking to the issue
- **Issue Updates**: Comments on the issue with PR link and adds status label

### Reply to PR Comments (`/reply`)

- Fetches unresolved review threads from a pull request
- Filters threads where the latest comment is from another user
- Analyzes comments with full codebase context
- Generates thoughtful replies addressing reviewer concerns
- Posts replies directly to the PR threads

### Multi-Perspective Code Review (`/code-review`)

- Reviews a PR from 8 different perspectives using specialized agents in parallel
- **Logic & Correctness**: Bugs, edge cases, error handling, race conditions
- **Design & Maintainability**: Code structure, naming, SOLID principles
- **Security**: Injection, auth issues, data exposure, OWASP concerns
- **Performance**: Algorithmic complexity, memory usage, N+1 queries
- **Convention Compliance**: CLAUDE.md and project convention adherence
- **Git History Context**: Git blame analysis, regression risk from commit history
- **PR History Context**: Past PR review comments and decisions on same files
- **Documentation**: Missing or outdated docs for changed code
- Aggregates all findings into a single GitHub PR review with line-specific comments

## Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated
- Git configured with push access to the repository
- Must be run from within a git repository linked to GitHub

## Installation

```
/plugin install github-devflow@gh-devflow-plugins
```

## Usage

### Plan an Issue

```
/plan <issue-number>
```

Example:
```
/plan 123
```

This will analyze issue #123, explore the codebase, generate an implementation plan, and post it as a comment on the issue.

### Implement an Issue

```
/implement <issue-number>
```

Example:
```
/implement 123
```

This will:
1. Fetch issue #123 and extract the implementation plan
2. Create a branch `issue-123`
3. Implement the changes based on the plan
4. Create a PR linked to the issue
5. Comment on the issue with the PR link
6. Add `implementation-started` label to the issue

### Review a PR

```
/code-review <pr-number>
```

Example:
```
/code-review 456
```

This will:
1. Fetch the PR diff and metadata
2. Dispatch 8 specialized reviewer agents in parallel (logic, design, security, performance, convention, git history, PR history, documentation)
3. Aggregate all findings into a single review
4. Post the review to GitHub with line-specific comments and a summary

### Reply to PR Comments

```
/reply <pr-number>
```

Example:
```
/reply 456
```

This will:
1. Fetch all review threads from PR #456
2. Filter for unresolved threads or threads where the latest comment is from another user
3. Analyze each comment with codebase context
4. Generate and post thoughtful replies to each thread

## Recommended Workflow

1. **Plan**: Use `/plan <number>` to analyze an issue and generate an implementation plan
2. **Review**: Review and refine the plan on GitHub
3. **Implement**: Use `/implement <number>` to implement the plan and create a PR
4. **Code Review**: Use `/code-review <pr-number>` to get a multi-perspective code review
5. **Reply**: Use `/reply <pr-number>` to respond to PR review comments

## Skills

| Skill | Description |
|-------|-------------|
| `/plan` | Create and post an implementation plan for a GitHub issue |
| `/implement` | Implement a GitHub issue following the plan and create a PR |
| `/reply` | Reply to unresolved review threads on a pull request |
| `/code-review` | Multi-perspective code review of a PR using 8 specialized agents |

## Troubleshooting

### "gh CLI requires authentication"

Run `gh auth login` to authenticate with GitHub.

### "No implementation plan found"

The `/implement` skill looks for implementation plans in the issue body and comments. Use `/plan` first to create a structured plan.

### "Cannot create label"

You may not have permission to create labels in the repository. The implementation will continue without the label.

## License

MIT
