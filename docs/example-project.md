---
layout: default
title: Example project walk-through
parent: Getting Started
nav_order: 4
description: "A complete aiflow example: every init question with its default, what gets generated, and a first feature built end-to-end (task → implement → review → close)."
---

# Example project walk-through
{: .no_toc }

1. TOC
{:toc}

---

This page builds a small **order-management REST API** from zero and shows every choice you can
make, what the **default** is, and what happens after. (aiflow is language-agnostic — the same
flow works for any stack.)

![aiflow init: the interactive Q&A](assets/terminal/init.gif)

## 1. Create the project

```bash
mkdir order-api && cd order-api
aiflow init
```

`aiflow init` asks its questions — **Enter always takes the sensible default**:

| # | Question | Default | Notes |
|---|----------|---------|-------|
| 1 | caveman (terse output)? + mode | **on**, `full` | saves ~75 % output tokens; `--no-token-saving` turns it off |
| 2 | rtk CLI-output filtering? | **on** | trims noisy command output before it hits context |
| 3 | graphify (structural code graph)? | **on** | answers "who calls X?" without re-reading files |
| 4 | cocoindex-code (semantic RAG)? | **on** | "find the code about Y", local embeddings, no key |
| 5 | task-master / filesystem MCP / context7 MCP? | **on** | task decomposition, file access, live library docs |
| 6 | Persistent memory + graph learning + intensity | **on**, `aggressive` | durable facts in `.claude/memory/` |
| 7 | Claude auth | `apikey` | or `oauth` (`claude setup-token`, uses your plan) |
| 8 | Version control | `git` | or `svn` / `none` |
| 9 | Remote host | `github` | github-enterprise, gitlab(-self), bitbucket, forgejo, gitea, custom, none — token-based |
| 10 | Sync on issue close? auto-pull at start? | **yes / yes** | team collaboration via the shared Dolt issue DB |
| 11 | Ollama (local models)? which? | **off**; `qwen3-coder` suggested | local models for easy/background steps, no API key |
| 12 | Shared team preferences? | **off**; style `google` | committed team-wide conventions |
| 13 | **Project aim** / architecture / OS / IDE | *empty — fill it!* | the cheapest quality lever; see below |
| 14 | Git branching model | `simple` | or `gitflow` / `none`; strict rules + PR-only default **yes** |

For the aim, answer something like:

> *Order-management REST API for our internal shops. Hexagonal architecture on PostgreSQL.
> Correctness and auditability beat raw speed; every endpoint ships fully tested.*

**What gets generated:** `.aiflow/config.json` (single source of truth), `CLAUDE.md` (operating
rules incl. quality gates §3a, REST rules §3b, database rules §3c), `.claude/agents/` +
`.claude/commands/` (the whole roster), `.mcp.json`, git hooks (format/lint/test + Conventional
Commits + branch rules), `.env` from `.env.example`, memory seed files, and the Beads issue DB.

## 2. Fill secrets and start

```bash
# edit .env → GITHUB_TOKEN + (ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)
aiflow shell        # loads .env, launches Claude Code with all MCPs wired
```

## 3. First feature, end to end

![One feature end to end: bd create, /implement with pre-analysis and PO question, /review-ac PASS, bd close](assets/terminal/workflow.gif)

Inside the session:

```text
bd create "Order endpoint: create + fetch orders" -t feature --claim
/implement
```

What the **implementer** now does — automatically:

1. **Pre-analysis first:** current architecture, how it changes, effort, complexity, risks —
   and from that the **Ralph-loop decision** (small task → direct; long-horizon → the loop).
   You can also force it: `/implement <bead> ralph`, or write "use the Ralph loop" into the bead.
2. **PO-level questions** where the requirement is ambiguous ("Should orders be deletable, or
   cancelled with history? A) hard delete — simpler, loses audit trail; B) soft delete — keeps
   history, slightly more code"). Your answer is **recorded** as a decision.
3. Builds production-ready: versioned + secured REST (`/api/v1/orders`, JWT — not Basic Auth),
   ≥ 3NF data model with real foreign keys, leveled logging, SOLID/KISS-sized classes.
4. Ships **tests** (unit + BDD end-to-end, > 80 % coverage of the changed logic) and an
   **`.http` file** (`http/orders.http`) you can run from IntelliJ/VS Code — host/port/test user
   come from `.env`.
5. Runs formatter, linter, static analysis until clean.

Then the gate:

```text
/review-ac
```

The **reviewer** (architect + quality gate in one) checks architecture integrity, design, risks,
and the objective checklist — verdict **PASS** or **CHANGES REQUIRED**. Out-of-scope ideas are
persisted as `[suggestion]` beads. After PASS:

```text
bd close <id> --reason "AC verified: endpoints tested, coverage 87%"
# aiflow close-sync asks whether to push + sync the issue DB (team stays current)
```

## 4. What you'd tune next

- **`CLAUDE.md §1/§2`** — project overview + architecture hints (biggest quality lever).
- **`.claude/agents/*.md`** — the shipped agents are deliberately generic; add your domain
  language, review focus, test stack.
- **On-demand checks:** `aiflow security-check`, `aiflow a11y-check` (strict WCAG),
  `aiflow modernize-check` (brownfield modernisation report), `aiflow quality-check`, and more —
  see [Commands](commands).
- **Existing codebase instead?** `aiflow init` detects it and offers `aiflow onboard` — it learns
  the code into memory, fills `CLAUDE.md`, and proposes a project aim for you to confirm.

![aiflow change-settings](assets/terminal/settings.gif)

Change any choice later with `aiflow change-settings` (or `--no-token-saving` to switch
caveman + rtk off).
