# GitHub Development Flow Plugins

A collection of Claude Code plugins for GitHub driven code development workflow.

## Overview

This repository contains plugins designed to streamline development workflows that center around GitHub Issues and Pull Requests. These plugins help bridge the gap between issue tracking and implementation by automating planning, documentation, and code review processes.

## Plugins

| Plugin | Description |
|--------|-------------|
| [github-devflow](./plugins/github-devflow) | Plan and implement GitHub issues with structured workflows for issue-driven development |

## Installation

To use these plugins with Claude Code, add this repository as a plugin marketplace.

From within Claude Code, run:

```
/plugin marketplace add hhiroshell/gh-devflow-plugins
```

Then install the plugin from the marketplace:

```
/plugin install github-devflow@gh-devflow-plugins
```

## Recommended Workflow

The plugin provides two skills that work best together:

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
