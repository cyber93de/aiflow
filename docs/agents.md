---
layout: default
title: Agents
parent: Agents & Workflows
nav_order: 1
description: "aiflow's Claude Code subagents: architect, planner, implementer, reviewer, tester, security/quality/dependency/test-gap/performance/docs audit agents, and the onboarder."
---

# Agents — the full roster
{: .no_toc }

1. TOC
{:toc}

---

Specialist subagents live in `.claude/agents/`. Claude picks one by its `description`, or you invoke
it explicitly. Customise any by editing its markdown (prompt, allowed `tools:`, `model:`).

## Delivery agents (do the work)

| Agent | Role |
|-------|------|
| **architect** | System design — produces ADRs, arc42 updates, and a task breakdown. No feature code. |
| **planner** | Turns a goal/epic/issue into small Beads tasks with testable acceptance criteria + real dependencies. |
| **implementer** | Builds exactly one ready bead (code + tests) in Google style; stops as BLOCKED if criteria are unclear. |
| **reviewer** | The quality gate — reviews a diff against acceptance criteria, correctness, tests, style. Verdict PASS / CHANGES REQUIRED. |
| **tester** | Writes meaningful tests, hunts edge cases; reports bugs instead of weakening tests. |

## Audit agents (manual, read-only on code, file prioritised Beads)

Each scans the whole project read-only and files prioritised Beads issues with a distinctive label so
the product owner can triage.

| Agent | Command | Files issues labelled |
|-------|---------|-----------------------|
| **security-advisor** | `aiflow security-check` | `[security-advisor]` |
| **quality-check** | `aiflow quality-check` | `[technical issue]` |
| **dependency-auditor** | `aiflow dependency-check` | `[dependency]` |
| **test-gap-advisor** | `aiflow test-gap` | `[test gap]` |
| **performance-advisor** | `aiflow perf-check` | `[performance]` |
| **docs-sync** | `aiflow docs-check` | `[docs]` |
| **requirements-check** | `aiflow requirements-check` | *report only* — grades issue quality vs architecture; no changes |

## Brownfield agent

| Agent | Role |
|-------|------|
| **onboarder** | Studies an existing codebase and persists what it learns into `.claude/memory/`, `CLAUDE.md`, and arc42 — future sessions start informed. Writes docs/memory only. |

## Slash-command skills

Triggerable inside Claude Code (`.claude/commands/`):

- **Delivery:** `/intake-issue <n>`, `/decompose <goal|prd>`, `/plan-epic`, `/implement [bead]`,
  `/review-ac`, `/arch "<question>"`.
- **Audits:** `/security-check`, `/quality-check`, `/requirements-check`, `/dependency-check`,
  `/test-gap`, `/perf-check`, `/docs-check`.
- **Brownfield / orientation:** `/onboard`, `/explain <path>`, `/standup`.

Beads and the Ralph loop also ship as plugin skills (`/beads:ready`, `/beads:decision`, `/ralph-loop`).

## Customising an agent

Edit its markdown file in `.claude/agents/`. You can change the prompt, restrict `tools:`, or pin a
`model:` (e.g. a cheaper model for a simple agent). Changes take effect next session.
