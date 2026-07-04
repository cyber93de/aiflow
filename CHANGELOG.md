# Changelog

All notable changes to **aiflow** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Docs
- **Per-OS install sections** (Windows · Linux · macOS) with full commands in the READMEs (EN/DE)
  and `docs/installation.md`, each with its own terminal GIF (new Windows/PowerShell demo).
- **Two more terminal GIFs:** the delivery **workflow** end to end (task → pre-analysis → PO
  question with recorded decision → versioned+secured API → tests + `.http` → review PASS → close)
  and **brownfield onboarding** (init detects existing code → onboarder learns it → proposes the
  project aim for confirmation → `aiflow modernize-check`); embedded in READMEs, workflows,
  getting-started, and example-project pages.
- **Documentation-site link** ([cyber93de.github.io/aiflow](https://cyber93de.github.io/aiflow/))
  now in the README header line (EN/DE).

## [0.1.1] — 2026-07-04

Quality-focused agent upgrade: the implementer now works like a senior engineer (strategy before
code), the reviewer reviews like an architect, and every implementation passes explicit quality
gates — static analysis, coverage, BDD tests, logging, and IDE-testable REST interfaces.

### Agents
- **implementer → senior engineer.** Mandatory **pre-analysis before any code**: current
  architecture, how it changes, effort, complexity, risks; missing information is gathered *before*
  implementation. Questions whether the requirement fits the existing architecture and performs
  **targeted refactoring** when it doesn't (or escalates to the architect). Prefers **established
  open-source frameworks and design patterns over self-implementations**, avoids duplicated code,
  designs for reuse and generic solutions, and always watches overall quality, performance, and
  security.
- **PO-level clarification + recorded decisions.** Functional questions are phrased so a product
  owner understands the hurdle (plain language, options with consequences); the user picks, and
  every decision is **recorded** (`/beads:decision` / `bd update --design`).
- **Design principles codified.** The implementer builds by SOLID, DRY, KISS, YAGNI, high
  cohesion/low coupling, no cyclic dependencies, small methods/classes, robust error/input/null
  handling, thread safety where relevant, and testability by design (DI, no hidden dependencies,
  deterministic, mockable).
- **reviewer → architect *and* quality gate in one agent.** Architect hat: architecture integrity
  (does the change break the architecture? was an adaptation necessary — and done sensibly +
  recorded as ADR?), design (SOLID, clean architecture, domain model, abstraction level),
  maintainability (technical debt, over-/under-engineering), risks (vulnerabilities, performance,
  concurrency, API breaking changes, backward compatibility). Quality-gate hat: an objective
  release checklist (findings addressed, tests green, no new smells/violations, metrics met,
  docs/changelog updated, requirement fully implemented) — verdict PASS (release) or CHANGES
  REQUIRED (back to the implementer). Out-of-scope improvement ideas are persisted as
  `[suggestion]` beads so the next loop picks them up.
- **tester → test/QA engineer.** Systematic coverage (happy path, negative, edge, boundary,
  exceptions, invalid inputs) plus a test-quality audit (meaningful assertions, deterministic,
  independent, understandable); enforces the coverage gates and the BDD pyramid. Runs **adaptively**
  — when the implementer's pre-analysis flags high risk/complexity, or on demand.
- **Objective metric targets** (new table in CLAUDE.md §3a): low cognitive/cyclomatic complexity,
  0 % new duplication, no new code smells, ≥ 80 % coverage of changed logic, 0 architecture
  violations, 0 linter/compiler warnings, 0 high/critical security findings, breaking changes only
  with recorded justification.

### Quality gates (new CLAUDE.md §3a — mandatory on every implementation)
- **Static code analysis, always:** use the project's tool (e.g. SonarQube) when available;
  otherwise the agent performs the analysis itself. Code smells are never shipped.
- **Coverage:** > 80 % line coverage on touched code; **every non-static method tested**.
- **Test pyramid:** unit + end-to-end tests always mandatory; integration/system tests where they
  add signal (skips must be justified). **BDD (Given/When/Then)** is mandatory for end-to-end,
  system, and acceptance tests.
- **Logging is quality:** no-logging is a defect; correct levels (`debug`/`info`/`warn`/`error`),
  standard logging frameworks, never secrets in logs.

### Database modelling rules (new CLAUDE.md §3c)
- **New data models** follow 20 explicit design rules (R1–R20): ≥ 3rd normal form (denormalisation
  only documented + measured), no redundant data, m:n via junction tables, real foreign keys (no
  soft references), no needless surrogate keys, `NOT NULL` by default, business rules as `CHECK`
  constraints, `UNIQUE` on natural keys, precise data types, no magic values, only necessary
  indexes, smallest sufficient types, large objects outside the DB, no overly wide tables, one
  naming convention, no cryptic abbreviations, lookup tables over status numbers, referential
  integrity everywhere, cascades only deliberately, soft delete/history where the domain needs it.
- **Brownfield caution (B1–B8): existing schemas are handled with care.** They may be shared by
  other applications and must support rollback to older app versions — so restructuring, re-keying,
  adding constraints, changing types, merging/splitting tables, or late normalisation never happen
  as a side effect of a feature task. Improvement potential is **documented as recommendation
  beads**; a commissioned schema change is treated as high-risk work (external-consumer check,
  backward-compatibility/rollback plan, versioned migration). The reviewer blocks uncommissioned
  structural changes smuggled into a diff.

### REST interfaces (new CLAUDE.md §3b)
- **Versioned and secured by default:** every REST API carries a version from day one
  (`/api/v1/…`; breaking changes → new version with a deprecation window) and real
  authentication — **Basic Auth is insufficient**: OAuth 2.x / OpenID Connect, short-lived JWT
  bearer tokens, or managed API keys with rotation; mTLS for service-to-service where warranted;
  authorisation checked per endpoint. The reviewer's gate checklist enforces both.
- Every new/changed REST endpoint ships a matching **`.http` file** (`http/<resource>.http`,
  IntelliJ HTTP Client / VS Code REST Client) covering happy path + auth + error case.
- Host, port, test user, and password come from **`.env`** (`APP_HOST`, `APP_PORT`,
  `TEST_USERNAME`, `TEST_PASSWORD` — seeded in `.env.example`); the agent may read `.env` to fill
  them. IntelliJ credentials go into the now-gitignored `http-client.private.env.json`.

### Ralph loop
- The implementer **decides automatically** from its pre-analysis (architecture impact, effort,
  complexity) whether the Ralph loop is worthwhile, and states the decision with its reason.
  Manual triggers win: `/implement <bead> ralph|no-ralph` in the session, or a directive written
  **into the issue itself** ("use the Ralph loop").

### CLI
- **`--no-token-saving`** for `aiflow init` and `aiflow change-settings` — switches **caveman and
  rtk off** in one flag for full, unfiltered output.

### Production readiness & architecture hygiene (CLAUDE.md §3a)
- **Production-ready awareness for all agents:** every implementation targets production; agents
  are very careful with low-maturity technology (experimental, pre-1.0, unmaintained), and the
  **reviewer and tester must flag it**.
- **Class size & KISS:** classes ballooning into hundreds of lines trigger **divide & conquer** —
  split responsibilities, encapsulate behind interfaces (introduced layer structures must be
  coherent with the rest of the codebase); accepted exception: utility libraries offering method
  overloads for flexible call sites.
- **State-of-the-art check:** legacy requests (SOAP instead of REST, XML-over-REST instead of
  JSON, 1980s-style MQ patterns instead of modern brokers/cloud-native eventing) are **questioned
  as PO-level decisions**, never silently built — EOL/unsupported technology is flagged as a
  maintainability *and* security risk.
- **Monolith avoidance:** modular boundaries and service-ready seams even when microservices
  aren't explicitly required.
- **Deliberate data/performance choices:** agents evaluate whether in-memory stores (**Redis**,
  **SQLite**) or a search/caching layer (**Elasticsearch**, which also decouples the database from
  the application) bring a measurable win — proposed to the PO, decision recorded.

### New on-demand checker agents (not part of the delivery loop)
- **accessibility-checker** (`aiflow a11y-check` / `/a11y-check`) — strict **WCAG 2.2 AA** audit
  of all UI surfaces (perceivable/operable/understandable/robust: alternatives, semantics,
  contrast, keyboard, focus, labels, ARIA); files `[accessibility]` beads and recommends an
  automated a11y tool for the E2E suite (axe-core with Playwright/Cypress, Pa11y, Lighthouse CI).
- **modernization-advisor** (`aiflow modernize-check` / `/modernize-check`) — walks the entire
  brownfield codebase and proposes modernisation **concepts as a report**
  (`.aiflow/modernization-report.md`) for the architect to review manually and optionally feed
  into Beads: EOL/unsupported stacks first (maintainability + security lead), monolith →
  **microservice** extraction candidates (strangler-fig), SOAP/XML/legacy MQ → **REST/JSON +
  cloud-native eventing**, **svn → git**, containerisation/CI/observability gaps, and concrete
  **unit/BDD/E2E test frameworks** when the project lacks them. Report only — no code changes,
  no beads.

### Docs (agents)
- READMEs and the docs site now describe **precisely what each agent does and watches for**
  (detailed per-agent sections in docs → Agents, shared ground rules called out).

### Onboarding & project aim
- **onboarder proposes the project aim** on brownfield projects — derived from the understanding it
  built, written to `project-aim.md`, and **confirmed by the user** (interactive: asks directly;
  headless: marked `PROPOSED — please confirm`). Never adopted silently.
- **Project-aim guidance** in the READMEs, docs, and the CLAUDE.md template: where to set it
  (`aiflow init` / `change-settings`, or manually in `.claude/memory/project-aim.md` +
  `CLAUDE.md §1`) and how to write it (2–4 sentences: what, for whom, target architecture,
  quality bar) — it tunes Claude to the project and is the cheapest quality lever.

### Docs
- **Positioning made explicit:** aiflow ships one very good, **universal base configuration** —
  deliberately **generic agents** meant to be customised per project — because a strong base config
  beats the blank-Claude start most AI projects begin with (~70–80 % less configuration effort).
- **Terminal GIFs** (install · init Q&A incl. Ollama model selection and git/svn · change-settings)
  embedded in the READMEs (EN/DE) and the docs site; reproducible sources in
  `docs/assets/terminal/` (`make-casts.mjs` + agg).
- **New docs pages:** **AI Basics** (plain-language primer for beginners: Claude Code, agents,
  memory, context windows, skills, hooks, MCP, tokens) and an **example-project walk-through**
  (every init question with its default, what gets generated, and a first feature built
  end-to-end).
- **Honest token framing** in READMEs and docs: token saving is a goal but only partially achieved
  per task because of the quality rules — the net win is that production-ready-first-pass work
  needs no re-prompting or rework, which saves tokens *and* time.
- **Positioning hook:** "Most people struggle to set up their AI project successfully — this tool
  is built to fix exactly that." Production-ready code as the stated project goal (reusable,
  reliable, secure, current standards, architecture-aware, with optional accessibility /
  modernisation / security reports).

## [0.1.0] — 2026-07-03

First public release. aiflow turns any repository into a governed, AI-driven software-delivery
pipeline with one command — Claude Code wired to durable task memory, a two-layer code memory
(structural graph + semantic RAG), specialist agents, team collaboration, token savings, and a real
release process. Everything is project-scoped; secrets never leave the project.

### Setup & configuration
- **`aiflow init`** — interactive Q&A that writes `.aiflow/config.json` and renders the whole project
  (`.mcp.json`, hooks, memory, branching, git hooks) from it.
- **`aiflow change-settings`** — re-run the Q&A and re-render everything idempotently.
- **`aiflow install-deps`** (`--all`) — install only the tools your config enables; user-space,
  cross-platform (winget/scoop, Homebrew, apt/dnf/pacman, official scripts).
- **`aiflow doctor`** — prerequisite check plus a per-project summary (remote + host MCP, VCS,
  Ollama models, memory graph/RAG/context7 + intensity).
- **Installer prompts** — `install.sh` / `install.ps1` offer to also install **git**, **Subversion
  (svn)**, and **Ollama**, so `init` later only asks which models to pull.
- **Version control choice** — pick **git**, **svn**, or **none** at setup; git hooks and branching
  governance are wired only for git.

### Version control hosts (token-based, no OAuth)
- **Remote types** — `github`, `github-enterprise`, `gitlab`, `gitlab-self`, `bitbucket`,
  `forgejo`, `gitea`, `custom` (any base URL), or `none`.
- **Host-specific MCP catalog** — the matching git-host MCP is wired automatically per remote type,
  with the base URL threaded into the server (`GITHUB_HOST` / `GITLAB_API_URL` / `GITEA_URL`).
- **Configurable token env** — `remote.tokenEnv` (e.g. `GITHUB_TOKEN`, `GITLAB_TOKEN`,
  `GIT_REMOTE_TOKEN`); everything is API-token based, never OAuth for git hosts.
- **Beads ↔ host sync** derived from the git remote for GitHub/GitLab.

### Models
- **Claude access** — choose `apikey` (`ANTHROPIC_API_KEY`) or `oauth` (`CLAUDE_CODE_OAUTH_TOKEN`).
- **Ollama** — optional local models (no key): select at init (newest **qwen3-coder** recommended),
  install/manage via **`aiflow ollama [pull|add|list]`**; models are wired into
  `.aiflow/router-config.json` so they're actually used.
- **Model routing** — claude-code-router sends easy/background steps to cheap/local models
  (`aiflow shell --router`); add cloud providers (DeepSeek, OpenRouter, Gemini, …).

### Memory & context
- **Two-layer code memory** — **graphify** (structural graph: imports/call-graph) + **cocoindex-code**
  (semantic RAG: AST-aware, local embeddings, no key, ~70% fewer tokens).
- **`aiflow index`** — one command refreshes **both** indexes (`graphify build` + `ccc index`).
- **context7 MCP** — live, version-correct external library docs (keyless, optional key).
- **Retrieval routing policy** — a generated `.claude/memory/memory-policy.md` tells the agent which
  source to hit (Beads → memory files → graph → RAG → context7 → read files).
- **Learning intensity** — `memory.intensity` (`aggressive` default / `normal` / `light` / `off`).
- **Persistent memory files** — `project-aim.md`, `dev-environment.md`, `memory-policy.md`, indexed
  in `.claude/MEMORY.md`.

### Team collaboration
- **Shared issue graph** — Beads issues in a Dolt database synced over `refs/dolt/data` on the git
  remote; no extra server.
- **Session-start auto-pull** — a `SessionStart` hook runs `bd dolt pull` (safe, never pushes;
  opt-out `sync.pullOnStart`).
- **Atomic claiming** — `bd ready --claim` / `bd update --claim` prevents two people grabbing one task.
- **`aiflow sync [pull|push|both]`** and **`aiflow close-sync`** — pull-before-push so teammates'
  issue changes are never clobbered.
- **Sync gate on close** — closing an issue prompts to push + Dolt-sync (`sync.askOnClose`).
- **Shared team preferences** — versioned `.aiflow/team-prefs.json` (code style, language,
  conventions) overriding `CLAUDE.md §3`.

### Agents & workflow
- **Delivery agents** — architect, planner, implementer, reviewer, tester.
- **Audit agents** — security-advisor, quality-check, dependency-auditor, test-gap-advisor,
  performance-advisor, docs-sync, requirements-check (file prioritised Beads issues).
- **Brownfield** — `aiflow onboard` learns an existing codebase into memory + CLAUDE.md + arc42.
- **Slash skills** — `/intake-issue`, `/decompose`, `/plan-epic`, `/implement`, `/review-ac`,
  `/arch`, the audit commands, `/onboard`, `/explain`, `/standup`.
- **Ralph loop** — autonomous iterate-until-done, interactive / headless (`aiflow ralph`) / in CI.

### Quality, git & releases
- **Google style** for all languages, **Conventional Commits**, `pre-commit`/`commit-msg`/`pre-push`
  git hooks (format + lint + tests + branch rules).
- **Branching models** — `simple` / `gitflow` / `none`, PR-only, auto-release, SemVer/CalVer,
  `chore/*`; enforced by hooks + `aiflow protect` + `aiflow release`.

### Token & cost optimisation
- **caveman** terse output (~75% fewer output tokens) and **rtk** CLI-output filtering (60–90% fewer)
  are **on by default**; graph/RAG retrieval; `aiflow cost` (ccusage) baseline.

### Containers & CI/CD
- **Headless container runs** — `docker/run.sh` works with **Podman or Docker** (auto-detected;
  `AIFLOW_CONTAINER` override). (Dagger was evaluated and dropped as redundant.)
- **Workflows** — `ci.yml` (validate scripts + JSON + PowerShell + dry-run build), `release.yml`
  (tag + per-OS archives on `VERSION` bump), `pages.yml` (deploy the docs site). Generated projects
  also get `ci.yml` + `agent.yml` (Ralph loop in CI).

### Custom MCP servers
- Add any MCP server to `.mcp.json`; entries aiflow doesn't manage are preserved on re-render.

### Docs & project
- **Extensive README** in English and German (24 sections).
- **GitHub Pages documentation site** under `docs/` (just-the-docs).
- **MIT License**; **no funding / donation prompts** — feedback, a ⭐, and bug reports are the ask.

[Unreleased]: https://github.com/Cyber93de/aiflow/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/Cyber93de/aiflow/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Cyber93de/aiflow/releases/tag/v0.1.0
