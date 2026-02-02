# GitHub Issue Implementer

A Claude Code plugin that implements GitHub issues by following implementation plans and creating pull requests.

## Features

- **Fetch Implementation Plans**: Reads implementation plans from GitHub issue descriptions, comments, and replies
- **Automated Implementation**: Implements code changes following the plan
- **PR Creation**: Creates a pull request with proper linking to the issue
- **Issue Updates**: Comments on the issue with PR link and adds status label

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- Git configured with push access to the repository

## Installation

```bash
claude mcp add-from-claude-plugin-marketplace github-issue-implementer
```

## Usage

```
/implement-issue <issue-number>
```

### Example

```
/implement-issue 42
```

This will:
1. Fetch issue #42 and extract the implementation plan
2. Create a branch `issue-42`
3. Implement the changes based on the plan
4. Create a PR linked to the issue
5. Comment on the issue with the PR link
6. Add `implementation-started` label to the issue

## Workflow

This plugin works best when combined with [github-issue-planner](../github-issue-planner/), which creates implementation plans for issues:

1. Use `/plan-issue <number>` to create an implementation plan
2. Review and refine the plan on GitHub
3. Use `/implement-issue <number>` to implement the plan

## Configuration

### Label Name

The plugin adds the `implementation-started` label by default. If this label doesn't exist, it will be created automatically.

## Troubleshooting

### "gh CLI requires authentication"

Run `gh auth login` to authenticate with GitHub.

### "No implementation plan found"

The plugin looks for implementation plans in the issue body and comments. Consider using `github-issue-planner` to create a structured plan first.

### "Cannot create label"

You may not have permission to create labels in the repository. The implementation will continue without the label.

## License

MIT
