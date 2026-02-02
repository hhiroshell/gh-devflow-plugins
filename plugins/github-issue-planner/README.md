# GitHub Issue Planner

A Claude Code plugin that creates implementation plans for GitHub issues and posts them as comments.

## Features

- Fetches GitHub issue details using `gh` CLI
- Analyzes your codebase to create context-aware implementation plans
- Generates structured plans with:
  - Overview and approach
  - Affected files
  - Implementation steps
  - Testing approach
  - Potential risks
- Posts the plan directly as an issue comment for review on GitHub

## Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated
- Must be run from within a git repository linked to GitHub

## Usage

```
/plan-issue <issue-number>
```

Example:
```
/plan-issue 123
```

## Installation

### As a local plugin

Copy this directory to your project's `.claude-plugin/` directory or use:

```bash
claude --plugin-dir /path/to/github-issue-planner
```

## Skills

| Skill | Description |
|-------|-------------|
| `/plan-issue` | Create and post an implementation plan for a GitHub issue |
