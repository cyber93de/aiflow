---
layout: default
title: Quick Start
parent: Getting Started
nav_order: 2
description: "Quick start: install aiflow, run aiflow init for Claude Code, wire MCP servers, and complete your first task with Beads, agents, and graph + RAG memory."
---

# Quick Start
{: .no_toc }

1. TOC
{:toc}

---

## Prerequisites

[Node.js](https://nodejs.org) (LTS). Everything else aiflow can install for you.

## Install

```bash
git clone https://github.com/Cyber93de/aiflow.git
cd aiflow
```

**Linux / macOS / Git-Bash:**
```bash
bash install.sh          # symlinks 'aiflow' onto your PATH
```

**Windows (PowerShell):**
```powershell
./install.ps1            # adds bin to PATH + creates the aiflow shim
```

The installer **asks once** whether to also install **git**, **Subversion (svn)**, and **Ollama** —
so a later `aiflow init` only has to ask *which* Ollama models you want.

```bash
aiflow doctor               # what's present / missing (+ per-project summary)
aiflow install-deps --all   # install the rest of the toolchain (optional)
```

Packaged builds: [github.com/Cyber93de/aiflow/releases](https://github.com/Cyber93de/aiflow/releases).

## Build a first project

```bash
mkdir my-app && cd my-app
aiflow init                 # interactive Q&A → writes .aiflow/config.json → renders everything
```

`aiflow init` asks (Enter = the sensible default; token-saving + intensive graph memory are **on**):

1. **caveman / rtk** — token-saving output + CLI filtering.
2. **graphify** (structural graph) and **cocoindex-code** (semantic RAG).
3. **task-master**, **filesystem MCP**, **context7 MCP**.
4. **Memory** — persistent memory, graph learning, and **intensity** (default `aggressive`).
5. **Claude access** — `apikey` (`ANTHROPIC_API_KEY`) or `oauth` (`claude setup-token`).
6. **Version control** — `git` / `svn` / `none`.
7. **Remote host** — `github | github-enterprise | gitlab | gitlab-self | bitbucket | forgejo |
   gitea | custom | none`, plus which **host MCP** to wire. Token-based.
8. **Sync rule** — ask to push + Dolt-sync on each issue close; auto-pull at session start.
9. **Ollama** — set it up? which models? (`qwen3-coder` recommended).
10. **Shared team preferences** — code style, etc.
11. **Project aim / architecture / OS / IDE**, and the **git branching model** (if VCS = git).

Then fill secrets and start:

```bash
# edit .env → your git-host token + (ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)
aiflow shell                # loads .env, launches Claude Code with all MCPs wired
```

Inside the session:

```text
/beads:ready                          # what's ready to work
bd create "Add health endpoint" -t task --claim   # create + claim a task
/implement                            # implementer builds it (code + tests, Google style)
/review-ac                            # reviewer gates it against acceptance criteria
```

## Existing codebase?

`aiflow init` detects it and offers `aiflow onboard`, which learns the code into `.claude/memory/`,
`CLAUDE.md`, and arc42 docs so the agent starts informed. Build the code indexes any time with
**`aiflow index`** (graph + RAG).

## Next

- [Features](features) · [Memory](memory) · [Configuration](configuration) · [Commands](commands)
