---
layout: default
title: Environment variables
parent: Reference
nav_order: 2
description: "aiflow .env reference: git host tokens (GitHub/GitLab/Bitbucket/custom), Anthropic API key vs Claude Code OAuth token, context7 key, and router provider keys."
---

# Environment variables (`.env`)
{: .no_toc }

1. TOC
{:toc}

---

All secrets live in `.env` — **gitignored, never global, never committed**. `aiflow shell` /
`aiflow ralph` load it. The git-host token is chosen by `remote.tokenEnv` in your config.

## Git host tokens (token-based, no OAuth)

| Variable | For |
|----------|-----|
| `GITHUB_TOKEN` | GitHub / GitHub Enterprise (PAT: repo + issues + pull_requests) |
| `GITLAB_TOKEN` | GitLab / self-managed GitLab (PAT with `api` scope) |
| `BITBUCKET_TOKEN` | Bitbucket (app password / token) |
| `GIT_REMOTE_TOKEN` | Forgejo / Gitea / custom host (rename to match `remote.tokenEnv`) |

## Claude access

| Variable | For |
|----------|-----|
| `ANTHROPIC_API_KEY` | pay-per-use API key (`claude.auth = apikey`) |
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code OAuth token from `claude setup-token` (`claude.auth = oauth`) |

Both are supported; the OAuth token wins if both are set.

## context7

| Variable | For |
|----------|-----|
| `CONTEXT7_API_KEY` | optional — raises context7 rate limits (it works keyless) |

## Cost/router providers (optional)

Used only with `router` enabled; keys can also live in `~/.claude-code-router/config.json`.

| Variable | For |
|----------|-----|
| `DEEPSEEK_API_KEY` | DeepSeek |
| `OPENROUTER_API_KEY` | OpenRouter |
| `GEMINI_API_KEY` | Google Gemini |

Ollama (local) needs **no key**.

## Ralph loop tuning

`RALPH_MAX_ITERATIONS`, `RALPH_TIMEOUT_SECONDS`, `RALPH_PERMISSION_MODE` (`acceptEdits` |
`bypassPermissions`).

See [Remote hosts](remotes) and [Models & context7](models).
