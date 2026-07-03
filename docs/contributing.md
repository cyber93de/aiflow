---
layout: default
title: Feedback & contributing
parent: Support
nav_order: 3
description: "Share ideas, criticism, and bug reports for aiflow; credits and thanks to Claude Code, Beads, graphify, CocoIndex, Context7, Ollama, rtk, and more; how to contribute."
---

# Feedback, ideas & contributing
{: .no_toc }

1. TOC
{:toc}

---

## We're open to your ideas

**This project lives on your input — and it's very welcome.** Whether it's a rough idea, a feature
wish, a "why does it work like that?", or straight-up criticism: bring it on. Honest feedback is how
aiflow gets better.

- 💡 **Ideas & suggestions** — open a
  [GitHub Discussion](https://github.com/Cyber93de/aiflow/discussions) or an
  [issue](https://github.com/Cyber93de/aiflow/issues). No idea is too small or too wild.
- 🗣️ **Criticism welcome** — tell us what's confusing, clunky, or missing. Disagreement is useful.
- 🐛 **Bug reports** — open an [issue](https://github.com/Cyber93de/aiflow/issues) with steps to
  reproduce, your OS, and the relevant `aiflow doctor` output. A small repro = a fast fix.
- 🙌 **Support** — if aiflow helps you, a ⭐ on the repo, a shared link, or a kind word genuinely
  makes the day. Thank you for being here.

There is **no paid tier and no donation ask** — the best support is your feedback, a star, and
telling a friend.

## Contributing code

Issues and PRs welcome at [github.com/Cyber93de/aiflow](https://github.com/Cyber93de/aiflow). aiflow
dogfoods itself: it uses Beads for its own tasks, Conventional Commits, and the CI workflow
(`bash -n`, shellcheck, JSON + PowerShell validation) must pass. Keep changes project-scoped and
secret-free, and follow the Google style aiflow enforces on itself.

## Credits & thanks

aiflow is glue. Enormous thanks to the projects it stands on — please star and support them:

- **[Claude Code](https://docs.claude.com/en/docs/claude-code)** (Anthropic) — the agent runtime everything builds on.
- **[Beads](https://github.com/steveyegge/beads)** — Dolt-backed issue tracker; durable task memory across sessions.
- **[Dolt](https://github.com/dolthub/dolt)** (DoltHub) — the versioned SQL database that makes team issue-sync work.
- **[graphify](https://github.com/safishamsi/graphify)** — the structural code knowledge graph over MCP.
- **[CocoIndex](https://github.com/cocoindex-io/cocoindex)** & **[cocoindex-code](https://github.com/cocoindex-io/cocoindex-code)** — the incremental, AST-aware semantic RAG index (`ccc`).
- **[Context7](https://github.com/upstash/context7)** (Upstash) — live, version-correct library docs over MCP.
- **[claude-task-master](https://github.com/eyaltoledano/claude-task-master)** — goal/PRD → task tree.
- **[claude-code-router](https://github.com/musistudio/claude-code-router)** — model routing for cost/local models.
- **[Ollama](https://ollama.com)** — local model runtime (no API key).
- **[rtk](https://www.rtk-ai.app/)** — CLI-output filtering to cut context.
- **[ccusage](https://github.com/ryoppippi/ccusage)** — token/cost analytics.
- **[claude-code-templates](https://github.com/davila7/claude-code-templates)** — community agents/commands/MCPs/hooks.
- **[Model Context Protocol](https://github.com/modelcontextprotocol/servers)** — the MCP servers ecosystem.

Trademarks and projects belong to their respective owners; aiflow is an independent integration and
is not affiliated with or endorsed by them.

## License

**MIT** — Copyright (c) 2026 Cyber93de. See [LICENSE](https://github.com/Cyber93de/aiflow/blob/main/LICENSE).
