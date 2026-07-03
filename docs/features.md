---
layout: default
title: Features & advantages
parent: Getting Started
nav_order: 3
description: "aiflow features: Claude Code automation, Beads task memory, code graph + semantic RAG, context7, Ollama, agents, team sync, and token savings with caveman and rtk."
---

# Features
{: .no_toc }

1. TOC
{:toc}

---

## Capability map

| Area | What you get |
|------|--------------|
| **Task tracking** | Beads (`bd`) — Dolt-backed issues with dependencies, status, history; survives context resets |
| **Code memory** | **graphify** (structural graph) + **cocoindex-code** (semantic RAG) + `.claude/memory/` facts |
| **External docs** | **context7** MCP — live, version-correct library documentation |
| **Version control** | Choose **git**, **svn**, or **none** at setup |
| **Remote host** | GitHub, GitHub Enterprise, GitLab, self-managed GitLab, Bitbucket, Forgejo, Gitea, or a custom URL — token-based |
| **Host MCP** | The matching git-host MCP is wired automatically per remote type |
| **Models** | Claude (API key *or* OAuth) + optional **Ollama** local models, selectable & auto-installed |
| **Model routing** | claude-code-router sends easy/background work to cheap/local models |
| **Agents** | 5 delivery + 6 audit + 1 brownfield specialist subagents |
| **Autonomy** | Ralph loop (interactive / headless / containerised / CI) |
| **Quality** | Google style, conventional commits, format/lint/test git hooks, review gate |
| **Branching** | simple / gitflow / none, PR-only, auto-release, SemVer/CalVer |
| **Team** | shared issue DB, atomic claim, session-start auto-pull, pull-before-push, shared preferences |
| **Token savings** | caveman + rtk on by default, graph/RAG retrieval, cost routing |

## Advantages in depth

### Better memory, fewer hallucinations
Two complementary code indexes plus durable task memory mean the agent *looks things up* instead of
guessing or re-reading dozens of files. See [Memory](memory).

### Big token reduction
- **caveman** — terse output mode (~75% fewer output tokens; code/commits/security stay normal).
- **rtk** — filters/compresses verbose command output before it enters context (60–90% fewer).
- **graph + RAG retrieval** — answer from graphify/cocoindex instead of reading whole files (~70% fewer).
- **model routing** — send easy/background steps to cheap or local (Ollama) models.
- **measure first** — `aiflow cost` (ccusage) shows real spend.

### Team-ready by design
Issues live in a shared Dolt database that syncs over your git remote — one issue graph for the whole
team, no extra server. Atomic claiming prevents two people grabbing the same task; pull-before-push
prevents clobbering. See [Team collaboration](team).

### Governed & auditable
Conventional Commits, enforced Google style, a review gate against acceptance criteria,
security/quality/deps/test/perf/docs audits, and a real branching + release model. See
[Workflows](workflows).

### Autonomous when you want it
The Ralph loop finishes a task unattended — locally, in a container, or in CI — and stops at
`COMPLETE`/`BLOCKED`, writing `result.json`.

### Yours, not a hub
Everything runs on your keys/tokens and your infrastructure; secrets never leave the project.

## The bundled toolchain

Each tool earns its place by raising **quality**, cutting **token cost**, or making delivery
**autonomous and auditable**. See the full list and links in [Feedback & contributing → Credits](contributing#credits--thanks).
Install only what your config enables with `aiflow install-deps` (`--all` = full set).
