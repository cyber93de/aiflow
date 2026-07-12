---
layout: default
title: Changelog
parent: Support
nav_order: 4
description: "aiflow changelog and release history: 0.2.0 cross-platform scripts + self-update, 0.1.1 quality-gate release, and the 0.1.0 first public release."
---

# Changelog
{: .no_toc }

aiflow follows [Keep a Changelog](https://keepachangelog.com/) and
[Semantic Versioning](https://semver.org/). The authoritative, always-current changelog lives in the
repository: **[CHANGELOG.md](https://github.com/Cyber93de/aiflow/blob/main/CHANGELOG.md)**.

## 0.2.0 — cross-platform scripts, self-update, no more broken nightly agent

Highlights:

- **Removed the nightly `aiflow-agent` workflow** — it ran an unattended Ralph loop on a cron
  in every scaffolded project and always failed without a configured token. Dropped from the
  templates; `aiflow init` no longer generates it.
- **Every invoked project script now ships as a `.sh` + `.ps1` pair** — hooks
  (`format`/`caveman`/`beads-sync`), audits (`security-check`/`quality-check`/
  `requirements-check`), `ralph-headless`, `run-agent`, `release`/`version`/`protect`,
  `bd-close-sync`, and `docker/run`. `apply.sh` writes the OS-correct interpreter into
  `.claude/settings.json`'s hook commands based on `dev.os` — Windows projects no longer need
  Git-Bash to run their own hooks/checks.
- **`aiflow update`** self-updates the CLI install; **`aiflow project-update`** refreshes a
  single project's mechanical scripts from the installed templates. Projects now stamp the
  aiflow version they were generated with and get prompted to upgrade when it falls behind.
- **"Built with aiflow" README badge** inserted idempotently on `apply` — visible provenance
  without ever overwriting an existing README.

## 0.1.1 — quality gates & senior-engineer agents

Highlights:

- **implementer as senior engineer** — mandatory pre-analysis (architecture, change impact, effort,
  complexity) before code; architecture-fit check with targeted refactoring; SOLID/DRY/KISS/YAGNI,
  testable by design (DI, deterministic); proven open-source frameworks and design patterns over
  self-implementations; no duplication, reusable/generic solutions; PO-level clarification
  questions with **recorded decisions**.
- **reviewer as architect + quality gate (one agent)** — architecture/design/risk review (layers,
  module boundaries, tech debt, over-/under-engineering, vulnerabilities, concurrency, breaking
  changes) plus an objective release checklist; verdict PASS or CHANGES REQUIRED; suggestions
  persisted as `[suggestion]` beads for the next loop.
- **tester as test/QA engineer** — negative/edge/boundary/exception/invalid-input tests plus
  test-quality audit (assertions, determinism, independence); runs adaptively when the
  pre-analysis flags high risk/complexity.
- **Objective metric targets** — 0 % new duplication, no new smells, 0 architecture violations,
  0 linter/compiler warnings, 0 high/critical security findings (CLAUDE.md §3a table).
- **Production readiness & architecture hygiene** — production-ready output only (low-maturity
  tech flagged by reviewer + tester), small classes/KISS with divide & conquer + interfaces,
  monolith avoidance, state-of-the-art check (SOAP/XML/legacy-MQ requests are questioned as
  PO decisions), deliberate Redis/SQLite/Elasticsearch consideration.
- **New checkers (on demand, outside the loop)** — **accessibility-checker** (`aiflow a11y-check`,
  strict WCAG 2.2 AA → `[accessibility]` beads + E2E-a11y-tool recommendation) and
  **modernization-advisor** (`aiflow modernize-check`, brownfield modernisation concepts as a
  report for the architect: microservices, REST/cloud-native, git over svn, supported stacks,
  missing test frameworks).
- **Quality gates (CLAUDE.md §3a)** — static analysis on every implementation (tool or the agent
  itself), > 80 % line coverage + all non-static methods tested, unit + BDD end-to-end always,
  integration/system where sensible, leveled logging required.
- **REST versioned + secured (§3b)** — `/api/v1/…` from day one; OAuth2/OIDC, JWT, or managed API
  keys — **Basic Auth is insufficient**; every new/changed endpoint ships an IDE-testable `.http`
  file (host/port/test credentials from `.env`).
- **Database rules (§3c)** — new models: ≥3NF, real FKs, constraints, precise types, junction
  tables, no needless surrogate keys (R1–R20). Brownfield: existing schemas handled with care
  (shared consumers, rollback to older app versions) — improvement potential becomes
  recommendation beads, never side-effect fixes; commissioned changes need consumer check +
  rollback plan (B1–B8).
- **Ralph loop** — the implementer decides **automatically** from its pre-analysis; manual
  triggers win (`/implement <bead> ralph|no-ralph`, or a directive written into the issue).
- **`--no-token-saving`** — `aiflow init` / `aiflow change-settings` flag that switches caveman +
  rtk off for full, unfiltered output.
- **Project aim** — onboarder proposes an aim from brownfield code and asks the user to confirm;
  aim-writing guidance (where + how) added to READMEs, docs, and the CLAUDE.md template.
- **Positioning** — aiflow = one strong, universal base config with deliberately generic,
  customisable agents; ~70–80 % less configuration effort than starting Claude blank.
- **Terminal GIFs** — install, init Q&A, and change-settings demos in the READMEs and docs.
- **New docs** — [AI Basics](ai-basics) (plain-language primer) and the
  [example-project walk-through](example-project) (all defaults + first feature end-to-end);
  honest token framing (quality rules spend tokens; first-pass-production-ready saves them).

## 0.1.0 — first public release

Highlights:

- **Setup** — `aiflow init` interactive Q&A → `.aiflow/config.json` → renders the whole project;
  `change-settings`, `install-deps`, `doctor`; installer offers git/svn/Ollama.
- **Version control & remotes** — git / svn / none; token-based GitHub, GitHub Enterprise, GitLab,
  self-managed GitLab, Bitbucket, Forgejo, Gitea, or custom — with the matching host MCP wired.
- **Models** — Claude API key or OAuth; Ollama local models (qwen3-coder recommended); model routing.
- **Memory** — graphify structural graph + cocoindex-code semantic RAG + context7 docs + a retrieval
  routing policy; `aiflow index` refreshes both indexes.
- **Team** — shared Dolt issue graph, session-start auto-pull, atomic claiming, pull-before-push.
- **Agents & workflow** — delivery + audit + brownfield agents, slash skills, the Ralph loop.
- **Quality, git & releases** — Google style, Conventional Commits, enforcement hooks, branching
  models, `aiflow release`.
- **Token savings** — caveman + rtk on by default; graph/RAG retrieval; `aiflow cost`.
- **Containers & CI/CD** — Podman/Docker headless runs; `ci.yml`, `release.yml`, `pages.yml`.
- **Docs & project** — extensive README (EN/DE), this documentation site, MIT license, no funding
  prompts.

See the full list in [CHANGELOG.md](https://github.com/Cyber93de/aiflow/blob/main/CHANGELOG.md).
