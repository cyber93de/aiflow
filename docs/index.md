---
layout: default
title: Home
nav_order: 1
description: "aiflow: a governed, AI-driven software-delivery pipeline for Claude Code — Beads task memory, code knowledge graph (graphify) + semantic RAG (cocoindex), context7, agents, Ollama, team sync, and token savings with caveman and rtk. One command, MIT."
permalink: /
---

# aiflow
{: .fs-9 }

Turn any repository into a **governed, AI-driven software-delivery pipeline** with one command —
durable task memory, a two-layer code memory (structural **graph** + semantic **RAG**), specialist
review/audit agents, first-class **team collaboration**, big **token savings**, and a real release
process.
{: .fs-6 .fw-300 }

[Get started](getting-started){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/Cyber93de/aiflow){: .btn .fs-5 .mb-4 .mb-md-0 }

**Version 0.1.0 · MIT License**

---

## What it is

aiflow wires [Claude Code](https://docs.claude.com/en/docs/claude-code) together with a curated
toolchain so an AI agent — or a whole team of humans + agents — can take an issue, plan it, write the
code in a consistent style, test it, review it against acceptance criteria, audit it for security and
quality, and ship it through a governed branching + release model.

- **Token-based & vendor-neutral** — your own Anthropic API key *or* Claude Code OAuth token; git
  hosts via **tokens only, never OAuth**.
- **Local-first option** — run easy work on **Ollama** models (no key); keep top models for hard reasoning.
- **Project-scoped** — secrets and settings live in the project (`.env`, `.aiflow/config.json`), never globally.
- **Cross-platform** — Windows, Linux, macOS.

## Why teams choose it

| Advantage | How |
|-----------|-----|
| **Better memory** | Structural graph (graphify) + semantic RAG (cocoindex-code) + durable Beads tasks → the agent looks things up instead of guessing. |
| **Fewer tokens** | caveman (~75% less output) + rtk (60–90% less CLI noise) + graph/RAG retrieval (~70% vs reading files) + cheap/local routing. |
| **Team-ready** | Shared Dolt issue DB over your git remote, atomic claiming, pull-before-push. |
| **Governed** | Conventional Commits, enforced Google style, review gate, security/quality/deps/test/perf/docs audits, branching + releases. |
| **Autonomous** | The Ralph loop finishes tasks unattended (local, container, or CI). |

## Explore the docs

- **[Getting started](getting-started)** — install and build your first project.
- **[Features](features)** — the full capability map.
- **[Memory: graph + RAG](memory)** — why aiflow uses both, and how it routes questions.
- **[Agents](agents)** — the full roster of delivery, audit, and brownfield agents.
- **[Models](models)** — Claude access, Ollama, context7, adding more models.
- **[Remote hosts](remotes)** — GitHub, GitLab, Bitbucket, Forgejo, Gitea, custom.
- **[Team collaboration](team)** — many members, one issue graph.
- **[Configuration](configuration)** — CLAUDE.md, team preferences, custom MCPs.
- **[Commands](commands)** — the `aiflow` CLI reference.
- **[Workflows & CI/CD](workflows)** — branching models + build/release.
- **[FAQ](faq)** · **[Feedback & contributing](contributing)**

---

aiflow is **glue** — huge thanks to the projects it stands on (see [Feedback & contributing](contributing#credits--thanks)).

---

<small>**Related topics & tools:** Claude Code · Anthropic Claude · AI coding agent · MCP (Model Context
Protocol) · Beads issue tracker · Dolt · graphify code knowledge graph · CocoIndex / cocoindex-code
semantic code RAG · Context7 · Ollama local LLMs · claude-code-router · rtk · caveman · token
optimization · retrieval-augmented generation · agentic software delivery · gitflow · Conventional
Commits · GitHub / GitLab / Bitbucket / Forgejo / Gitea.</small>
