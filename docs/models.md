---
layout: default
title: Models & context7
parent: CLI & Configuration
nav_order: 4
description: "Claude access (API key or OAuth), Ollama local models (qwen3-coder), adding more models via claude-code-router, and context7 live library docs — context7 wires as an MCP server for Claude Code, GitHub Copilot, or OpenAI Codex CLI."
---

# Claude access, Ollama, more models & context7
{: .no_toc }

1. TOC
{:toc}

---

## Claude access

`.aiflow/config.json → claude.auth` (both supported; OAuth wins if both are set):

- `apikey` → `ANTHROPIC_API_KEY` (pay-per-use, [console.anthropic.com](https://console.anthropic.com)).
- `oauth` → run `claude setup-token` → `CLAUDE_CODE_OAUTH_TOKEN` (uses your Claude plan).

Both live in `.env` (gitignored, never global).

## Model tiers per activity (subagent routing)

Thinking-heavy work gets a strong model; mechanical work does not. `.aiflow/config.json →
modelRouting` (default **on**) stamps the right model into each subagent's frontmatter whenever
`aiflow apply` runs — Claude Code only, no external router involved.

| Tier | Default model | Subagents | Why |
|------|---------------|-----------|-----|
| `reasoning` | **opus** (set `fable` if you prefer) | `architect`, `planner`, `reviewer`, `security-advisor`, `requirements-check`, `modernization-advisor`, `orchestrator` | Architecture, concepts, decomposition, review and security analysis are where a wrong call is expensive and long-lived. |
| `implementation` | **sonnet** | `implementer`, `tester`, `quality-check`, `accessibility-checker` | Bounded work with explicit acceptance criteria to check against. |
| `mechanical` | **haiku** | `docs-sync`, `test-gap-advisor`, `dependency-auditor`, `performance-advisor`, `onboarder` | Pattern-matching and enumeration — CI-grade checks, no design judgement. |

Override the model per tier, or move a single agent to another tier:

```jsonc
{
  "modelRouting": {
    "enabled": true,
    "tiers":  { "reasoning": "fable", "implementation": "sonnet", "mechanical": "haiku" },
    "agents": { "implementer": "reasoning" }   // this one agent gets the reasoning model
  }
}
```

With `"enabled": false` every subagent runs on the session's model and the `model:` lines are
stripped again. Toggle with `aiflow change-settings`; `tiers`/`agents` are hand-edited and survive
that (they are carried over, not rebuilt).

**Escalate, never silently downgrade:** if a "simple" task turns out to touch the architecture, it
*is* architecture work — move it up a tier. Copilot and Codex have no subagents; pick the
equivalent model manually and keep it stable within a thread.

## Ollama (local, no API key)

Enable at `aiflow init`, or manage any time:

```bash
aiflow ollama add qwen3-coder     # add a model to config + pull it
aiflow ollama pull                # pull every model listed in config
aiflow ollama list                # what's installed
```

`qwen3-coder` (newest Qwen) is the recommended default. Selected models are written into
`.aiflow/router-config.json` as a provider, so they're actually used for easy/background work:

```bash
aiflow shell --router             # routes cheap/background steps to local models
```

## Adding more / cloud models

For DeepSeek, OpenRouter, Gemini, and other providers:

1. Add the provider + key to `~/.claude-code-router/config.json` (never committed).
2. Enable `router` in `.aiflow/config.json`.
3. Optional keys can also live in `.env` (`DEEPSEEK_API_KEY`, `OPENROUTER_API_KEY`, `GEMINI_API_KEY`).

Route trivial/background steps to cheap models; keep top Claude models for hard reasoning. Measure
the effect with `aiflow cost`.

## context7 — live library docs

**context7** is an MCP server that fetches **live, version-correct documentation** for the libraries
you use, so the agent codes against the real current API instead of a stale memory. Enabled by
default (`mcp.context7`).

- In a session, just ask normally ("use the latest `zod` schema API") — the agent calls context7 to
  pull current docs. You can also nudge it: *"check context7 for the current Prisma migrate API"*.
- Works **keyless**; a `CONTEXT7_API_KEY` in `.env` raises rate limits.
- Pair it with the code indexes: **context7** = *external* library docs, **graphify/cocoindex** =
  *your* code. See [Memory](memory).
