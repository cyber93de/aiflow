---
layout: default
title: Memory — graph + RAG
parent: Concepts
nav_order: 1
description: "aiflow code memory for Claude Code: a structural knowledge graph (graphify) plus semantic RAG (cocoindex) and Beads task memory — cutting tokens and hallucinations."
---

# Memory: why a graph *and* a RAG index
{: .no_toc }

1. TOC
{:toc}

---

LLMs forget between sessions and burn tokens re-reading files. aiflow gives the agent a **layered
context stack** so it *routes* a question to the cheapest source that answers it. The full routing
table is written to `.claude/memory/memory-policy.md` in every project.

## The context stack

| Need | Source | Why |
|------|--------|-----|
| Current task, deps, decisions, session state | **Beads** (`bd`) | structured work memory, survives compaction |
| Durable project facts / gotchas / env quirks | **memory files** (`.claude/memory/`) | prose not in code/git |
| Where a symbol is defined, who calls it, dependency direction | **graphify** (MCP) | exact structural graph — no re-scan |
| "Find the code about concept X" / semantic / fuzzy | **cocoindex-code** (`ccc` / MCP) | AST-aware RAG, local embeddings, ~70% fewer tokens |
| External library/framework API docs | **context7** (MCP) | live upstream docs, avoids hallucination |
| Anything still unresolved | read the file(s) | only after graph + RAG narrowed the target |

**Rule:** never scan whole files first. Route the question through graphify (structure) and
cocoindex-code (semantics) to locate the few relevant chunks, then open only those.

## Why a graph?

Code *is* a graph — imports, calls, types. A graph answers **structural** questions ("who calls
`parseToken`? what does `auth` depend on?") exactly and cheaply — no guessing, no re-reading — and it
discourages DRY violations because the agent can *see* existing code instead of re-inventing it.

aiflow uses **graphify** for this: a queryable knowledge graph over MCP.

## Why also RAG?

A graph doesn't answer **fuzzy** questions ("where is retry logic handled?"). aiflow adds
**cocoindex-code** (`ccc`): it chunks the code AST-aware, embeds it **locally** (sentence-transformers,
no API key), and searches by meaning — ~70% fewer tokens than opening files. It's **incremental**:
only changed files re-embed, and the index lives in `.cocoindex_code/` (gitignored).

- CLI: `ccc search "authentication logic"`, `ccc search --lang python schema`, `ccc grep '...'`.
- As an MCP server it's wired automatically when `mcp.cocoindex` is on.

## Learning intensity

`.aiflow/config.json → memory.intensity` controls how aggressively the agent saves durable facts:

- `aggressive` (default) — save after every non-trivial task + refresh the graph.
- `normal` — save durable non-obvious facts; refresh when structure changes.
- `light` — only high-value, long-lived facts.
- `off` — rely on Beads + `CLAUDE.md` only.

## Refresh both indexes with one command

```bash
aiflow index            # = graphify build  +  ccc index   (incremental)
```

Run it after significant code changes; it keeps the structural graph *and* the RAG index current.

## See also

- [context7](models#context7) for external library docs.
- [Configuration](configuration) for the memory files and policy.
