---
layout: default
title: MCP servers
parent: Reference
nav_order: 3
description: "The Model Context Protocol (MCP) servers aiflow wires — for Claude Code, GitHub Copilot, and/or OpenAI Codex CLI: git-host MCP, filesystem, graphify code graph, cocoindex-code RAG, context7, task-master, GitKraken — and adding your own."
---

# MCP servers
{: .no_toc }

1. TOC
{:toc}

---

aiflow generates one MCP config **per enabled agent** (`.aiflow/config.json → agents.*`) from the
same server set — `.mcp.json` for Claude Code, `.codex/config.toml` for OpenAI Codex CLI,
`.vscode/mcp.json` for GitHub Copilot in VS Code. The **Model Context Protocol (MCP)** servers it
can wire:

| Server | Purpose | Enabled by |
|--------|---------|-----------|
| **git-host** (github / gitlab / bitbucket / gitea / forgejo) | issues, PRs/MRs on your host | `remote.mcp` |
| **GitKraken** | workspaces/PRs/issues via the `gk` CLI — a client, wired alongside any host | `gitkraken.enabled` |
| **filesystem** | safe structured file access | `mcp.filesystem` |
| **graphify** | structural code knowledge graph (imports/call-graph) | `graphify.enabled` |
| **cocoindex-code** | semantic code RAG search (`ccc mcp`) | `mcp.cocoindex` |
| **context7** | live, version-correct library docs | `mcp.context7` |
| **task-master** | goal/PRD → task decomposition | `taskmaster.enabled` |

The git-host MCP is chosen per `remote.type`, with the base URL threaded in (`GITHUB_HOST` /
`GITLAB_API_URL` / `GITEA_URL`) so enterprise/self-managed hosts work. Tokens come from `.env`
(`remote.tokenEnv`), referenced as `${VAR}` placeholders — Codex CLI/VS Code may expect a
different interpolation syntax; see [Multi-Agent Support](multi-agent) for the caveats per agent.

## Adding your own MCP server

Add an entry to `.mcp.json` — servers aiflow doesn't manage are preserved on re-render:

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
the secret in `.env`. Browse vetted servers with `npx claude-code-templates@latest`. Prefer a focused
MCP over a broad one — fewer tools = less context and fewer wrong turns.

See [Configuration](configuration) and the
[MCP servers ecosystem](https://github.com/modelcontextprotocol/servers).
