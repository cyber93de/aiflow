# Project Operating Rules (aiflow)

<!-- aiflow config flags - tooling reads these -->
<!-- AIFLOW_MEMORY: off -->

This file governs how AI agents work in this repo. It is the single source of truth
shared by interactive sessions and headless/CI runs. Edit the sections marked
**[EDIT ME]** for your project.

---

## 1. Project overview  [EDIT ME]

> One paragraph: what this project is, who uses it, the tech stack.
> Replace this block.

- **Stack:** <language / framework>
- **Entry point:** <main file / app start>
- **Run locally:** <command>
- **Test:** <command>

> **Project aim (fill it in — the cheapest quality lever).** Every agent reads the aim before
> planning or coding; without it Claude works generically instead of tuned to *this* project.
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
notes the missing tool. The `format` hook auto-formats edited files when the tool exists.

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

Work is tracked in **Beads** (`bd`), a Dolt-backed issue store shared by the whole team.
Multi-step or multi-session work MUST be a bead. Beads issues live in a Dolt DB and sync via
`refs/dolt/data` on the git remote — so several members share one issue graph.

0. **Sync first (start of every session):** `aiflow sync` (= `git pull --rebase` + `bd dolt pull`)
   so you see teammates' latest issues/status before picking work. Never work off a stale DB.
1. **Pick + claim work atomically:** `bd ready --claim --json` claims the first ready, unassigned
   bead (sets assignee = you, status = in_progress) in one step. To claim a specific one:
   `bd update <id> --claim`. **Only work a bead you have claimed.** Check `bd ready --unassigned`
   to see what's free; never start a bead already assigned to someone else.
2. **Acceptance criteria:** every task has explicit, checkable AC. If missing, write them first and confirm before coding.
   Functional questions are phrased so a **PO understands the hurdle** (plain language, options
   with consequences); the user picks, and the decision is **recorded** (`/beads:decision` or
   `bd update <id> --design`).
3. **Strategy first:** the implementer builds a short pre-analysis (current architecture, how it
   changes, effort, complexity) and gathers missing information **before** writing code.
4. **Implement:** smallest change that satisfies AC. Follow §2 architecture + §3 style + §3a/§3b
   quality gates.
5. **Verify:** run tests + formatter + linter + static analysis (§3a). AC must be demonstrably met.
6. **Review gate:** run `/review-ac` — one agent, two hats: **architect review** (architecture,
   design, risks) plus the **quality-gate checklist** (§3a metrics, tests, docs). Fix every
   BLOCKER/SHOULD; out-of-scope improvement ideas are persisted as `[suggestion]` beads for the
   next loop. When the pre-analysis flagged high risk/complexity, a separate **tester** pass runs
   before the gate.
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
- **Decisions** that affect others → `/beads:decision` (recorded with rationale), not just a commit.

---

## 5. Agents

Specialised subagents live in `.claude/agents/`. Use the right one:
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
- **onboarder** — `aiflow onboard`. Learns an existing codebase into memory + CLAUDE.md + arc42
  (writes docs/memory only). Plus slash skills `/explain <path>` and `/standup`.

Customise them by editing the markdown in `.claude/agents/` (see README.md §8 "Customising").

---

## 6. Ralph loop (autonomous iteration)

For larger tasks, run the **Ralph loop** — the agent iterates until the task is
`COMPLETE` or `BLOCKED`.
- Interactive: `/ralph-loop:ralph-loop` inside Claude Code.
- Headless / CI: `aiflow ralph "<prompt or bead id>"` (see `.aiflow/ralph-headless.sh`).
- The loop stops at the AC, never invents scope, and writes `result.json`.

**Who decides whether to use it:** by default the **implementer decides automatically** from its
**pre-analysis** (current architecture, expected change, effort, complexity): long-horizon /
many-file / iterate-and-verify work → Ralph; small crisp change → direct. The decision and its
reason are stated before implementation starts. You can also trigger it **manually**: say it in
the Claude Code session for a given issue (`/implement <bead> ralph` / `no-ralph`, or
`/ralph-loop`), or write it **into the bead itself** (e.g. "use the Ralph loop" in the
description) — the implementer honours a directive found in the bead like an explicit flag.

