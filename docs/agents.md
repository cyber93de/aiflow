---
layout: default
title: Agents
parent: Agents & Workflows
nav_order: 1
description: "aiflow's Claude Code subagents in detail: what architect, planner, implementer, reviewer, tester, the audit agents, accessibility-checker, modernization-advisor, and the onboarder do and watch for."
---

# Agents — the full roster
{: .no_toc }

1. TOC
{:toc}

---

Specialist subagents live in `.claude/agents/`. Claude picks one by its `description`, or you invoke
it explicitly. The shipped agents are **deliberately generic** — a strong, universal starting point,
not the finish line: **customise them to your project's needs** by editing their markdown (prompt,
allowed `tools:`, `model:`) — e.g. your domain language, your review focus, your test stack.

**Shared ground rules for all delivery agents:** every implementation targets **production** — they
are very careful with low-maturity technology (experimental, pre-1.0, unmaintained), and the
reviewer and tester must flag it. They keep classes small (**KISS**; a class growing into hundreds
of lines triggers **divide & conquer** and interface encapsulation — utility-library overloads are
the accepted exception), avoid growing a monolith even when microservices aren't required, question
**legacy technology choices** (SOAP over REST, XML-over-REST over JSON, 1980s-style MQ patterns)
instead of silently building them, and deliberately consider the data/performance architecture
(in-memory stores like **Redis**/**SQLite**, or **Elasticsearch** as a search/caching layer that
decouples the database from the application).

## Delivery agents (do the work)

### architect
Designs structure and protects it over time. Produces **ADRs**, arc42 updates, and a bead breakdown —
never feature code. Watches for: real constraints and the quality goal at stake; at least two viable
options with trade-offs; module boundaries and dependency direction; **production-ready, supported
technology** (no experimental/EOL stacks); **state of the art over legacy** (REST/JSON +
cloud-native eventing over SOAP/XML and legacy MQ); **modular over monolithic** (service-ready
seams); caching/search layers (Redis, Elasticsearch) where load justifies them.

### planner
Turns a goal/epic/issue into small, dependency-ordered Beads tasks. Watches for: one independently
shippable unit per bead; **concrete, testable acceptance criteria** ("returns 400 on empty body",
not "handles errors"); real dependencies only (fake ones kill parallelism); no vague AC ever
reaching the implementer.

### implementer (senior software engineer)
Builds exactly one ready bead — **strategy first**: a mandatory pre-analysis (current architecture,
how it changes, effort, complexity, risks) and information gathering *before* any code. From the
pre-analysis it **decides automatically whether to use the Ralph loop**; a manual directive wins —
`/implement <bead> ralph|no-ralph` in the session, or "use the Ralph loop" written into the bead
itself. Watches for: architecture fit (targeted refactoring when the requirement
doesn't fit — or escalation to the architect); **SOLID/DRY/KISS/YAGNI**, high cohesion/low
coupling, no cyclic dependencies; small classes (divide & conquer + interfaces instead of giants);
**proven frameworks and design patterns over self-implementations**; no duplication, reusable and
generic solutions; robustness (error handling, input validation, null/Optional, thread safety);
**testability by design** (DI, no hidden dependencies, deterministic, mockable); security
(parameterised queries, no secrets, least privilege); leveled **logging**; PO-level clarification
questions with **recorded decisions**; questioning of legacy tech choices; the quality gates
(static analysis, > 80 % coverage of changed logic, unit + BDD E2E tests, metric targets, database
rules §3c); REST endpoints **versioned (`/api/v1/…`) and properly secured** — OAuth2/OIDC, JWT, or
managed API keys, never Basic Auth — each with its `.http` file.

### reviewer (architect + quality gate in one)
The gate before a bead closes — two hats in one pass. **Architect hat** watches for: acceptance
criteria actually met; **architecture integrity** (layers, module boundaries, interfaces, ADRs —
an unrecorded architecture change is a blocker); design (SOLID, clean architecture, domain model,
right abstraction level); maintainability (tech debt, over-/under-engineering, oversized classes,
monolith drift); **production readiness** (low-maturity or unquestioned legacy tech is a finding;
EOL stack elements are a security finding); risks (vulnerabilities, performance, concurrency,
API breaking changes, backward compatibility); the data model (§3c). **Quality-gate hat** ticks an
objective checklist: findings addressed, tests green + coverage gates, no new smells/duplicates/
violations, zero warnings, static analysis done, logging + doc comments, `.http` files, docs/
changelog updated, requirement fully implemented. Verdict **PASS** or **CHANGES REQUIRED**;
out-of-scope improvement ideas are persisted as `[suggestion]` beads — never lost in chat.

### tester (test/QA engineer)
The deeper test pass — runs when the pre-analysis flags high risk/complexity, or on demand.
Watches for: systematic coverage (**happy path, negative tests, edge cases, boundary values,
exception handling, invalid inputs**, concurrency); the coverage gates (> 80 % lines, every
non-static method); **test quality**, not just quantity — meaningful assertions, deterministic,
independent, understandable tests; BDD (Given/When/Then) for E2E/system/acceptance;
production-readiness (a feature that can't be tested reliably is flagged); real defects become
beads — production code is never edited to silence a test.

## Audit agents (manual, on demand — not part of the delivery loop)

Each scans the whole project read-only and files prioritised Beads issues with a distinctive label
so the product owner can triage (except the two report-only agents).

| Agent | Command | Output | Watches for |
|-------|---------|--------|-------------|
| **security-advisor** | `aiflow security-check` | `[security-advisor]` beads | secrets, injection, authN/Z flaws, crypto misuse, SSRF/XSS/CSRF, unsafe deserialisation, dependency risk, insecure config |
| **quality-check** | `aiflow quality-check` | `[technical issue]` beads | dead code, now-simplifiable code, duplication, excessive complexity, inconsistencies |
| **dependency-auditor** | `aiflow dependency-check` | `[dependency]` beads | known-vulnerable, outdated, unused, or license-problematic dependencies |
| **test-gap-advisor** | `aiflow test-gap` | `[test gap]` beads | untested critical paths |
| **performance-advisor** | `aiflow perf-check` | `[performance]` beads | hotspots, N+1 queries, needless allocations, missing caching |
| **docs-sync** | `aiflow docs-check` | `[docs]` beads | doc/code drift |
| **accessibility-checker** | `aiflow a11y-check` | `[accessibility]` beads | **strict WCAG 2.2 AA**: text alternatives, semantic markup, contrast, keyboard operability, focus, labels/errors, correct ARIA; recommends an automated a11y tool for the E2E suite (axe-core / Pa11y / Lighthouse CI) |
| **requirements-check** | `aiflow requirements-check` | *report only* | issue quality: goal clarity, testable AC, scope, architecture fit, undescribed cases, dependencies |
| **modernization-advisor** | `aiflow modernize-check` | *report only* → `.aiflow/modernization-report.md` | brownfield modernisation: EOL/unsupported stacks, monolith → **microservice** extraction candidates (strangler-fig), SOAP/XML/legacy MQ → **REST/JSON + cloud-native eventing**, **svn → git**, containerisation/CI/observability gaps, missing **unit/BDD/E2E test frameworks** (named concretely for the stack), caching/search decoupling (Redis/Elasticsearch). Maintainability and security lead the ranking — the architect reviews the report and optionally turns concepts into beads |

## Brownfield agent

| Agent | Role |
|-------|------|
| **onboarder** | Studies an existing codebase and persists what it learns into `.claude/memory/`, `CLAUDE.md`, and arc42 — future sessions start informed; **proposes a project aim** from its understanding and asks you to confirm it. Writes docs/memory only. |

## Slash-command skills

Triggerable inside Claude Code (`.claude/commands/`):

- **Delivery:** `/intake-issue <n>`, `/decompose <goal|prd>`, `/plan-epic`,
  `/implement [bead] [ralph|no-ralph]`, `/review-ac`, `/arch "<question>"`.
- **Audits:** `/security-check`, `/quality-check`, `/requirements-check`, `/dependency-check`,
  `/test-gap`, `/perf-check`, `/docs-check`, `/a11y-check`, `/modernize-check`.
- **Brownfield / orientation:** `/onboard`, `/explain <path>`, `/standup`.

Beads and the Ralph loop also ship as plugin skills (`/beads:ready`, `/beads:decision`, `/ralph-loop`).

## Customising an agent

Edit its markdown file in `.claude/agents/`. You can change the prompt, restrict `tools:`, or pin a
`model:` (e.g. a cheaper model for a simple agent). Changes take effect next session.
