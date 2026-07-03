# ADR 0001: Record architecture decisions

- **Status:** accepted
- **Date:** <yyyy-mm-dd>

## Context
We need a durable, reviewable record of why the architecture is the way it is, so agents
and humans respect prior decisions instead of relitigating them.

## Decision
Use ADRs (one markdown file per decision) under `docs/architecture/adr/`. The architect
agent writes them; they are referenced from CLAUDE.md §2 and the arc42 doc §9.

## Consequences
- Decisions are greppable and versioned with the code.
- New decisions supersede old ones explicitly (link the superseded ADR).

<!-- Copy this file for the next decision: 0002-*.md -->
