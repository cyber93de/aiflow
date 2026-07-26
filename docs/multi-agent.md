---
layout: default
title: Multi-Agent Support
parent: Agents & Workflows
nav_order: 3
description: "aiflow is agent-agnostic: a shared AGENTS.md plus per-tool MCP config for Claude Code, GitHub Copilot, and OpenAI Codex CLI. What's shared, what's Claude Code-only, and how to pick which agent(s) a project targets."
---

# Multi-agent support
{: .no_toc }

1. TOC
{:toc}

---

aiflow started as a Claude Code integration and still gives Claude Code the deepest feature set —
but the project rules, quality gates, task workflow, and git/branching model are useful to *any*
coding agent working in the repo. As of the config's `agents` key, aiflow renders what it can for
**GitHub Copilot** and **OpenAI Codex CLI** too, from the same `.aiflow/config.json`.

## Picking your agent(s)

`aiflow init` / `aiflow change-settings` ask three yes/no questions — pick as many as you actually
use, they're not mutually exclusive:

| Agent | Config key | What gets rendered |
|-------|-----------|---------------------|
| Claude Code | `agents.claude` (default **on**) | `.mcp.json`, `.claude/agents/*`, `.claude/commands/*`, hooks in `.claude/settings.json`, the Ralph loop |
| GitHub Copilot | `agents.copilot` (default off) | `.github/copilot-instructions.md` (points to `AGENTS.md`), `.vscode/mcp.json` |
| OpenAI Codex CLI | `agents.codex` (default off) | `.codex/config.toml` (`[mcp_servers.*]` tables) — Codex reads `AGENTS.md` directly, no pointer file needed |

Re-run `aiflow change-settings` any time to add or drop an agent; it re-renders every file above,
idempotently.

## The shared foundation: `AGENTS.md`

**`AGENTS.md`** at the repo root is the single, agent-agnostic source of truth: code style
(§3), quality gates (§3a/§3b/§3c), the Beads task workflow (§4), git/branching rules (§7),
memory conventions (§8), and the Definition of Done (§10). Every agent should read it before
touching the repo.

- **Claude Code** reads `CLAUDE.md`, which is a one-line pointer — `@AGENTS.md` — using
  [Claude Code's native memory-import syntax][claude-memory]. Edit `AGENTS.md`, never `CLAUDE.md`;
  the pointer file exists purely so Claude Code's default lookup finds something.
- **OpenAI Codex CLI** reads `AGENTS.md` directly — that convention is the reason the file is
  named `AGENTS.md` in the first place, no pointer needed.
- **GitHub Copilot** reads `.github/copilot-instructions.md`, which is a short file telling
  Copilot to read `AGENTS.md` for the actual rules.

Sections in `AGENTS.md` marked **(Claude Code only)** — §5 (subagents), §6 (the Ralph loop), the
`rtk`/caveman output-shaping in §9 — describe automation that only Claude Code can dispatch
in-session. Every other agent still follows the *same* workflow and rules manually, step by step;
it just doesn't get the automatic dispatch. Concretely: where Claude Code runs `/review-ac` to
invoke the `reviewer` subagent, a Copilot or Codex session (or the human driving it) reads
`AGENTS.md` §3a/§5 and performs that same architecture + quality-gate pass itself.

## What stays Claude Code-only (and why)

| Feature | Why it doesn't carry over (yet) |
|---------|----------------------------------|
| Subagents (`.claude/agents/*`) | Copilot/Codex have no equivalent "dispatch a specialised subagent with its own tool scope" mechanism today. |
| Slash-commands (`/review-ac`, `/implement`, `/ralph-loop`, …) | Tool-specific command surface; not portable syntax. |
| Hooks (`.claude/settings.json` — format/lint/test/beads-sync on tool use) | Claude Code's hook system has no direct Copilot/Codex equivalent. |
| Ralph loop autonomous iteration | Built around Claude Code's session/subagent model. |
| caveman / rtk output shaping | Claude Code-specific output filters for token savings. |

None of this blocks Copilot/Codex from doing the *work* — the underlying rules (code style,
tests, git hygiene, branching, Beads) are tool-agnostic and described in plain language in
`AGENTS.md` precisely so any capable agent can follow them without the Claude Code machinery.

## MCP servers per agent

`.aiflow/config.json`'s `mcp.*`, `remote.mcp`, and `gitkraken.enabled` describe one logical set of
MCP servers (filesystem, the git-host MCP, graphify, cocoindex-code, context7, GitKraken, …).
`apply.sh` renders that same set into whichever agent-specific format(s) you enabled:

- **Claude Code** — `.mcp.json` (the format Claude Code reads natively).
- **Codex CLI** — `.codex/config.toml`, `[mcp_servers.<name>]` TOML tables. Codex CLI's own MCP
  config commonly lives in `~/.codex/config.toml` (global) — check whether your Codex version
  picks up a project-local file, or merge this generated file into the global one.
- **Copilot (VS Code)** — `.vscode/mcp.json`, `{"servers": {...}}`. VS Code's MCP config schema
  evolves — if a server doesn't load, check the current VS Code docs for the exact shape/`env`
  interpolation syntax expected.

Token/secret values are written as `${VAR}` placeholders resolved from `.env` — this is aiflow's
own convention (matching how Claude Code's `.mcp.json` resolves them) and may need adjusting to
whatever environment-variable syntax your Codex/Copilot version actually supports.

## Branching, releases, and CI

The gitflow branching model, the `pre-push` governance hook, `aiflow hotfix`/`aiflow release`, and
the predefined release-publish workflows (GitHub/GitLab/Gitea/Forgejo/Bitbucket) are all plain git
and shell — they work identically no matter which agent (or human) is driving the commits. See
[Workflows & CI/CD](workflows).

[claude-memory]: https://docs.claude.com/en/docs/claude-code/memory
