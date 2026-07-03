---
layout: default
title: FAQ
parent: Support
nav_order: 1
description: "Frequently asked questions about aiflow: Claude API key vs OAuth, offline/private use, graphify vs cocoindex, adding models, GitLab/self-hosted, and team use."
---

# FAQ
{: .no_toc }

1. TOC
{:toc}

---

**Do I need an Anthropic API key?**
Either an API key *or* a Claude Code OAuth token (`claude setup-token`) — pick `claude.auth` at init.

**Does it work offline / privately?**
Code indexing (cocoindex-code) and embeddings are **local** (no key). With Ollama you can run models
locally too. Claude itself still calls Anthropic.

**Is my data sent anywhere?**
Secrets stay in `.env` (gitignored, never global). Only what Claude needs for a request goes to
Anthropic (or your local models via the router).

**graphify vs cocoindex — do I need both?**
They're complementary: graphify answers *structural* questions exactly; cocoindex answers
*semantic/fuzzy* ones cheaply. Both are recommended — see [Memory](memory).

**How do I add another model?**
Ollama: `aiflow ollama add <model>`. Cloud: add it to `~/.claude-code-router/config.json` and enable
`router` — see [Models](models).

**How do I use GitLab / Bitbucket / self-hosted instead of GitHub?**
`aiflow change-settings` → pick the remote type (or `custom` + base URL) → put the token in `.env`.
See [Remote hosts](remotes).

**Can several people work in one project?**
Yes — that's a core feature: shared Dolt issue DB, atomic claim, session-start pull, pull-before-push.
See [Team collaboration](team).

**How do I change my mind later?**
`aiflow change-settings` re-runs the Q&A and re-renders `.mcp.json`, hooks, branching, and memory.

**Do I have to pre-install tools?**
No. The installer offers git/svn/ollama; `aiflow install-deps` (or `aiflow init`) installs the rest.

**Something references the wrong git host / token?**
Re-run `aiflow change-settings`; check `.env` has the token env named in `remote.tokenEnv`;
`aiflow doctor` shows the resolved config.

**Windows or macOS or Linux?**
All three. On Windows, install via `install.ps1`; the CLI also works in Git-Bash.

## Troubleshooting quick hits

- **`jq is required`** — install jq (`aiflow install-deps` does).
- **`bd`/Dolt errors** — `aiflow install-deps` installs both; `bd dolt status` checks the server.
- **MCP server won't start** — `aiflow doctor`; confirm the tool is installed (`ccc`, `graphify`,
  Docker for the GitHub MCP) and the token env in `.env` matches `remote.tokenEnv`.
- **Ollama models unused** — enable `router`, run `aiflow shell --router`; confirm
  `.aiflow/router-config.json` lists them and `ollama list` has them.
- **Dolt sync conflict** — `bd dolt pull` (merge), resolve, then `bd dolt push`. Never force-push.
