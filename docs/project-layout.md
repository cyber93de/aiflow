---
layout: default
title: Project layout
parent: Reference
nav_order: 4
description: "The files aiflow generates in a Claude Code project: .aiflow config, .beads issues, .claude agents/hooks/memory, .githooks, .mcp.json, CLAUDE.md, and .env."
---

# Project layout
{: .no_toc }

What `aiflow init` puts in a project and what each piece does.

```
your-project/
├─ .aiflow/
│  ├─ config.json            # the single source of truth (committed)
│  ├─ team-prefs.json        # shared team preferences (committed)
│  ├─ router-config.json     # generated: Ollama/cost providers (gitignored)
│  ├─ bd-close-sync.sh       # close → prompt push + Dolt-sync
│  └─ *.sh                   # audit/release/ralph helpers
├─ .beads/                   # Beads issue database (Dolt)
├─ .claude/
│  ├─ agents/  commands/     # subagents + slash commands
│  ├─ hooks/                 # caveman, formatter, beads-sync (SessionStart auto-pull)
│  ├─ memory/                # project-aim, dev-environment, memory-policy
│  └─ settings.json          # permissions + hooks + MCP allow-list
├─ .githooks/                # commit-msg, pre-commit, pre-push (enforcement)
├─ docker/                   # Dockerfile + run.sh (Podman or Docker) for headless Ralph runs
├─ docs/architecture/        # arc42 + ADRs
├─ .mcp.json                 # generated from config (host MCP, filesystem, graphify, cocoindex, context7)
├─ CLAUDE.md                 # operating rules every agent reads
└─ .env                      # secrets (gitignored, never global)
```

## Tools are global, configuration is per-project

- **Tools / binaries** — installed once per user (`npm -g`, `uv tool`, winget/scoop/brew); shared
  across projects.
- **Configuration & secrets** — per project; switching projects switches everything, and nothing
  leaks between them.

See [Configuration](configuration) and [config.json schema](config-schema).
