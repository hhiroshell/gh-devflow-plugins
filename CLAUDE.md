# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Claude Code plugins for GitHub-driven development workflows. The main plugin is `github-devflow`, which provides skills for planning, implementing, reviewing, fixing, and replying to GitHub issues and PRs.

## Repository Structure

```
gh-devflow-plugins/
├── github-devflow/           # Main plugin
│   ├── .claude-plugin/       # Plugin manifest (plugin.json with version)
│   ├── skills/               # User-invokable skills (SKILL.md files)
│   │   ├── plan/             # /plan - Create implementation plans for issues
│   │   ├── implement/        # /implement - Implement issues and create PRs
│   │   ├── reply/            # /reply - Reply to PR review threads
│   │   ├── fix/              # /fix - Fix code, create issues, or dismiss review comments
│   │   └── code-review/      # /code-review - Multi-perspective PR review
│   ├── scripts/              # Shared helper scripts (fetch-review-threads.sh, post-reply.sh)
│   └── agents/               # Specialized reviewer agents for code-review
└── .claude-plugin/           # Marketplace manifest (marketplace.json)
```

## Plugin Architecture

### Skills
Each skill has a `SKILL.md` with YAML frontmatter defining:
- `description`: Trigger conditions for the skill
- `argument-hint`: Expected argument format
- `allowed-tools`: Tools the skill can use
- `disable-model-invocation`: Whether to prevent autonomous model use

Skills use helper scripts in `scripts/` subdirectories for GitHub API operations via `gh` CLI.

### Agents
The `agents/` directory contains specialized reviewer agents used by `/code-review`. Each agent file (e.g., `logic-reviewer.md`) has frontmatter specifying:
- `model`: Which model to use (sonnet/haiku)
- `tools`: Available tools
- `color`: UI color for the agent

All agents output findings as JSON with a standard schema: `{perspective, findings: [{file, line, start_line?, severity, comment}]}`.

### Helper Scripts
Shell scripts in `scripts/` and `skills/code-review/scripts/` handle GitHub API interactions:
- Input validation (PR numbers, file paths)
- `gh` CLI calls for fetching/posting data
- JSON transformation with `jq`

Scripts validate file paths are within `/tmp/github-devflow:code-review/` for security.

## Development Notes

- All GitHub operations use the `gh` CLI (requires authentication via `gh auth login`)
- Most skills should not modify repository files directly; they analyze and post comments. Exceptions: `/implement` creates code and PRs, `/fix` makes code changes to address review feedback
- The `/code-review` skill launches 8 reviewer agents in parallel using the Task tool
- Review signatures include skill identifiers for filtering (e.g., `github-devflow:code-review`)
