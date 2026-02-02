# GitHub Development Flow Plugins

A collection of Claude Code plugins for GitHub driven code development workflow.

## Overview

This repository contains plugins designed to streamline development workflows that center around GitHub Issues and Pull Requests. These plugins help bridge the gap between issue tracking and implementation by automating planning, documentation, and code review processes.

## Plugins

| Plugin | Description |
|--------|-------------|
| [github-issue-planner](./plugins/github-issue-planner) | Create implementation plans for GitHub issues and post them as comments |
| [github-issue-implementer](./plugins/github-issue-implementer) | Implement GitHub issues by following implementation plans and creating PRs |

## Installation

To use these plugins with Claude Code, add this repository as a plugin marketplace.

From within Claude Code, run:

```
/plugin marketplace add hhiroshell/gh-devflow-plugins
```

Then install plugins from the marketplace:

```
/plugin install github-issue-planner@gh-devflow-plugins
/plugin install github-issue-implementer@gh-devflow-plugins
```

## Recommended Workflow

These plugins work best together:

1. **Plan**: Use `/plan-issue <number>` to analyze an issue and generate an implementation plan
2. **Review**: Review and refine the plan on GitHub
3. **Implement**: Use `/implement-issue <number>` to implement the plan and create a PR

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated
- Must be run from within a git repository linked to GitHub

## Philosophy

GitHub driven development treats GitHub Issues as the source of truth for requirements and Pull Requests as the primary unit of work. These plugins support this workflow by:

- **Planning**: Analyzing issues and generating implementation plans before coding
- **Documentation**: Keeping discussions and decisions in GitHub where they belong
- **Automation**: Reducing manual steps between planning and implementation

## License

MIT
