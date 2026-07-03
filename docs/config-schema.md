---
layout: default
title: config.json schema
parent: Reference
nav_order: 1
description: "Reference for aiflow's .aiflow/config.json: caveman, rtk, router, graphify, cocoindex, context7, memory, claude auth, vcs, remote, sync, ollama, teamPrefs, git."
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
  "router":   { "enabled": false },                      // claude-code-router; auto-on with Ollama
  "graphify": { "enabled": true },                       // structural code graph MCP
  "taskmaster": { "enabled": false },                    // claude-task-master decomposition
  "mcp":      { "filesystem": true, "context7": true, "cocoindex": true },
  "memory":   { "enabled": true, "graph": true, "intensity": "aggressive" }, // off|light|normal|aggressive
  "claude":   { "auth": "apikey" },                      // apikey | oauth (OAuth wins if both env set)
  "vcs":      { "system": "git" },                       // git | svn | none
  "remote": {
    "type": "github",       // github|github-enterprise|gitlab|gitlab-self|bitbucket|forgejo|gitea|custom|none
    "baseUrl": "https://github.com",
    "api": "github-api",    // github-api|gitlab-api|bitbucket|gitea-api|generic
    "tokenEnv": "GITHUB_TOKEN",
    "mcp": "github"         // github|gitlab|bitbucket|forgejo|gitea|none (host MCP to wire)
  },
  "sync":     { "askOnClose": true, "pullOnStart": true },
  "ollama":   { "enabled": false, "url": "http://localhost:11434", "models": [] },
  "teamPrefs":{ "enabled": false, "codeStyle": "google" },
  "project":  { "aim": "…", "architecture": "…" },
  "dev":      { "os": "windows", "ide": "vscode" },
  "git":      { "model": "gitflow", "strict": true, "prOnly": true,
                "autoRelease": true, "versionStrategy": "semver", "releaseTags": true, "chore": true }
}
```

## What each field renders

| Field | Renders |
|-------|---------|
| `mcp.*` + `remote.mcp` | the servers in `.mcp.json` |
| `remote.*` | host MCP env (`GITHUB_HOST` / `GITLAB_API_URL` / `GITEA_URL`) + Beads owner/repo |
| `vcs.system` | git init / git hooks / branching (git only) |
| `memory.*` | `.claude/memory/memory-policy.md` (routing + learning intensity) |
| `ollama.*` + `router` | `.aiflow/router-config.json` (provider + background route) |
| `teamPrefs.*` | `.aiflow/team-prefs.json` |
| `sync.askOnClose` | `.aiflow/bd-close-sync.sh`; `sync.pullOnStart` → SessionStart auto-pull |
| `git.*` | `.aiflow/branching.json` + `docs/branching.md` + enforcement hooks |

## Back-compat

A legacy `.vcs` **string** (old host name) is still read as a fallback for `remote.type`.

See also [Configuration](configuration), [Environment variables](environment-variables),
[MCP servers](mcp-servers).
