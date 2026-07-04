---
layout: default
title: Configuration
parent: CLI & Configuration
nav_order: 2
description: "Configure aiflow: .aiflow/config.json, CLAUDE.md operating rules, shared team preferences, and adding custom MCP servers for Claude Code."
---

# Configuration you should tune
{: .no_toc }

1. TOC
{:toc}

---

Everything is driven by **`.aiflow/config.json`** (committed, no secrets). Edit it interactively with
`aiflow change-settings` (re-renders `.mcp.json`, hooks, branching, memory) — switch version control
(git/svn), pick different Ollama models, or turn token saving off entirely with
`aiflow change-settings --no-token-saving`. Secrets always stay in `.env` (gitignored, never global).

![aiflow change-settings: switch vcs, pick Ollama models, disable token saving with --no-token-saving](assets/terminal/settings.gif)

## The files most worth tuning

- **`CLAUDE.md`** — the operating rules every agent reads (project overview, architecture hints, code
  style, task workflow, git rules, the memory/context stack, communication). **Fill the `[EDIT ME]`
  blocks** (§1 overview, §2 architecture) — this is the single biggest quality lever.
- **`.aiflow/team-prefs.json`** (the "preferences" file) — shared, versioned team/user preferences:
  code style preset, language, conventions. Committed so the team inherits them; overrides `CLAUDE.md §3`.
- **`.claude/memory/`** — `project-aim.md` (goal + architecture), `dev-environment.md`,
  `memory-policy.md` (the retrieval routing + learning intensity). Keep these current.
- **`.claude/settings.json`** — permissions (allow/deny), hooks (caveman, formatter, beads-sync),
  MCP allow-list.
- **`.aiflow/branching.json` / `docs/branching.md`** — the branching + release model.
- **`.env`** — all tokens/keys.

## `config.json` shape

```jsonc
{
  "caveman":  { "enabled": true, "mode": "full" },
  "rtk":      { "enabled": true },
  "router":   { "enabled": false },
  "graphify": { "enabled": true },
  "taskmaster": { "enabled": true },
  "mcp":      { "filesystem": true, "context7": true, "cocoindex": true },
  "memory":   { "enabled": true, "graph": true, "intensity": "aggressive" },
  "claude":   { "auth": "apikey" },
  "vcs":      { "system": "git" },
  "remote":   { "type": "github", "baseUrl": "https://github.com",
                "api": "github-api", "tokenEnv": "GITHUB_TOKEN", "mcp": "github" },
  "sync":     { "askOnClose": true, "pullOnStart": true },
  "ollama":   { "enabled": false, "url": "http://localhost:11434", "models": [] },
  "teamPrefs":{ "enabled": false, "codeStyle": "google" },
  "project":  { "aim": "…", "architecture": "…" },
  "dev":      { "os": "windows", "ide": "vscode" },
  "git":      { "model": "gitflow", "strict": true, "prOnly": true,
                "autoRelease": true, "versionStrategy": "semver", "releaseTags": true, "chore": true }
}
```

## Adding your own MCP servers

aiflow generates `.mcp.json` from the config, but you can add any extra MCP server — your edits to
servers aiflow doesn't manage are preserved on re-render:

```jsonc
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "@scope/my-mcp-server"],
      "env": { "MY_TOKEN": "${MY_TOKEN}" }   // secrets via .env, never inline
    }
  }
}
```

Then allow it in `.claude/settings.json` under `permissions.allow` (e.g. `"mcp__my-server"`) and put
any secret in `.env`. For community-vetted servers, browse `npx claude-code-templates@latest`.
Tip: prefer a focused MCP over a broad one — fewer tools = less context and fewer wrong turns.

## Tools are global, configuration is per-project

- **Tools / binaries** — installed once per user (`npm -g`, `uv tool`, brew/winget); shared across
  projects. `aiflow install-deps` puts them there; the router config lives in your home dir.
- **Configuration & secrets** — per project: `.env`, `.aiflow/config.json`, `CLAUDE.md`, `.mcp.json`,
  `.claude/`, `.githooks/`, memory. Switching projects switches config; nothing leaks between them.
