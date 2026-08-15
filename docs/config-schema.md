---
layout: default
title: config.json schema
parent: Reference
nav_order: 1
description: "Reference for aiflow's .aiflow/config.json: caveman, rtk, ponytail, modelRouting, router, graphify, cocoindex, context7, memory, claude auth, vcs, remote, sync, ollama, teamPrefs, git."
---

# `.aiflow/config.json` schema
{: .no_toc }

1. TOC
{:toc}

---

`.aiflow/config.json` is the single source of truth. `aiflow init` writes it, `aiflow change-settings`
edits it, and `apply.sh` renders everything from it (idempotent). It contains **no secrets** — those
live in `.env`.

```jsonc
{
  "caveman":  { "enabled": true, "mode": "full" },      // full | lite | ultra
  "rtk":      { "enabled": true },                       // CLI-output filtering
  "ponytail": { "enabled": false, "mode": "full" },      // full | lite | ultra; YAGNI skill, off by default
  "router":   { "enabled": false },                      // claude-code-router; auto-on with Ollama
  "graphify": { "enabled": true },                       // structural code graph MCP
  "taskmaster": { "enabled": false },                    // claude-task-master decomposition
  "mcp":      { "filesystem": true, "context7": true, "cocoindex": true },
  "memory":   { "enabled": true, "graph": true, "intensity": "aggressive" }, // off|light|normal|aggressive
  "agents":   { "claude": true, "copilot": false, "codex": false }, // which coding agent(s) to render for
  "modelRouting": { "enabled": true,                     // per-activity model tiers (Claude Code only)
    "tiers":  { "reasoning": "opus", "implementation": "sonnet", "mechanical": "haiku" },
    "agents": { }                                        // optional: "<agent>": "<tier>" override
  },
  "claude":   { "auth": "apikey" },                      // apikey | oauth (OAuth wins if both env set)
  "vcs":      { "system": "git" },                       // git | svn | none
  "remote": {
    "type": "github",       // github|github-enterprise|gitlab|gitlab-self|bitbucket|forgejo|gitea|custom|none
    "baseUrl": "https://github.com",
    "api": "github-api",    // github-api|gitlab-api|bitbucket|gitea-api|generic
    "tokenEnv": "GITHUB_TOKEN",
    "mcp": "github"         // github|gitlab|bitbucket|forgejo|gitea|none (host MCP to wire)
  },
  "gitkraken": { "enabled": false },                     // GitKraken MCP (client, not a host — alongside remote.*)
  "codexsaver": { "enabled": false, "provider": "deepseek", "apiKeyEnv": "DEEPSEEK_API_KEY" }, // Codex CLI cost-aware MCP router
  "sync":     { "askOnClose": true, "pullOnStart": true },
  "ollama":   { "enabled": false, "url": "http://localhost:11434", "models": [] },
  "teamPrefs":{ "enabled": false, "codeStyle": "google" },
  "project":  { "aim": "…", "architecture": "…" },
  "dev":      { "os": "windows", "ide": "vscode" },
  "git":      { "model": "gitflow", "strict": true, "prOnly": true,
                "autoRelease": true, "versionStrategy": "semver", "releaseTags": true, "chore": true },
  "meta":     { "aiflowVersion": "0.2.0" }                // stamped at init; drives the project-update prompt
}
```

## What each field renders

| Field | Renders |
|-------|---------|
| `agents.*` | which per-agent files get rendered: `.mcp.json`/`.claude/*` (claude), `.vscode/mcp.json`+`.github/copilot-instructions.md` (copilot), `.codex/config.toml` (codex) |
| `modelRouting.enabled` | stamps/strips `model: <id>` on every subagent per activity tier — reasoning (architect/planner/reviewer/security/requirements/modernization/orchestrator), implementation (implementer/tester/quality-check/a11y), mechanical (docs-sync/test-gap/dependency/performance/onboarder). Claude Code only. See [Models](models#model-tiers-per-activity-subagent-routing) |
| `modelRouting.tiers.*` | model id per tier (`reasoning`/`implementation`/`mechanical`); defaults `opus`/`sonnet`/`haiku`. Hand-edited — `aiflow change-settings` preserves it |
| `modelRouting.agents.*` | `"<agent-name>": "<tier>"` — moves a single subagent to another tier |
| `ponytail.enabled`/`.mode` | gates the ponytail skill's decision ladder (self-checked at invocation, not file-rendered) |
| `mcp.*` + `remote.mcp` + `gitkraken.enabled` | the servers in `.mcp.json` (and the enabled agents' equivalents) |
| `remote.*` | host MCP env (`GITHUB_HOST` / `GITLAB_API_URL` / `GITEA_URL`) + Beads owner/repo + the matching predefined release-publish workflow (`.github/workflows/release.yml`, `.gitlab-ci.yml`, `.gitea/workflows/release.yml`, `.forgejo/workflows/release.yml`, `bitbucket-pipelines.yml`) |
| `vcs.system` | git init / git hooks / branching (git only) |
| `memory.*` | `.claude/memory/memory-policy.md` (routing + learning intensity) |
| `ollama.*` + `router` | `.aiflow/router-config.json` (provider + background route) |
| `teamPrefs.*` | `.aiflow/team-prefs.json` |
| `sync.askOnClose` | `.aiflow/bd-close-sync.sh`; `sync.pullOnStart` → SessionStart auto-pull |
| `git.*` | `.aiflow/branching.json` + `docs/branching.md` + enforcement hooks |
| `dev.os` | which interpreter (`bash`/PowerShell) the rendered Claude Code hook commands use |
| `meta.aiflowVersion` | compared against the installed CLI on every `aiflow` run; prompts `aiflow project-update` when behind |

## Back-compat

A legacy `.vcs` **string** (old host name) is still read as a fallback for `remote.type`.

See also [Configuration](configuration), [Environment variables](environment-variables),
[MCP servers](mcp-servers).
