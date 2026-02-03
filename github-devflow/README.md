# GitHub DevFlow

A Claude Code plugin for GitHub issue-driven development workflows. Plan and implement GitHub issues with structured workflows.

## Features

### Planning (`/plan-issue`)

- Fetches GitHub issue details using `gh` CLI
- Analyzes your codebase to create context-aware implementation plans
- Generates structured plans with:
  - Overview and approach
  - Affected files
  - Implementation steps
  - Testing approach
  - Potential risks
- Posts the plan directly as an issue comment for review on GitHub

### Implementation (`/implement-issue`)

- **Fetch Implementation Plans**: Reads implementation plans from GitHub issue descriptions, comments, and replies
- **Automated Implementation**: Implements code changes following the plan
- **PR Creation**: Creates a pull request with proper linking to the issue
- **Issue Updates**: Comments on the issue with PR link and adds status label

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
/plan-issue <issue-number>
```

Example:
```
/plan-issue 123
```

This will analyze issue #123, explore the codebase, generate an implementation plan, and post it as a comment on the issue.

### Implement an Issue

```
/implement-issue <issue-number>
```

Example:
```
/implement-issue 123
```

This will:
1. Fetch issue #123 and extract the implementation plan
2. Create a branch `issue-123`
3. Implement the changes based on the plan
4. Create a PR linked to the issue
5. Comment on the issue with the PR link
6. Add `implementation-started` label to the issue

## Recommended Workflow

1. **Plan**: Use `/plan-issue <number>` to analyze an issue and generate an implementation plan
2. **Review**: Review and refine the plan on GitHub
3. **Implement**: Use `/implement-issue <number>` to implement the plan and create a PR

## Skills

| Skill | Description |
|-------|-------------|
| `/plan-issue` | Create and post an implementation plan for a GitHub issue |
| `/implement-issue` | Implement a GitHub issue following the plan and create a PR |

## Troubleshooting

### "gh CLI requires authentication"

Run `gh auth login` to authenticate with GitHub.

### "No implementation plan found"

The `/implement-issue` skill looks for implementation plans in the issue body and comments. Use `/plan-issue` first to create a structured plan.

### "Cannot create label"

You may not have permission to create labels in the repository. The implementation will continue without the label.

## License

MIT
