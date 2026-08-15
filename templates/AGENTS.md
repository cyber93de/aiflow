# Project Operating Rules (aiflow)

<!-- aiflow config flags - tooling reads these -->
<!-- AIFLOW_MEMORY: off -->

This file governs how AI coding agents work in this repo — **agent-agnostic**: Claude Code,
GitHub Copilot, OpenAI Codex CLI, or any tool that reads a repo-root instructions file. It is the
single source of truth shared by interactive sessions and headless/CI runs. Edit the sections
marked **[EDIT ME]** for your project.

Sections marked **(Claude Code only)** describe subagents/hooks/slash-commands that only Claude
Code can invoke automatically. Every other agent still follows the same workflow and rules —
manually, step by step, in the order described — it just doesn't get the automated
dispatch/enforcement. `CLAUDE.md` in this repo root is a one-line pointer that makes Claude Code
load this exact file; Codex CLI and most other tools read `AGENTS.md` directly by convention.
GitHub Copilot reads `.github/copilot-instructions.md`, which also just points here.

---

## 1. Project overview  [EDIT ME]

> One paragraph: what this project is, who uses it, the tech stack.
> Replace this block.

- **Stack:** <language / framework>
- **Entry point:** <main file / app start>
- **Run locally:** <command>
- **Test:** <command>

> **Project aim (fill it in — the cheapest quality lever).** Every agent reads the aim before
> planning or coding; without it it works generically instead of tuned to *this* project.
> Set it via `aiflow init` / `aiflow change-settings`, or write it manually here **and** in
> `.claude/memory/project-aim.md`. 2–4 plain sentences: *what* the product does, *for whom*,
> the *target architecture*, the *quality bar*. On a brownfield project, `aiflow onboard`
> proposes an aim from the code — confirm or correct it, never leave it `PROPOSED`.

---

## 2. Architecture hints  [EDIT ME]

> High-level rules an agent must respect. Keep concrete. Examples:

- Layering: `api -> service -> repository -> db`. No layer skips.
- Dependency direction: domain never imports infrastructure.
- Public API lives in `<dir>`. Internal helpers in `<dir>`.
- Persistence: <db / ORM>. Migrations in `<dir>`.
- Errors: never swallow; wrap with context.
- Full architecture document: `docs/architecture/` (arc42). Update it when structure changes.

---

## 3. Code style — Google Style, every language (MANDATORY)

All code follows the **Google Style Guides** regardless of language:
https://google.github.io/styleguide/

Defaults the agent must apply:
- **Indent:** spaces, not tabs (2 for most; 4 for Python).
- **Line length:** 80–100 cols (language-specific Google limit).
- **Naming:** Google conventions per language (e.g. `lowerCamelCase` vars in Java/JS/Dart/Go-exported, `snake_case` in Python, `PascalCase` types).
- **Imports:** ordered & grouped per the relevant Google guide.
- **Comments:** doc comments on every public symbol; explain *why*, not *what*.
- **No dead code, no commented-out blocks** left behind.

Per-language formatter/linter (run before declaring work done):
| Language   | Formatter            | Linter            |
|------------|----------------------|-------------------|
| Python     | `black` + `isort`    | `pylint` (Google rc) / `ruff` |
| JS/TS      | `prettier`           | `eslint` (google config) |
| Java       | `google-java-format` | `checkstyle` (google_checks.xml) |
| Go         | `gofmt`/`goimports`  | `golangci-lint`   |
| Dart/Flutter | `dart format`      | `flutter analyze` |
| C++        | `clang-format` (Google style) | `clang-tidy` |
| Shell      | `shfmt`              | `shellcheck`      |

If a formatter is missing, the agent still writes code in Google style by hand and
notes the missing tool. The `format` hook auto-formats edited files when the tool exists
**(Claude Code only — Copilot/Codex: run the formatter yourself before finishing).**

---

## 3a. Quality gates — analysis, tests, logging (MANDATORY, every implementation)

**Static code analysis** happens on every implementation:
- If the project provides a tool (SonarQube, a full linter suite, `spotbugs`, …), run it and fix
  what it reports on the touched code.
- If **no tool** is available, the agent performs the analysis **itself**: scan the changed code
  for code smells (long methods, deep nesting, god classes, magic values, dead code, duplication,
  needless complexity) and fix them before finishing. "No tool" is not an excuse — **code smells
  are never shipped**.

