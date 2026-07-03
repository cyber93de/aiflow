---
layout: default
title: Token optimization
parent: Concepts
nav_order: 2
description: "Cut Claude Code token cost with aiflow: caveman terse output, rtk CLI-output filtering, graph + RAG retrieval instead of reading files, and cheap/local model routing."
---

# Token optimization
{: .no_toc }

1. TOC
{:toc}

---

Context is the budget. aiflow attacks token cost from four directions — the first two are **on by
default**.

## caveman — terse output

A compressed output mode: the agent drops filler and speaks tersely. **~75% fewer output tokens**;
code, commits, and security warnings stay in full prose. Toggle in `.aiflow/config.json`
(`caveman.enabled`, `caveman.mode: full|lite|ultra`).

## rtk — CLI-output filtering

Verbose command output (installs, test runs, build logs) is filtered/compressed **before it enters
context** — errors and diffs are preserved, noise is trimmed. Typically **60–90% fewer tokens** on
noisy commands. Enabled per project by aiflow.

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
