# gh-devflow-plugins

A collection of Claude Code plugins for GitHub driven code development workflow.

## Overview

This repository contains plugins designed to streamline development workflows that center around GitHub Issues and Pull Requests. These plugins help bridge the gap between issue tracking and implementation by automating planning, documentation, and code review processes.

## Plugins

| Plugin | Description |
|--------|-------------|
| [github-issue-planner](./plugins/github-issue-planner) | Create implementation plans for GitHub issues and post them as comments |

## Installation

To use these plugins with Claude Code, add this repository as a plugin source:

```bash
claude mcp add-json gh-devflow-plugins '{"type":"url","url":"https://raw.githubusercontent.com/hhiroshell/gh-devflow-plugins/main/.claude-plugin/marketplace.json"}'
```

Or install individual plugins directly:

```bash
claude --plugin-dir ./plugins/github-issue-planner
```

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
