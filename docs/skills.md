---
layout: default
title: Skills
parent: Agents & Workflows
nav_order: 4
description: "aiflow's Claude Code Skills: the catalogue (technology stacks, integration and data architecture, security, SEO, ponytail YAGNI, memory-setup) and the rule for what belongs in a skill versus an agent."
---

# Skills
{: .no_toc }

1. TOC
{:toc}

---

> **Claude Code only.** Skills live in `.claude/skills/<name>/SKILL.md`. Claude Code matches a
> skill's `description` against what you are currently doing and offers to run it — no `/name`
> needed, unlike a [slash-command](agents#slash-commands-and-skills). Copilot and Codex CLI have no
> auto-offer mechanism: read the relevant `SKILL.md` directly as a manual checklist.

## Skill or agent?

Both can exist for the same topic, and often should — the same-named agent simply uses the skill
instead of restating it. The split follows one rule:

| | Belongs in an **agent** | Belongs in a **skill** |
|---|---|---|
| **What it is** | a *role*: who acts, with what authority, in what order, and what they hand to whom | *knowledge*: a checklist, the trade-offs of a technology, what to look for |
| **Loaded** | when that role is dispatched | when the task matches, for **any** role |
| **Examples** | "the reviewer decides PASS / CHANGES REQUIRED"; "the orchestrator dispatches one specialist at a time" | "a JWT must be checked for `alg`, `exp`, `aud`, `iss`"; "an ISR must not allocate" |

So: workflow, decision authority, and handoffs stay in `.claude/agents/*.md`. Reusable, technology-
or topic-specific knowledge that *several* agents need becomes a skill — the implementer writing an
endpoint and the reviewer checking it should be reading the same list. Rules that must fire on
**every** task (the §3a/§3b/§3c quality gates, the §2 architecture rules) stay inline in
`AGENTS.md`: a skill is offered by pattern match, which is exactly the wrong mechanism for
something that must never be missed — and Copilot/Codex get no auto-offer at all.

## The catalogue

### Technology stacks

| Skill | Covers | Triggers on |
|-------|--------|-------------|
| **stack-embedded** | C/C++ firmware: HAL/driver separation, no allocation after init, ISR discipline, watchdog, deterministic timing, cross-toolchain (in WSL on Windows), host tests against a mocked HAL | MCU/RTOS/bare-metal projects, `arm-none-eabi`, "firmware", "ISR", "HAL" |
| **stack-mobile** | Flutter/Dart, Kotlin/Android, Swift/iOS: UI→presentation→domain←data layering, one state-management choice, process death and offline/sync, Keystore/Keychain, store constraints, the mobile test pyramid | a Flutter app, an Android module, an iOS target |
| **stack-web-frontend** | Angular/React/Vue: feature-sliced structure, server state vs client state, DTO→view-model mapping, XSS and token handling, Core Web Vitals budgets, i18n, a11y, Testing-Library + Playwright | a browser front-end in the repo |
| **stack-backend** | Spring/Quarkus/Jakarta, .NET, Rust, Node, Go, Python: hexagonal layering with ports, transaction boundaries, 12-factor config, resilience (timeouts, retries, breakers), observability, FOSS-first choices, Testcontainers | any server-side service |

### Integration & data architecture

| Skill | Covers | Triggers on |
|-------|--------|-------------|
| **api-design** | REST versioning/status codes/pagination/idempotency/`problem+json`/OpenAPI/`.http` files (§3b), when SOAP is legitimate and how to migrate off it, GraphQL and gRPC trade-offs | creating or changing an endpoint, WSDL, OpenAPI spec or client |
| **messaging-events** | when async beats synchronous, Kafka/RabbitMQ/NATS/SQS choice, at-least-once + idempotent consumers, the transactional outbox, ordering, schema evolution, DLQs, sagas | a queue, topic, broker, event or background job |
| **data-storage** | relational default and §3c, when NoSQL is actually justified, embedded DBs (SQLite/Room/Drift/Realm), Redis as cache with real invalidation, Elasticsearch as a derived read layer, indexing and migrations | a datastore, cache, search index or migration |
| **cloud-native** | container images (multi-stage, non-root, pinned), 12-factor, K8s probes/limits/rollout/secrets, EC2 immutable images, modular monolith vs microservices, observability and cost | Dockerfile, compose, K8s/Helm manifests, deployment pipelines |

### Cross-cutting

| Skill | Covers | Triggers on |
|-------|--------|-------------|
| **security** | OWASP Top 10 as a review raster + ASVS levels, IAM least privilege with roles and short-lived credentials, API authN/authZ (§3b), secrets, crypto choices, supply chain (pinning, scanning, no `curl \| sh`) | auth, sessions, tokens, permissions, crypto, uploads, deserialisation, user input reaching a query or shell, IAM policy, a new dependency |
| **seo-optimization** | meta tags, Open Graph/Twitter Cards, JSON-LD, robots.txt/sitemap, canonicals, Core Web Vitals, GitHub Pages specifics | any web-facing content |
| **ponytail** | YAGNI decision ladder before new code/dependency/abstraction; `/ponytail-review` audits a diff for over-engineering | off by default (`ponytail.enabled`/`.mode`) |
| **memory-setup** | the memory/context-routing stack: memory files vs Beads vs graphify vs cocoindex-code vs context7, learning intensity, team preferences, Ollama routing | deciding what to persist, or when context routing is unclear |

## Who uses which

The stack and integration skills are read by whoever is doing the work — usually the
**implementer**, the **reviewer** (same checklist, other direction), the **architect** when picking
a technology, and the **tester** for the "test the boring failures" lists. The **security** skill is
the shared raster for the **security-advisor**, the implementer and the reviewer, so a finding
reads the same wherever it comes from.

## Adding your own

Drop a `<name>/SKILL.md` into `.claude/skills/` with YAML frontmatter (`name`, `description`). The
**description is the trigger** — write it as "invoke when …" plus the concrete words that should
match, not as a title. Keep the body a checklist an agent can act on; if it reads like an essay it
will not change any behaviour.

**Quote a description that contains a colon.** `description: … two hats: architect …` is invalid
YAML (the `": "` reads as a nested mapping key) and nothing warns you: a skill or command silently
falls back to its body text as the description — so it stops matching the trigger words you wrote
— and an **agent** with a broken frontmatter block is dropped from the roster entirely. Wrap the
value in double quotes, or single quotes if the text itself contains double quotes. The generated
project's `pre-commit` hook runs `.github/scripts/check-frontmatter.py` over every agent, command,
and skill as soon as you stage one, and CI runs it again on every push. The hook needs
`python3`/`python` + PyYAML; without them it says so and skips, so CI stays the backstop.

For projects that use `aiflow project-update`, skills are refreshed from the templates like agents
and commands — a customised file is backed up to `<file>.bak` first, never overwritten silently.