**Test pyramid** (choose deliberately, don't skip silently):
- **Unit tests — always mandatory.** > 80 % **line coverage** on the touched code, and **every
  non-static method has a test**.
- **End-to-end tests — always mandatory**, written in **BDD style** (Given/When/Then, e.g.
  Gherkin/Cucumber or the project's BDD framework).
- **Integration tests** and **system tests** — add them where they carry real signal (I/O
  boundaries, service seams, cross-module flows). If skipped, say why in the handoff.
- **BDD is mandatory** for end-to-end, system, and acceptance tests. Unit tests stay in the
  project's normal test framework/style.
- Prefer well-established test frameworks over hand-rolled harnesses.

**Logging is part of quality:**
- An application without logging is a quality defect — flag it and fix it in the code you touch.
- Use **levels** correctly: `debug` (diagnostic detail), `info` (business events), `warn`
  (recoverable anomaly), `error` (failure with context). Never log secrets or personal data.
- Use the ecosystem's standard logging framework (slf4j/logback, `logging`, pino/winston, …),
  never `print`/`console.log` in production code.

**Design principles** (implementer builds by them, reviewer verifies them):
SOLID · DRY · KISS · YAGNI · high cohesion, low coupling · no cyclic dependencies · small
methods/classes, self-explanatory names · error handling + input validation + null/Optional
handling everywhere · thread safety where concurrency applies · testable by design (dependency
injection, no hidden dependencies, deterministic, mockable).

**Class size & KISS in practice:**
- Classes stay small. A class ballooning into hundreds of lines is a signal to stop and apply
  **divide & conquer**: split responsibilities, extract collaborators, encapsulate logic behind
  **interfaces**. If that requires its own layer structure, it must be **coherent in itself and
  consistent with the rest of the codebase** — no one-off layering.
- Legitimate exception: utility classes/libraries consumed by other applications may offer the
  same method in several overloads (different argument counts) for flexible call sites.

**Production readiness & technology choices (MANDATORY):**
- Every implementation targets **production**, not a demo. Be very careful with technology that
  lacks maturity (experimental libraries, pre-1.0/alpha releases, unmaintained projects):
  prefer proven alternatives, and if an immature choice is genuinely justified, record it as a
  decision. **Reviewer and tester must flag low-maturity tech** in a change.
- **State of the art is the default — question legacy choices.** If a requirement asks for
  SOAP instead of REST, XML payloads on REST instead of JSON, or 1980s-style message-queue
  patterns instead of modern brokers/cloud-native eventing (Kafka, NATS, RabbitMQ, K8s-native),
  don't silently build it: ask **why** (PO-level question, options + consequences) and record
  the decision. Outdated and end-of-life technology is a maintainability **and security** risk —
  nothing is more fatal than systems whose stack has no support anymore.
- **Avoid growing a monolith.** Even when microservices are not explicitly required, design
  modular boundaries and service-ready seams so parts can be extracted later.
- **Consider the data/performance architecture deliberately:** would an in-memory store
  (**Redis**, **SQLite**) bring a measurable performance win? Would a search/caching layer
  (**Elasticsearch**) decouple the database from the application and absorb read load? Evaluate
  when the requirement touches performance or search, propose it to the PO, record the decision.

**Metric targets** (objective — every agent honours them, the quality gate checks them):

| Metric | Target |
|--------|--------|
| Cognitive / cyclomatic complexity | as low as practical; no new hotspots |
| Code duplication | **0 % new** duplicates |
| Code smells | **no new** smells |
| Test coverage | **≥ 80 %** of changed logic (lines); all non-static methods |
| Architecture violations | **0** |
| Linter warnings | **0** |
| Compiler warnings | **0** |
| Security findings | **0** high/critical |
| API breaking changes | only with recorded justification |

---

## 3b. REST interfaces — versioning, security, `.http` files (MANDATORY)

**Every REST API is versioned and secured:**
- **Versioning from day one** — URI versioning (`/api/v1/…`) as the default (or header/media-type
  versioning if the project already uses it). Breaking changes go into a new version; old versions
  get a documented deprecation window. An unversioned new API is a review finding.
- **Real authentication/authorisation** — **Basic Auth is insufficient** for anything beyond a
  throwaway local demo. Use the current standards: **OAuth 2.x / OpenID Connect**, JWT bearer
  tokens (short-lived, validated signature + expiry + audience), or managed API keys with rotation;
  mTLS where service-to-service traffic warrants it. Always HTTPS, never credentials in URLs,
  authorisation checked per endpoint (not just "logged in").

Every **new or changed REST endpoint** ships a matching **`.http` file** (IntelliJ HTTP Client /
VS Code REST Client compatible) so it can be exercised straight from the IDE:

- Location: `http/<resource>.http` — one file per resource/controller, one request block per
  operation. Cover the happy path plus at least one auth and one error case.
- **Host, port, test user, and password come from `.env`** (`APP_HOST`, `APP_PORT`,
  `TEST_USERNAME`, `TEST_PASSWORD` — see `.env.example`). The agent **may read `.env`** to pick
  the right values; if the keys are missing it adds them to `.env.example` and documents them.
- Reference the values instead of hard-coding secrets: VS Code REST Client reads
  `{{$dotenv APP_HOST}}` directly from `.env`; for IntelliJ keep a small `http-client.env.json`
  (public values only) next to the files and put credentials in the **gitignored**
  `http-client.private.env.json`.
- Keep the files current — a changed endpoint with a stale `.http` file is a review finding.

---

## 3c. Database modelling rules (MANDATORY)

Two regimes. Which one applies is decided **per schema object**, not per project: anything you
create new follows the design rules; anything that already exists falls under the brownfield rules.

### New data models (tables/schemas the agent creates)

**Modelling**
- **R1 — At least 3rd normal form.** Deliberate denormalisation only with a documented, measurable
  performance win.
- **R2 — No redundant data.** Each fact stored once; duplication must be justified.
- **R3 — m:n only via junction tables.** Never ID lists or CSV values in a column.
- **R4 — Real foreign keys** for every logical relationship — no "soft" references
  (`customerId INT` without `REFERENCES Customer(id)` is a defect).
- **R5 — No needless surrogate keys.** Junction tables get `PRIMARY KEY (UserId, RoleId)`, not an
  extra `Id` — add one only when it's needed (other tables reference the row, or the relation
  carries attributes).

**Constraints**
- **R6 — `NOT NULL` by default.** `NULL` only where "unknown / not applicable" is a real domain state.
- **R7 — Business rules as `CHECK` constraints** where possible (`price >= 0`, `quantity > 0`,
  `percentage BETWEEN 0 AND 100`).
- **R8 — `UNIQUE` on every natural key**, not just primary keys.
- **R9 — Precise data types** (`CHAR(2)` for an ISO country code, not `VARCHAR(500)`).
- **R10 — No magic values** (`-1`, `999999`, `''`) in place of proper modelling.

**Performance**
- **R11 — Only necessary indexes:** primary keys, foreign keys, frequently filtered/sorted columns.
  No index-everything strategy.
- **R12 — Smallest sufficient type** (`SMALLINT` over `BIGINT` when it fits).
- **R13 — Keep large objects out.** BLOBs/large text only when required; prefer storing files
  outside the database.
- **R14 — No overly wide tables.** Many optional columns usually signal a bad model.

**Maintainability & integrity**
- **R15 — One naming convention** — never mixes like `CustomerID` / `customer_id` / `CustId`.
- **R16 — No cryptic abbreviations** (`User`, `Address`, `Order` — not `usr`, `adr`, `ord`).
- **R17 — Lookup tables over status numbers** (`OrderStatus(Id, Name)` instead of `status = 1`)
  when the set can grow; for truly static values (ISO codes, small enums) an ENUM/domain may fit —
  make it a **project-wide decision** and record it.
- **R18 — Referential integrity everywhere.** No orphaned rows possible.
- **R19 — Cascades only deliberately.** `CASCADE DELETE` never by default — only when the domain
  says the children die with the parent.
- **R20 — Question every hard delete.** Use soft delete or history tables where the domain needs
  traceability.

### Existing data models (brownfield — handle with care)

The B rules are **cautionary guidance, not absolute bans**. Why the caution: an existing schema
may be shared by **other applications/projects** you can't see from this repo, and operations may
need to **roll back to an older application version** that still expects the old structure. A
schema change that looks like a pure improvement can break both. So:

- **B1–B7 — don't do these as a side effect of a feature task:** restructuring existing models,
  changing keys, adding constraints, changing data types, merging tables, splitting tables,
  normalising after the fact. Default answer: leave the structure alone.
- **B8 — note the improvement potential instead.** Record every schema problem you find (missing
  FKs/constraints, unjustified NULL columns, redundant data, pointless surrogate keys, missing
  UNIQUEs/indexes, normal-form violations, inconsistent naming) as a **recommendation** — a
  `[technical issue]`/`[suggestion]` bead — for the PO to schedule deliberately.
- **When a schema change IS commissioned** (explicitly, or the PO accepts a recommendation), treat
  it as high-risk: check for **external consumers** of the schema first, plan **backward
  compatibility / rollback** (expand–contract migrations beat in-place changes), version the
  migration, and take it through the review gate like any architecture change.

---

## 4. Task workflow (Beads + acceptance criteria)

Work is tracked in **Beads** (`bd`), a Dolt-backed issue store shared by the whole team — same CLI
regardless of which agent is driving it. Multi-step or multi-session work MUST be a bead. Beads
issues live in a Dolt DB and sync via `refs/dolt/data` on the git remote — so several members
share one issue graph.

0. **Sync first (start of every session):** `aiflow sync` (= `git pull --rebase` + `bd dolt pull`)
   so you see teammates' latest issues/status before picking work. Never work off a stale DB.
1. **Pick + claim work atomically:** `bd ready --claim --json` claims the first ready, unassigned
   bead (sets assignee = you, status = in_progress) in one step. To claim a specific one:
   `bd update <id> --claim`. **Only work a bead you have claimed.** Check `bd ready --unassigned`
   to see what's free; never start a bead already assigned to someone else.
2. **Acceptance criteria:** every task has explicit, checkable AC. If missing, write them first and confirm before coding.
   Functional questions are phrased so a **PO understands the hurdle** (plain language, options
   with consequences); the user picks, and the decision is **recorded** (`/beads:decision`
   **(Claude Code only)**, or `bd update <id> --design` from any agent).
3. **Strategy first:** build a short pre-analysis (current architecture, how it changes, effort,
   complexity) and gather missing information **before** writing code.
4. **Implement:** smallest change that satisfies AC. Follow §2 architecture + §3 style + §3a/§3b
   quality gates.
5. **Verify:** run tests + formatter + linter + static analysis (§3a). AC must be demonstrably met.
6. **Review gate:** one pass, two hats: **architect review** (architecture, design, risks) plus
   the **quality-gate checklist** (§3a metrics, tests, docs) — run `/review-ac`
   **(Claude Code only** — dispatches the `reviewer` subagent; other agents: read §3a/§5 and do
   this pass yourself, or ask the user to review**)**. Fix every BLOCKER/SHOULD; out-of-scope
   improvement ideas are persisted as `[suggestion]` beads for the next loop. When the
   pre-analysis flagged high risk/complexity, a separate **tester** pass runs before the gate.
7. **Commit:** reference the bead id in the message (see §7).
8. **Close** the bead with a note on how AC were verified: `bd close <id> --reason "…"`.
9. **Sync gate (mandatory when enabled):** the moment a bead is closed locally, if
   `.aiflow/config.json → sync.askOnClose` is `true`, run `aiflow close-sync <bead-id>`.
   It **asks** (never automatic) whether to `git push` and whether to Dolt-sync the issue DB.
   It **pulls before it pushes** (`bd dolt pull` → `bd dolt push`) so it never clobbers a
   teammate's changes. Do not push or sync silently, and do not skip the prompt.

A task is **DONE** only when: AC met • quality gates §3a/§3b/§3c passed (tests + coverage, static
analysis, logging, `.http` files, database rules) • style/lint clean • review gate passed •
decisions recorded • bead closed • sync gate honoured.

### 4a. Team collaboration rules (multiple members, one issue graph)
- **Single source of truth:** Beads only. Do NOT use TodoWrite / markdown TODOs / ad-hoc lists.
- **Claim before you touch it.** The atomic `--claim` prevents two people grabbing the same bead.
  If `bd` says a bead is already claimed by someone else, pick another.
- **Pull before push, always.** Issue state is shared; `aiflow sync` / `aiflow close-sync` pull
  first. On a Dolt conflict: `bd dolt pull` (merge), resolve, then push. Never force-push.
- **Small, frequent syncs** beat big ones — push closed/updated beads promptly so others see them.
- **Assignee + status are the coordination signal.** Keep status current (`in_progress` when you
  start via `--claim`, `closed` when done). Stale status = wasted duplicate work.
- **Discovered work → a new bead** (`bd create … --deps discovered-from:<id>`), don't silently
  expand scope; that keeps everyone's ready-list honest.
- **Decisions** that affect others → `/beads:decision` **(Claude Code only** — other agents:
  `bd update <id> --design` or write the rationale directly into the bead**)**, not just a commit.

---

## 5. Agents (Claude Code only)

Specialised subagents live in `.claude/agents/` and are dispatched automatically or via
slash-commands — **this section only applies when Claude Code is driving.** GitHub Copilot and
OpenAI Codex CLI have no equivalent subagent-dispatch mechanism today: follow the same roles and
gates yourself, in the same order, reading the referenced section for each.

- **architect** — system design, arc42 docs, ADRs, trade-offs. Read-only-ish.
- **planner** — break an epic/issue into beads with dependencies + AC.
- **implementer** — senior engineer for one ready bead: strategy-first pre-analysis, architecture
  fit, proven frameworks/patterns over self-built, quality gates §3a/§3b, with tests.
- **reviewer** — architect **and** quality gate in one: architecture/design/risk review plus the
  objective §3a checklist; verdict PASS (release) or CHANGES REQUIRED (back to implementer);
  suggestions persisted as beads. Does not write features.
- **tester** — test/QA engineer: negative/edge/boundary/exception/invalid-input tests plus test
  QUALITY (assertions, determinism, independence). Runs when the pre-analysis flags high
  risk/complexity, or on demand.
- **security-advisor** — manually triggered (`aiflow security-check` / `/security-check`). Scans the
  whole project and files Beads issues per finding, prioritised by severity, prefixed `[security-advisor]`.
- **requirements-check** — manually triggered (`aiflow requirements-check` / `/requirements-check`).
  Advisory only: grades issue description quality/completeness against the architecture and reports
  gaps. Never changes issues or code.
- **quality-check** — manually triggered (`aiflow quality-check` / `/quality-check`). Audits the
  codebase for refactoring needs (dead code, now-simplifiable code, duplication, complexity) and
  files Beads issues prefixed `[technical issue]` for the PO to triage. Read-only on code.
- **dependency-auditor** — `aiflow dependency-check`. Vulns/outdated/unused/license → `[dependency]` Beads.
- **test-gap-advisor** — `aiflow test-gap`. Untested critical paths → `[test gap]` Beads.
- **performance-advisor** — `aiflow perf-check`. Perf hotspots → `[performance]` Beads.
- **docs-sync** — `aiflow docs-check`. Doc/code drift → `[docs]` Beads.
- **accessibility-checker** — `aiflow a11y-check` / `/a11y-check`. Strict WCAG 2.2 AA audit of all
  UI surfaces → `[accessibility]` Beads; recommends an automated a11y tool for the E2E suite
  (axe-core/Pa11y/Lighthouse CI). Not part of the delivery loop.
- **modernization-advisor** — `aiflow modernize-check` / `/modernize-check`. Walks the whole
  brownfield codebase and proposes modernisation concepts (microservices, REST/cloud-native,
  git over svn, supported stacks, missing unit/BDD/E2E test frameworks) as a **report** in
  `.aiflow/modernization-report.md` for the architect to review — no code changes, no beads.
  Not part of the delivery loop.
- **onboarder** — `aiflow onboard`. Learns an existing codebase into memory + this file + arc42
  (writes docs/memory only). Plus slash-commands `/explain <path>` and `/standup`.

Customise them by editing the markdown in `.claude/agents/` (see README.md §8 "Customising").
`aiflow` CLI commands (`aiflow security-check`, `aiflow quality-check`, …) are agent-agnostic
entry points — they work from any shell regardless of which coding agent invoked them; only the
automatic in-session dispatch (subagents, slash-commands) is Claude Code-specific.

### Skills

**Skills** (`.claude/skills/<name>/SKILL.md`, Claude Code only) are a different mechanism from
slash-commands: Claude Code matches a skill's `description` against the current task and offers
to run it automatically, rather than waiting for an explicit `/command`.

**Skill or agent?** An **agent** is a *role* — who acts, with what authority, in what order, what
it hands to whom. A **skill** is *knowledge* — a checklist or a set of trade-offs that several
roles need (the implementer writing an endpoint and the reviewer checking it should read the same
list). Both may exist for one topic; the same-named agent then uses the skill instead of restating
it. Rules that must fire on **every** task — the §2 architecture rules and the §3a/§3b/§3c quality
gates — stay inline in this file: a skill is offered by pattern match, which is the wrong mechanism
for something that must never be missed, and Copilot/Codex get no auto-offer at all.

**Technology stacks** — layering, toolchain, test pyramid and the typical findings per platform:
- **stack-embedded** — C/C++ firmware: HAL/driver separation, no allocation after init, ISR
  discipline, watchdog, deterministic timing, host tests against a mocked HAL.
- **stack-mobile** — Flutter/Dart, Kotlin/Android, Swift/iOS: UI→presentation→domain←data,
  one state-management choice, process death, offline/sync, Keystore/Keychain, store constraints.
- **stack-web-frontend** — Angular/React/Vue: feature slices, server state vs client state,
  DTO→view-model mapping, XSS and token handling, Core Web Vitals budgets, i18n, a11y.
- **stack-backend** — Spring/Quarkus/Jakarta, .NET, Rust, Node, Go, Python: hexagonal layering with
  ports, transaction boundaries, 12-factor config, resilience, observability, FOSS-first choices.

**Integration & data architecture:**
- **api-design** — REST (§3b) versioning, status codes, pagination, idempotency, `problem+json`,
  OpenAPI, `.http` files; when SOAP is legitimate and how to migrate off it; GraphQL/gRPC trade-offs.
- **messaging-events** — when async beats synchronous; Kafka/RabbitMQ/NATS/SQS; at-least-once +
  idempotent consumers; transactional outbox; ordering; schema evolution; DLQs; sagas.
- **data-storage** — relational default (§3c), when NoSQL is justified, embedded DBs, Redis as a
  cache with real invalidation, Elasticsearch as a derived read layer, indexing and migrations.
- **cloud-native** — container images, 12-factor, K8s probes/limits/rollout/secrets, EC2 immutable
  images, modular monolith vs microservices, observability and cost.

**Cross-cutting:**
- **security** — OWASP Top 10 as a review raster + ASVS levels, IAM least privilege (roles,
  short-lived credentials, rotation), API authN/authZ per §3b, secrets, crypto, supply chain
  (pinning, scanning, never `curl | sh` unverified). The **security-advisor** uses this same raster.
- **seo-optimization** — SEO for any web-facing project (HTML, GitHub Pages, static sites,
  Next.js/Astro/Hugo/Jekyll/VuePress/VitePress/React/Vue/Svelte/Angular/…): meta tags, Open
  Graph/Twitter Cards, JSON-LD, robots.txt/sitemap.xml, canonical URLs, Core Web Vitals. Never
  applies non-trivial changes without confirming first; ends with an SEO report.
- **ponytail** — a YAGNI decision ladder (does it need to exist? already in the codebase? stdlib?
  native platform feature? installed dependency? a one-liner? only then write it) applied before
  any new code/dependency/abstraction, plus `/ponytail-review` to audit a diff for
  over-engineering. Toggled by `.aiflow/config.json → ponytail.enabled`/`.mode`
  (`full`/`lite`/`ultra`, default **off**); when off the skill is present but inert.
- **memory-setup** — the full memory/context-routing picture (§8 has the short version + toggle).

Copilot/Codex have no auto-offer mechanism for any of these — read the relevant `SKILL.md` directly
as a manual checklist (Codex reaches it via this file's pointer; Copilot: see the summary in
`.github/copilot-instructions.md`). Add more by dropping a `<name>/SKILL.md` into
`.claude/skills/`; the **description is the trigger**, so write it as "invoke when …" plus the
words that should match.

**Frontmatter must be valid YAML — nothing warns you if it isn't.** An agent whose frontmatter
fails to parse is **silently dropped** from the roster; a command or skill silently falls back to
its body text as the description, so it stops matching the trigger words you wrote. The usual
cause is an unquoted `description:` containing `": "` — YAML reads that as a nested mapping key.
Quote any description containing a colon (`description: "… two hats: architect …"`, single quotes
if the text itself contains double quotes). The `pre-commit` hook checks this whenever you stage
an agent/command/skill file, and CI enforces it on every push
(`.github/scripts/check-frontmatter.py`). The hook needs `python3`/`python` + PyYAML; without them
it says so and skips, so CI stays the backstop.

---

## 6. Ralph loop (autonomous iteration — agent-agnostic)

For larger tasks, run the **Ralph loop** — the agent iterates on the same task until it emits a
completion (or abort) signal.
- Headless / CI: `aiflow ralph "<prompt or bead id>" [ralph flags...]` (see
  `.aiflow/ralph-headless.sh`). Runs on **[open-ralph-wiggum](https://github.com/Th0rgal/open-ralph-wiggum)**
  and works with Claude Code, OpenAI Codex CLI, or GitHub Copilot CLI via `--agent
  claude-code|codex|copilot` — defaults to the first agent enabled in `.aiflow/config.json →
  agents.*` (claude > codex > copilot) if you don't pass `--agent` yourself. ralph-wiggum owns
  the outer loop (iterations, restarts, `.ralph/ralph-history.json`); this script just builds the
  task prompt. `aiflow ralph "<task>" --tasks` enables Tasks Mode for multi-part work; `ralph
  --status` (from another terminal) shows live progress.
- Interactive, Claude Code only: `/ralph-loop:ralph-loop` — a separate Claude Code plugin skill,
  not the headless CLI above.
- The loop stops at the AC, never invents scope. Known limitation: completion-promise
  auto-detection isn't always reliable with every agent — `--max-iterations` remains the real
  safety bound regardless.

**Who decides whether to use it:** by default the **implementer decides automatically** from its
**pre-analysis** (current architecture, expected change, effort, complexity): long-horizon /
many-file / iterate-and-verify work → Ralph; small crisp change → direct. The decision and its
reason are stated before implementation starts. You can also trigger it **manually**: say it in
the Claude Code session for a given issue (`/implement <bead> ralph` / `no-ralph`, or
`/ralph-loop`), or write it **into the bead itself** (e.g. "use the Ralph loop" in the
description) — the implementer honours a directive found in the bead like an explicit flag.
Copilot/Codex users: run `aiflow ralph "<task>" --agent codex` (or `copilot`) directly, or iterate
on the task yourself until AC are met, checking back against §4 at each step.

---

## 7. Git rules

- Every project is a git repo. Commit in small, reviewable steps.
- **Conventional Commits** + bead id: `feat(auth): add token refresh (bd-12)`. Enforced by the
  `commit-msg` git hook.
- The `pre-commit` hook enforces Google-style format + lint + unit tests. Do not bypass it.
- Never commit `.env` or secrets. Never `--no-verify`. Never force-push shared branches.
- Branch per task: `task/bd-<id>-short-slug` (unless the branching model defines a type — then use it).
- **Branching model:** follow `docs/branching.md` / `.aiflow/branching.json` — allowed branch
  sources, merge directions, PR rules, and release/versioning. Enforced by the `pre-push` hook
  (git-level, works no matter which agent or human pushes); releases via `aiflow release`. Do not
  bypass it.
- **gitflow model — picking a branch type:**
  - `feature/*`, `bugfix/*` — branch from `develop`, merge back to `develop`. Never target `main`.
  - `chore/*` — docs-only changes and CI/workflow-file-only changes (`.github/workflows/**`)
    count as `chore/*`, not `feature/*`, even if the diff is substantial. May target `develop`
    or `main`. Never triggers a release.
  - `hotfix/*` — for an urgent production fix only. Start with `aiflow hotfix <name>` (branches
    off `main`, bumps `VERSION` to `X.Y.(Z+1)-HOTFIX`). Merges to `main` (triggers a patch
    release) and is also merged into `develop` so the fix isn't lost there.
- **`main` never carries an in-progress version.** Only `develop` carries `-SNAPSHOT` and only
  `hotfix/*` carries `-HOTFIX`; `aiflow release` strips the suffix before it lands on `main`.
  A pre-push guard rejects any push to `main` with a `-SNAPSHOT`/`-HOTFIX` version.
- **Releasing is never automatic.** A release is only cut by merging `develop` → `main` (minor,
  strips `-SNAPSHOT`) or `hotfix/*` → `main` (patch, strips `-HOTFIX`); `chore/*` → `main`
  never releases. Always ask the user for explicit confirmation before merging into `main` or
  running `aiflow release --yes` — never decide on your own that "it's time to release." This
  applies to every agent equally — Claude Code, Copilot, and Codex CLI alike.
- End agent-authored commit messages with a trailer naming whichever agent made the commit, e.g.
  `Co-Authored-By: Claude <noreply@anthropic.com>`, `Co-Authored-By: GitHub Copilot
  <noreply@github.com>`, or `Co-Authored-By: OpenAI Codex <noreply@openai.com>`.

---

## 8. Memory (optional)

Persistent project memory is **toggled by `AIFLOW_MEMORY` at the top of this file** (set by
`aiflow init` / `aiflow change-settings`, config key `memory.enabled`; `off` by default until then).
When **on**: store durable, non-obvious facts (decisions, gotchas, env quirks — never things
already in code, git history, or Beads) in `.claude/memory/` with an index in `.claude/MEMORY.md`;
learning intensity is `.aiflow/config.json → memory.intensity` (`aggressive`/`normal`/`light`/`off`).
Refresh graphify + cocoindex-code together with `aiflow index` after significant changes.

Full detail — what to save, the context-routing stack (Beads vs memory files vs graphify vs
cocoindex-code vs context7, in priority order), shared team preferences (`.aiflow/team-prefs.json`),
and local-model (Ollama) routing — lives in the **memory-setup** skill
(`.claude/skills/memory-setup/SKILL.md`, Claude Code auto-offers it; Copilot/Codex: read it
directly, or the live routing table in `.claude/memory/memory-policy.md` once memory is on).

---

## 9. Communication & token budget

- **Output style:** caveman by default (terse; mode in `.aiflow/config.json`) **(Claude Code
  only)**. **Code, commits, PRs, and security warnings stay normal prose.** Toggle off with
  `AIFLOW_CAVEMAN=off`.
- **Keep context lean:** route via **graphify** (structure) + **cocoindex-code** (semantic RAG)
  before reading whole files, on any agent that has them wired as MCP servers. See §8 +
  `.claude/memory/memory-policy.md`.
- **Route by difficulty:** trivial/background steps may run on cheap/local models via
  `aiflow shell --router` **(Claude Code only)**; reserve top models for hard reasoning. Measure
  with `aiflow cost` (Claude Code usage only).
- **Model routing for audit-only subagents** — a separate, Claude-Code-native mechanism from the
  router above (no external tool, always available). Controlled by `.aiflow/config.json →
  modelRouting.enabled` (default **on**). When on, `aiflow apply` stamps `model: haiku` into the
  frontmatter of exactly 5 subagents that only do mechanical/background checks, not deep
  reasoning: **docs-sync**, **test-gap-advisor**, **dependency-auditor**, **performance-advisor**,
  **onboarder** — so they run on Haiku 4.5 instead of the session's main model. Every other
  subagent (`implementer`, `architect`, `security-advisor`, `reviewer`, `planner`,
  `quality-check`, `requirements-check`, `accessibility-checker`, `modernization-advisor`,
  `tester`) always keeps the session's default model — they need real reasoning. Toggle it with
  `aiflow change-settings` **(Claude Code only)**.
- **Ponytail** — `.aiflow/config.json → ponytail.enabled`/`.mode` (default off). When on, the
  **ponytail** skill (§5) applies a YAGNI decision ladder before new code/dependencies/
  abstractions; `/ponytail-review` audits a diff for over-engineering regardless of the toggle.
- CLI output is filtered by **rtk** before reaching context **(Claude Code only)** —
  errors/diffs are preserved.
- **Copilot:** apply the [token-optimization guide](https://github.com/olivomarco/github-copilot-token-optimization)'s
  techniques baked into `.github/copilot-instructions.md` — terse output, "landmines only"
  context files, stable model/tool-set per thread.
- **Codex:** when `codexsaver.enabled`, [CodexSaver](https://github.com/fendouai/CodexSaver)
  routes cheap/bounded work (docs, tests, explanation, search) to a cheaper worker automatically
  via MCP — Codex stays responsible for architecture, security, and final review.

---

## 10. Definition of Done (quick checklist)

- [ ] Acceptance criteria met and verified
- [ ] Pre-analysis done; functional decisions recorded (`/beads:decision` / `--design`)
- [ ] Tests written/updated and passing — unit + BDD E2E mandatory, coverage > 80 % lines,
      all non-static methods tested (§3a)
- [ ] Static analysis clean (tool or manual pass) — no code smells (§3a)
- [ ] Logging present with correct levels (§3a)
- [ ] REST changes ship current `.http` files (§3b)
- [ ] Database changes comply with §3c (new models per design rules; existing schemas only with
      commission + consumer check + rollback plan; improvement potential filed as beads)
- [ ] Google style + lint clean; §3a metric targets met (no new smells/duplicates, 0 warnings)
- [ ] Review gate passed (architect review + quality-gate checklist — `/review-ac` on Claude
      Code, done manually or by the user on Copilot/Codex), findings fixed, suggestions
      persisted as `[suggestion]` beads
- [ ] Bead updated/closed, commit references bead id
- [ ] Docs/architecture updated if structure changed (ADR for architecture changes)
