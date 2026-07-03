# Third-party components & licenses

**aiflow** is licensed under the [MIT License](LICENSE) © 2026 Cyber93de.

aiflow is an **integration / bootstrapper**: it does **not** vendor, bundle, or redistribute the
source code or binaries of the tools below. They are installed by the user through their own package
managers (npm, uv, Homebrew, winget, scoop, apt/dnf, official installers) or invoked at runtime
(e.g. via `npx`, `docker`/`podman`, or MCP). Each remains under its own license and copyright.
This file is provided for **attribution and transparency**; it is not a redistribution notice.

If you redistribute aiflow together with any of these tools' binaries or source, review and comply
with that tool's license directly.

## Runtime dependencies aiflow can install or invoke

| Component | Role in aiflow | License |
|-----------|----------------|---------|
| [Claude Code](https://docs.claude.com/en/docs/claude-code) (`@anthropic-ai/claude-code`) | the agent runtime | Proprietary — Anthropic Commercial Terms |
| [Beads](https://github.com/steveyegge/beads) (`bd`) | issue tracker / task memory | MIT |
| [Dolt](https://github.com/dolthub/dolt) | versioned SQL database backing Beads | Apache-2.0 |
| [graphify](https://github.com/safishamsi/graphify) | structural code knowledge graph (MCP) | MIT |
| [CocoIndex](https://github.com/cocoindex-io/cocoindex) + [cocoindex-code](https://github.com/cocoindex-io/cocoindex-code) (`ccc`) | semantic code RAG index (MCP) | Apache-2.0 |
| [Context7](https://github.com/upstash/context7) (`@upstash/context7-mcp`) | live library docs (MCP) | MIT |
| [claude-task-master](https://github.com/eyaltoledano/claude-task-master) | task decomposition | MIT **+ Commons Clause** (no-sell) |
| [claude-code-router](https://github.com/musistudio/claude-code-router) | model routing | MIT |
| [Ollama](https://github.com/ollama/ollama) | local model runtime | MIT |
| [rtk](https://github.com/rtk-ai/rtk) | CLI-output filtering | Apache-2.0 |
| [ccusage](https://github.com/ryoppippi/ccusage) | token/cost analytics | MIT |
| [jq](https://github.com/jqlang/jq) | JSON processor (reads config) | jq permissive license |
| [uv](https://github.com/astral-sh/uv) | installs graphify / cocoindex-code | Apache-2.0 OR MIT |
| MCP servers — [filesystem](https://github.com/modelcontextprotocol/servers), [github-mcp-server](https://github.com/github/github-mcp-server), [server-gitlab](https://github.com/modelcontextprotocol/servers), gitea/bitbucket MCPs | git-host + filesystem access | MIT (per project) |
| [GitHub CLI `gh`](https://github.com/cli/cli) / [GitLab CLI `glab`](https://gitlab.com/gitlab-org/cli) | host CLIs | MIT |
| [claude-code-templates](https://github.com/davila7/claude-code-templates) | optional config marketplace | MIT |

## Documentation site

The docs at `docs/` use the [just-the-docs](https://github.com/just-the-docs/just-the-docs) Jekyll
theme via `remote_theme` (**MIT**) — fetched at build time by GitHub Pages, not vendored in this repo.

## Notes

- **Commons Clause (task-master):** prohibits *selling* task-master itself or offering it as a hosted
  service. aiflow is free and MIT, invokes task-master as an external tool, and does not sell it — so
  this does not affect aiflow or its users. If you build a commercial hosted service, review it.
- **Anthropic Claude / Claude Code** are products of Anthropic under their commercial terms; aiflow is
  an independent project and is **not affiliated with or endorsed by** Anthropic or any listed project.
- Trademarks and project names belong to their respective owners.
