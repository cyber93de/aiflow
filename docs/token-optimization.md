---
layout: default
title: Token optimization
parent: Concepts
nav_order: 2
description: "Cut AI coding agent token cost with aiflow: caveman terse output and rtk CLI-output filtering for Claude Code, the Copilot token-optimization guide, CodexSaver for Codex CLI, graph + RAG retrieval instead of reading files, and cheap/local model routing."
---

# Token optimization
{: .no_toc }

1. TOC
{:toc}

---

Context is the budget. Each agent gets its own approach — see
[Multi-Agent Support](multi-agent#token-savings-per-agent) for the quick per-agent summary; this
page covers every mechanism (Claude Code's caveman/rtk, Copilot's guide, Codex's CodexSaver, and
the agent-agnostic graph/RAG retrieval + model routing) in depth.

## Claude Code — caveman + rtk (on by default)

aiflow attacks Claude Code's token cost from four directions — the first two are **on by
default**. Prefer full, unfiltered output instead? Initialise or reconfigure with
`aiflow init --no-token-saving` / `aiflow change-settings --no-token-saving` — it switches
**caveman and rtk off** in one go.

**Honest expectation:** aiflow's quality rules (tests, coverage gates, static analysis, architect
review) deliberately *spend* tokens on getting things right — so per-task savings are only partial.
The net win is that a requirement implemented **production-ready on the first pass** needs no
re-prompting, no re-sharpening, and no rework: that saves more tokens *and time* than any filter.

### caveman — terse output

A compressed output mode: the agent drops filler and speaks tersely. **~75% fewer output tokens**;
code, commits, and security warnings stay in full prose. Toggle in `.aiflow/config.json`
(`caveman.enabled`, `caveman.mode: full|lite|ultra`).

### rtk — CLI-output filtering

Verbose command output (installs, test runs, build logs) is filtered/compressed **before it enters
context** — errors and diffs are preserved, noise is trimmed. Typically **60–90% fewer tokens** on
noisy commands. Enabled per project by aiflow.

## GitHub Copilot — the token-optimization guide

`agents.copilot` renders `.github/copilot-instructions.md` with the highest-ROI techniques from the
[GitHub Copilot token-optimization guide](https://github.com/olivomarco/github-copilot-token-optimization)
baked in: terse output control, "landmines only" context files (Copilot bills `AGENTS.md` /
`copilot-instructions.md` on every step, so only non-obvious constraints belong there), and
model/tool-set stability advice (switching models or tools mid-thread invalidates cache, costing
more tokens). No separate install — it's just how the file is written.

## OpenAI Codex CLI — CodexSaver (optional)

`codexsaver.enabled` (off by default, needs `agents.codex` + a provider API key) wires
[CodexSaver](https://github.com/fendouai/CodexSaver) in as an MCP server: it routes cheap/bounded
work (docs, tests, explanations, search) to a cheaper worker (Pi Agent by default, or a provider
like DeepSeek), keeping Codex itself for architecture, security, and final review. `aiflow
install-deps` clones and editable-pip-installs it (no published package); `apply.sh` owns
`.codex/config.toml` and appends CodexSaver's entry itself, so re-running `aiflow apply` never
clobbers or duplicates it.

## Graph + RAG retrieval instead of reading files

The biggest silent cost is re-reading whole files. aiflow routes questions through the
[code memory](memory): **graphify** (structure) and **cocoindex-code** (semantic RAG, ~70% fewer
tokens than opening files). The agent locates the few relevant chunks, then opens only those.

## Model routing — cheap/local for easy work

Send trivial/background steps to cheaper or **local Ollama** models via claude-code-router, keeping
top Claude models for hard reasoning:

```bash
aiflow shell --router
```

See [Models & context7](models).

## Measure first

```bash
aiflow cost      # ccusage: real token/cost baseline
```

Optimise what the numbers show, not what you guess. Combined, these routinely cut total token spend
by a large multiple on real projects.