---

## 7. Git rules

- Every project is a git repo. Commit in small, reviewable steps.
- **Conventional Commits** + bead id: `feat(auth): add token refresh (bd-12)`. Enforced by the
  `commit-msg` git hook.
- The `pre-commit` hook enforces Google-style format + lint + unit tests. Do not bypass it.
- Never commit `.env` or secrets. Never `--no-verify`. Never force-push shared branches.
- Branch per task: `task/bd-<id>-short-slug` (unless the branching model defines a type — then use it).
- **Branching model:** follow `docs/branching.md` / `.aiflow/branching.json` — allowed branch
  sources, merge directions, PR rules, and release/versioning. Enforced by the `pre-push` hook;
  releases via `aiflow release`. Do not bypass it.
- End agent-authored commit messages with a trailer:
  `Co-Authored-By: Claude <noreply@anthropic.com>`

---

## 8. Claude memory (optional)

Persistent project memory is **toggled by `AIFLOW_MEMORY` at the top of this file** (set by
`aiflow init` / `aiflow change-settings`).
- `off`: no memory dir is used; rely on Beads + this file.
- `on`: store durable facts in `.claude/memory/` with an index in `.claude/MEMORY.md`.
  `aiflow` seeds two files: `project-aim.md` (goal + target architecture) and
  `dev-environment.md` (OS, IDE, VCS host — so the agent picks correct commands).

When **on**: save only non-obvious, durable facts (decisions, gotchas, env quirks) —
never things already in code, git history, or Beads.

**Learning intensity** is set in `.aiflow/config.json → memory.intensity` and written to
`.claude/memory/memory-policy.md` (read it): `aggressive` (default — learn after every
non-trivial task + refresh the graph), `normal`, `light`, or `off`.

**Context stack (route the question, don't scan files):** `.claude/memory/memory-policy.md`
holds the full routing table. In short:
- **Beads** (`bd`) — current task, dependencies, decisions, session state.
- **memory files** (`.claude/memory/`) — durable prose facts / gotchas / env quirks.
- **graphify** (MCP) — *structural* graph: where a symbol is defined, who calls it, dependency
  direction. Exact, no re-scan.
- **cocoindex-code** (`ccc` / MCP) — *semantic* RAG: "find code about concept X", AST-aware,
  local embeddings (no key), ~70% fewer tokens than reading files.
- **context7** (MCP) — external library/framework docs.

Rule: hit graphify (structure) + cocoindex-code (semantics) to locate the few relevant chunks,
then open only those files. Refresh **both** indexes after significant changes with a single
command: `aiflow index` (runs `graphify build` + `ccc index`, incremental).

**Shared team preferences:** if `.aiflow/team-prefs.json` exists it holds versioned,
team/user-wide preferences (code style, language, conventions) that override per-language
defaults in §3. It is committed so the whole team inherits it; personal tweaks stay local.

**Local models (Ollama):** when `.aiflow/config.json → ollama` is enabled, its models are
wired into `.aiflow/router-config.json`; run easy/background steps on them via
`aiflow shell --router` (no API key, private, cheap). Manage models with `aiflow ollama`.

---

## 9. Communication & token budget

- **Output style:** caveman by default (terse; mode in `.aiflow/config.json`). **Code, commits,
  PRs, and security warnings stay normal prose.** Toggle off with `AIFLOW_CAVEMAN=off`.
- **Keep context lean:** route via **graphify** (structure) + **cocoindex-code** (semantic RAG)
  before reading whole files. See §8 + `.claude/memory/memory-policy.md`.
- **Route by difficulty:** trivial/background steps may run on cheap/local models via
  `aiflow shell --router`; reserve top models for hard reasoning. Measure with `aiflow cost`.
- CLI output is filtered by **rtk** before reaching context — errors/diffs are preserved.

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
- [ ] `/review-ac` passed (architect review + quality-gate checklist), findings fixed,
      suggestions persisted as `[suggestion]` beads
- [ ] Bead updated/closed, commit references bead id
- [ ] Docs/architecture updated if structure changed (ADR for architecture changes)
