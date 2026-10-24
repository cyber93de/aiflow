---
layout: default
title: Token optimization
parent: Concepts
nav_order: 2
description: "Reduce context and token use across agents with concise shared instructions, progressive-disclosure skills, focused file reads, optional retrieval MCPs and agent-specific token tools."
---

# Token optimization
{: .no_toc }

1. TOC
{:toc}

---

Context is the budget. All agents share a low-overhead baseline: compact always-loaded instructions,
task-loaded skills, targeted reads, and optional MCPs that stay disabled unless useful. Extra output
filters and model routing are tool-specific; they are not assumed to work across agents.

## Shared baseline and optional Claude tools

aiflow's shared baseline applies to every agent. Claude-only output tools can be enabled during
initialization or settings changes. Prefer full, unfiltered output instead? Initialise or reconfigure with
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

The biggest silent cost is re-reading whole files. On larger projects, enable **graphify** (structure)
or **cocoindex-code** (semantic search) in settings and use them to locate relevant files before
opening targeted chunks. Both are opt-in because their setup and tool context do not pay off for
every repository. Treat retrieval as navigation, then verify claims against source files.

## Model routing — cheap/local for easy work

Send trivial/background steps to cheaper or **local Ollama** models via claude-code-router, keeping
top Claude models for hard reasoning:

```bash
aiflow shell --router
```

See [Models & context7](models).

## Model tiers per subagent (Claude Code only)

A separate, always-available mechanism from the router above — no external tool, no Ollama
needed. `modelRouting.enabled` (on by default) stamps a `model:` line into every subagent's
frontmatter according to the **kind of work** it does:

| Tier | Default | Subagents |
|------|---------|-----------|
| reasoning | `opus` (or `fable`) | architect · planner · reviewer · security-advisor · requirements-check · modernization-advisor · orchestrator |
| implementation | `sonnet` | implementer · tester · quality-check · accessibility-checker |
| mechanical | `haiku` | docs-sync · test-gap-advisor · dependency-auditor · performance-advisor · onboarder |

Paying Opus rates for a dependency scan is waste; paying Haiku rates for an architecture review is
worse. Override per tier or per agent in `modelRouting.tiers` / `modelRouting.agents` — see
[Models & context7](models#model-tiers-per-activity-subagent-routing). Toggle the whole mechanism
with `aiflow change-settings`.

## `/compact` — the cheapest lever there is

Every turn re-sends the whole context window. A session that has been running for an hour pays for
its own history on every single message, and reasoning quality drops as the window fills. aiflow's
durable knowledge lives in **Beads**, `.claude/memory/`, `docs/architecture/` and `AGENTS.md` — the
transcript that produced it does not need to stay in context.

Compact at these points:

| When | Why |
|------|-----|
| Right after `aiflow init` (greenfield) | The Q&A already wrote the aim, stack and architecture into `.aiflow/config.json` + `.claude/memory/`. The interview itself is dead weight. |
| Right after `aiflow onboard` (brownfield) | Everything the onboarder learned is now in `codebase-map.md`, `AGENTS.md` §1/§2 and arc42. |
| After every closed bead | The next bead starts from the issue + the code, not from the last one's debugging. |
| Before a long Ralph run or a big refactor | The loop needs headroom, not your history. |

Persist first, compact second: bead notes/design, a memory file, or an ADR. Compaction is not
storage. Copilot and Codex have no `/compact` — start a fresh thread at the same four points and
re-read `AGENTS.md` plus the bead.

## ponytail — fewer tokens spent on code nobody needed

Off by default (`ponytail.enabled`/`.mode: full|lite|ultra`). A YAGNI decision ladder the agent
applies before writing new code, adding a dependency, or introducing an abstraction: does it need
to exist at all, is it already in the codebase, is it stdlib, a native platform feature, an
installed dependency, or a one-liner — only then does it write the minimum-viable new code.
`/ponytail-review` audits the current diff for over-engineering regardless of the toggle. See
[Agents → Skills](agents#slash-commands-and-skills).

## Measure first

```bash
aiflow cost      # ccusage: real token/cost baseline
```

Optimise what the numbers show, not what you guess. Combined, these routinely cut total token spend
by a large multiple on real projects.
