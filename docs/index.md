---
layout: default
title: Home
nav_order: 1
description: "aiflow: a governed, AI-driven software-delivery pipeline, agent-agnostic across Claude Code, GitHub Copilot, and OpenAI Codex CLI — Beads task memory, code knowledge graph (graphify) + semantic RAG (cocoindex), context7, agents, Skills (ponytail YAGNI, memory-setup, seo-optimization), gitflow release automation, Ollama, team sync, and per-agent token savings (caveman/rtk, haiku model routing, Copilot token-optimization guide, CodexSaver). One command, MIT."
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

**Version 0.7.0 · MIT License**

![aiflow init: bootstrap a project in one interactive Q&A](assets/terminal/init.gif)

---

## What it is

aiflow wires [Claude Code](https://docs.claude.com/en/docs/claude-code) together with a curated
toolchain so an AI agent — or a whole team of humans + agents — can take an issue, plan it, write the
code in a consistent style, test it, review it against acceptance criteria, audit it for security and
quality, and ship it through a governed branching + release model. It's **agent-agnostic**: the
same project rules (`AGENTS.md`) and MCP tool config also render for **GitHub Copilot** and
**OpenAI Codex CLI** — see [Multi-Agent Support](multi-agent) — though Claude Code keeps the
deepest feature set (subagents, hooks, the Ralph loop).

**Most people struggle to set up their AI project successfully — especially without deep AI
know-how yet. aiflow is built to fix exactly that** (start with [AI Basics](ai-basics) if the
terminology is new to you).

The idea: **a very good, universal base configuration that works everywhere** — because a strong
base config beats no config, and "no config" is how most AI-coding projects sadly start. Out of the
box it saves roughly **70–80 % of the configuration effort** versus using Claude blank. The shipped
agents and rules are deliberately **generic**: customise them to your project (domain language,
review focus, test stack) — but even uncustomised they beat a blank start.

The actual goal is **production-ready code**: reusable, reliable, secure, on current standards;
agents that know and respect your architecture, extend it sensibly, push back on requirements that
don't fit it, and propose new layers (caching, search, service seams) where performance demands —
plus on-demand reports on **accessibility (WCAG)**, **modernisation potential**, and **security**.
Token saving remains a goal too, but the quality rules mean it is only partially achieved per
task — the real saving is **never having to ask twice**.

- **Token-based & vendor-neutral** — your own Anthropic API key *or* Claude Code OAuth token; git
  hosts via **tokens only, never OAuth**.
- **Local-first option** — run easy work on **Ollama** models (no key); keep top models for hard reasoning.
- **Project-scoped** — secrets and settings live in the project (`.env`, `.aiflow/config.json`), never globally.
- **Cross-platform** — Windows, Linux, macOS.

## Why teams choose it

| Advantage | How |
|-----------|-----|
| **Better memory** | Structural graph (graphify) + semantic RAG (cocoindex-code) + durable Beads tasks → the agent looks things up instead of guessing. |
| **Fewer tokens** | Claude Code: caveman (~75% less output) + rtk (60–90% less CLI noise) + haiku model routing for audit subagents + the optional ponytail YAGNI skill. Copilot: token-optimization guide. Codex: optional CodexSaver. All agents: graph/RAG retrieval (~70% vs reading files) + cheap/local routing. |
| **Team-ready** | Shared Dolt issue DB over your git remote, atomic claiming, pull-before-push. |
| **Governed** | Conventional Commits, enforced Google style, review gate, security/quality/deps/test/perf/docs audits, branching + releases. |
| **Autonomous** | The Ralph loop finishes tasks unattended (local, container, or CI). |

## Explore the docs

- **[Getting started](getting-started)** — install and build your first project.
- **[Features](features)** — the full capability map.
- **[Memory: graph + RAG](memory)** — why aiflow uses both, and how it routes questions.
- **[Agents](agents)** — the full roster of delivery, audit, and brownfield agents (Claude Code).
- **[Multi-Agent Support](multi-agent)** — using GitHub Copilot and/or OpenAI Codex CLI too.
- **[Models](models)** — Claude access, Ollama, context7, adding more models.
- **[Remote hosts](remotes)** — GitHub, GitLab, Bitbucket, Forgejo, Gitea, custom.
- **[Team collaboration](team)** — many members, one issue graph.
- **[Configuration](configuration)** — AGENTS.md, team preferences, custom MCPs.
- **[Commands](commands)** — the `aiflow` CLI reference.
- **[Workflows & CI/CD](workflows)** — branching models + build/release.
- **[FAQ](faq)** · **[Feedback & contributing](contributing)**

---

aiflow is **glue** — huge thanks to the projects it stands on (see [Feedback & contributing](contributing#credits--thanks)).

---

<small>**Related topics & tools:** Claude Code · Anthropic Claude · AI coding agent · MCP (Model Context
Protocol) · Beads issue tracker · Dolt · graphify code knowledge graph · CocoIndex / cocoindex-code
semantic code RAG · Context7 · Ollama local LLMs · claude-code-router · rtk · caveman · ponytail ·
YAGNI · memory-setup · haiku model routing · token optimization · retrieval-augmented generation ·
agentic software delivery · gitflow · Conventional Commits · GitHub / GitLab / Bitbucket / Forgejo
/ Gitea.</small>
