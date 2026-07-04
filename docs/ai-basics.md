---
layout: default
title: AI Basics (start here)
parent: Getting Started
nav_order: 0
description: "New to AI coding? Plain-language primer: what Claude Code, agents, memory, context windows, skills, hooks, and MCP are — and how aiflow uses them."
---

# AI basics — a plain-language primer
{: .no_toc }

1. TOC
{:toc}

---

Most people struggle to set up their AI project successfully — usually not because the tools are
bad, but because the concepts are new. This page explains them in plain language. Skip it if you
already work with Claude Code daily.

## What is an LLM, and why does it "forget"?

A large language model (LLM) predicts text. Given instructions and context, it can write and edit
code impressively well — but it has **no memory between sessions**. Every new conversation starts
from zero unless you supply the context again. Most of what aiflow does is solving exactly this
"context problem" in a structured, repeatable way.

## What is a context window?

The **context window** is the model's working memory: everything it can "see" right now — your
instructions, the conversation so far, file contents, tool output. It is large but **finite**, and
every token in it costs money and attention. Two consequences aiflow designs around:

- **Don't fill it with noise.** Reading whole files "just in case" wastes the window. aiflow routes
  questions through a code graph (**graphify**) and a semantic index (**cocoindex-code**) so the
  agent loads only the few relevant chunks.
- **Don't lose what matters.** When a session ends (or the window fills up and gets compacted),
  untracked knowledge dies. aiflow persists it: tasks in **Beads**, durable facts in
  **memory files**, decisions in the issue tracker.

## What is Claude Code?

[Claude Code](https://docs.claude.com/en/docs/claude-code) is Anthropic's coding agent for the
terminal and IDE. With your permission it reads files, runs commands, edits code, and uses tools.
It is configured per project through plain files — `CLAUDE.md` (the rules every agent follows),
`.claude/settings.json` (permissions + hooks), `.claude/agents/` and `.claude/commands/`. aiflow
generates and maintains all of these for you.

## What is an agent?

An **agent** is a focused AI worker with a role and a system prompt: aiflow ships an
*implementer* (senior engineer), a *reviewer* (architect + quality gate), a *tester*, an
*architect*, a *planner*, plus on-demand checkers (security, accessibility, modernisation, …).
Each is a small markdown file you can read and edit — the prompt **is** the configuration. See
[Agents](agents) for what each one does and watches for.

## What is memory (in aiflow)?

Three layers, each for a different kind of knowledge:

| Layer | Holds | Example |
|-------|-------|---------|
| **Beads** (`bd`) | tasks, dependencies, status, decisions | "implement order endpoint — in progress, claimed by you" |
| **Memory files** (`.claude/memory/`) | durable prose facts | project aim, dev environment, gotchas |
| **Code indexes** (graphify + cocoindex-code) | the structure and meaning of your code | "who calls `parseToken`?", "where is retry logic?" |

Each session starts by reading these — so the agent begins informed instead of re-discovering
your project every time.

## What is a skill / slash command?

A reusable instruction you trigger with `/name` — e.g. `/implement` (build one task end-to-end),
`/review-ac` (run the review gate), `/a11y-check` (WCAG audit). They live in `.claude/commands/`
as markdown files.

## What is a hook?

A script the environment runs **automatically** on events: after the AI edits a file (aiflow
auto-formats it), at session start (aiflow pulls the shared issue database), before a git push
(aiflow enforces the branching rules). Hooks are how rules stay enforced even when nobody thinks
about them.

## What is MCP?

The **Model Context Protocol** is a standard for plugging external tools into the agent: your git
host's issues and PRs, the filesystem, the code graph, live library documentation (**context7**).
aiflow generates the MCP configuration (`.mcp.json`) from your answers at `aiflow init`.

## What is the Ralph loop?

An autonomy pattern: the agent iterates on a task — implement, verify, fix — until it is
`COMPLETE` or `BLOCKED`, without you babysitting each step. The implementer decides automatically
(from its pre-analysis) whether a task warrants it; you can also request it manually per issue.

## Token? Cost?

Models bill by **tokens** (roughly: pieces of words) — everything the model reads and writes
counts. aiflow reduces cost with terse output (caveman), CLI-output filtering (rtk), graph/RAG
retrieval, and optional routing of easy steps to cheap or local models. Be aware: the quality
rules deliberately *spend* tokens on tests and reviews — the net saving comes from not having to
re-prompt and rework. Measure with `aiflow cost`.

## Where to go next

- [Installation](installation) — get the CLI.
- [Quick Start](getting-started) — first project in minutes.
- [Example project walk-through](example-project) — every question, every default, first feature.
- [Agents](agents) — who does what, in detail.
