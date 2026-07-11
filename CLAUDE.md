# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Claude Code plugins for GitHub-driven development workflows. The main plugin is `github-devflow`, which provides skills for planning, implementing, reviewing, fixing, and replying to GitHub issues and PRs.

## Repository Structure

```
gh-devflow-plugins/
├── .claude-plugin/               # Marketplace manifest (marketplace.json)
├── .github/
│   └── workflows/
│       └── release.yml           # Release automation (tag → GitHub Release)
└── github-devflow/               # Main plugin
    ├── .claude-plugin/           # Plugin manifest (plugin.json with version)
    ├── agents/                   # Specialized reviewer agents for code-review
    ├── scripts/                  # Shared helper scripts (fetch-review-threads.sh, post-reply.sh)
    └── skills/                   # User-invokable skills (SKILL.md files)
        ├── plan/                 # /plan - Create implementation plans for issues
        ├── implement/            # /implement - Implement issues and create PRs
        ├── reply/                # /reply - Reply to PR review threads
        ├── fix/                  # /fix - Fix code, create issues, or dismiss review comments
        ├── watch/                # /watch - Watch a PR for AI-reviewer comments and auto reply+fix in a loop
        │   └── scripts/          # Skill-specific scripts (watch-pr-comments.sh)
        └── code-review/          # /code-review - Multi-perspective PR review
            └── scripts/          # Skill-specific scripts (fetch-pr-diff.sh, post-review.sh)
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
Shell scripts handle GitHub API interactions via the `gh` CLI:
- **Shared scripts** (`github-devflow/scripts/`): `fetch-review-threads.sh` (fetch PR threads with filtering), `post-reply.sh` (post replies with skill signatures)
- **Code-review scripts** (`github-devflow/skills/code-review/scripts/`): `fetch-pr-diff.sh` (fetch PR diff and metadata), `post-review.sh` (post reviews with line-specific comments)

Scripts validate file paths are within `/tmp/github-devflow:*/` for security.

## Development Notes

- All GitHub operations use the `gh` CLI (requires authentication via `gh auth login`)
- Most skills should not modify repository files directly; they analyze and post comments. Exceptions: `/implement` creates code and PRs, `/fix` makes code changes to address review feedback
- The `/code-review` skill launches 8 reviewer agents in parallel using the Task tool
- Review signatures include skill identifiers for filtering (e.g., `github-devflow:code-review`)

## Release Flow

Releases are automated via `.github/workflows/release.yml`. Claude Code uses `plugin.json` `.version` as a cache key, so each release must have a unique version and `main` must always differ from any released version.

### Version strategy
- `github-devflow/.claude-plugin/plugin.json` `.version` — authoritative version (cache key). Set to `X.Y.Z` on release tags, `X.(Y+1).0-dev` on `main` between releases.
- `.claude-plugin/marketplace.json` `.plugins[0].source.ref` — ref-based source pinned to the latest release tag (e.g., `v0.5.0`). No `version` field; version is determined by `plugin.json` at the ref'd commit.

### How to release
1. Run `./scripts/release.sh <version>` (e.g., `./scripts/release.sh 0.5.0`)
   - Sets `plugin.json` version to `0.5.0` and `marketplace.json` ref to `v0.5.0`
   - Commits and tags `v0.5.0`
   - Bumps `plugin.json` to `0.6.0-dev`, commits
   - Pushes `main` and the tag
2. The GitHub Actions workflow validates that `plugin.json` version matches the tag and `marketplace.json` ref matches the tag name, then creates a GitHub Release with auto-generated notes
