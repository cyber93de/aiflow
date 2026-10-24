# Project Operating Rules (aiflow)

<!-- aiflow config flags - tooling reads these -->
<!-- AIFLOW_MEMORY: off -->

This file governs how AI coding agents work in this repo — **agent-agnostic**: Claude Code,
GitHub Copilot, OpenAI Codex CLI, or any tool that reads a repo-root instructions file. It is the
single source of truth shared by interactive sessions and headless/CI runs. Edit the sections
marked **[EDIT ME]** for your project.

Sections marked **(Claude Code only)** describe aiflow-generated Claude subagents, hooks and slash
commands. Other agents can use native delegation features, but aiflow does not yet render
equivalent role profiles for them. All agents follow the common workflow and rules here.
`CLAUDE.md` is a one-line pointer to this file; Codex reads `AGENTS.md` directly and Copilot is
pointed here by `.github/copilot-instructions.md`.

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

## 2. Architecture rules (MANDATORY)

These rules apply to **every** task, in every language — Java/Kotlin, Swift/Objective-C, Dart,
TypeScript, C#, Rust, Go, Python, C/C++ on embedded. The vocabulary differs per ecosystem
(package/module/crate/framework/target); the structure does not. §2a is binding everywhere; §2b is
where **this** project's concrete decisions go.

### 2a. Binding rules

**Layered architecture.** Every project has explicit layers and a single dependency direction —
inward, toward the domain:

```
presentation / API   (controllers, UI, CLI, ISR handlers)
        ↓
application / service (use cases, orchestration, transactions)
        ↓
domain               (entities, value objects, business rules — depends on nothing)
        ↑
infrastructure       (persistence, HTTP clients, brokers, drivers — implements domain ports)
```

- **No layer skips.** A controller never touches a repository or a driver directly.
- **The domain imports nothing outward.** No ORM annotations bleeding business rules, no HTTP types
  in entities, no vendor SDK in the domain. Infrastructure depends on the domain, never the reverse.
- **No cyclic dependencies** between modules/packages. A cycle is a defect, not a style opinion.
- Embedded equivalent: `application ↔ service ↔ HAL/driver`. Business logic never talks to a
  register directly; the HAL is the port.

**Interfaces at every seam.** Anything crossing a layer or module boundary is reached through an
interface (protocol/trait/abstract type), never a concrete class:
- The domain declares the **port** (`OrderRepository`, `PaymentGateway`); infrastructure provides
  the **adapter**. Wire them by dependency injection, never by `new`-ing inside the caller.
- A public API contract and its implementation live in separate types. Internal helpers stay
  internal (package-private / `internal` / not exported).
- This is what makes the code testable: every boundary is mockable by construction.

**DAO and DTO are mandatory, and they are not the same object.**
- **DAO / repository** — the *only* place that talks to a data store. No SQL, no query builder, no
  ORM session, no file/registry access anywhere else. One DAO per aggregate, not per table-join.
- **DTO** — what crosses a process boundary (REST/SOAP/queue payloads, UI view models). Mapped
  explicitly to/from domain objects.
- **Domain objects never leave the domain** — not serialised to a client, not persisted verbatim,
  not accepted as request bodies. An entity annotated for both JPA and JSON is a review finding:
  it couples the database schema to the wire format, so neither can change independently.

**Reusability before duplication.** Before writing something new: does it exist in this codebase,
in the standard library, in an already-installed dependency? Extract shared behaviour into a
common module rather than copying it. **Generics/type parameters** are the right tool when the same
logic differs only by type (`Repository<T, ID>`, `Result<T, E>`, a typed mapper) — use them to kill
duplication, not to build speculative abstraction layers (§3a: YAGNI).

**Complexity is the enemy.**
- Split a complex task into **small, single-purpose methods** with self-explanatory names. A method
  that needs a comment to explain *what* it does wants to be two methods.
- Guard clauses over nesting; no deep `if`-pyramids; no god classes/functions.
- Cognitive and cyclomatic complexity stay within the §3a metric targets. Every extra branch,
  flag parameter, and special case has to earn its place.

**Style.** Google Style per §3 — mandatory, no exceptions. Formatter and linter run before a task
is done.

### 2b. This project's architecture  [EDIT ME]

> Concrete decisions for **this** codebase. Replace the placeholders. If this block is still
> unfilled when the first real task arrives, the **architect** agent fills it (see below).

- Layer names + directories: `<dir> -> <dir> -> <dir>`
- Module/package boundaries and what may depend on what: `<...>`
- Public API lives in `<dir>`; internal helpers in `<dir>`.
- Persistence: `<db / ORM>`; DAOs in `<dir>`; migrations in `<dir>`.
- DTO ↔ domain mapping: `<mapper approach / dir>`
- Errors: never swallow; wrap with context. Project error type: `<...>`
- Full architecture document: `docs/architecture/` (arc42) + ADRs. Update it when structure changes.

### 2c. Rules must exist — and they win

- **A project without architecture rules gets them.** If §2b is still a placeholder and no ADR
  defines the structure, the **architect** agent (`/arch`) proposes a sensible set on first use —
  layering, module boundaries, DAO/DTO convention, interface policy, naming/package structure —
  writes it into §2b **and** as an ADR under `docs/architecture/`, and has it confirmed. On a
  brownfield codebase the **onboarder** derives the *actual* rules from the code first and flags
  where reality already contradicts them.
- **Once recorded, the rules are binding.** They change only through a new ADR that explicitly
  supersedes the old one — never silently, never as a side effect of a feature task.
- **A task that doesn't fit the architecture is not implemented as-is.** When a requirement would
  break a rule in §2a/§2b, the agent **stops before writing code** and asks — in PO-understandable
  language, with options and consequences (e.g. *"putting this query in the controller saves a day
  now, but no other feature can reuse it and the DB type leaks into the API"*). The user decides;
  the decision is recorded (`/beads:decision` **(Claude Code only)**, or `bd update <id> --design`).
  Improvising around a rule, or "just this once", is a review BLOCKER.
- The **reviewer** checks §2a/§2b explicitly (§5) — layer violations, missing interfaces at seams,
  domain objects on the wire, missing DAO/DTO separation, avoidable complexity, copy-paste instead
  of reuse — and each of those is a BLOCKER, not a suggestion.

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
10. **Continue the queue:** refresh it (`aiflow next`, or `bd ready --json`) and start the next
    task. Closing a bead ends a *task*, not the session — see §4b.

A task is **DONE** only when: AC met • quality gates §3a/§3b/§3c passed (tests + coverage, static
analysis, logging, `.http` files, database rules) • style/lint clean • review gate passed •
decisions recorded • bead closed • sync gate honoured • queue refreshed (§4b).

### 4b. Queue mode — work the queue, not one bead

Beads is an authoritative **work queue**, not a notepad. There is a difference between "execute
this task" and "work through the available tasks", and this project expects the second:

```
bd ready --json → select → claim → inspect → implement → validate → close → refresh → repeat
```

**Completing a task never ends the session by itself.** After closing a bead, re-run the queue
check immediately and continue with the next appropriate task. Do not ask the user what to work
on next while Beads already holds a ready one — announce which one you picked and why, then work
it.

**Selecting the next task** (`aiflow next` applies the first two mechanically and prints the
winner; `--after <closed-id>` feeds it the third):
1. higher priority (P0 first),
2. a task that unblocks others,
3. a task in the epic/workstream currently being implemented,
4. a natural continuation of the task just closed (e.g. `discovered-from` it),
5. otherwise the most appropriate ready task by description and dependencies.

Don't jump to unrelated work while a clear continuation of the current thread exists.

**Stop only for a real reason** — and say which one:
- the queue holds nothing actionable (`aiflow next` exits 3),
- everything left is blocked by unresolved dependencies (`bd blocked`),
- continuing needs a decision, clarification, credentials, permission or information only the
  user has,
- the user said stop.

"The task I was given is finished" is **not** one of them. Neither is a queue you did not look at.

This is not left to memory: with Claude Code, the `Stop` hook `.claude/hooks/queue-continue.*`
checks the queue when the agent tries to end its turn and hands back the next ready task. It
fires **at most once** per stop, so stating a legitimate reason above always ends the session.
Turn it off per project with `.aiflow/config.json → beads.queueMode = false`, or for one session
with `AIFLOW_QUEUE_MODE=off`. Copilot/Codex have no Stop-hook equivalent: run `aiflow next`
yourself after every close.

**Autonomy still has limits.** Queue mode does not authorise blanket execution of every open
bead: the §4 gates (AC, review, decisions) apply to each task unchanged, work outside a bead's
scope becomes a new bead rather than silent extra work, and the git/release rules in §7 —
especially "never merge to `main` or release without explicit confirmation" — are untouched by it.

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

Claude Code dispatches specialists from `.claude/agents/` and slash commands. Copilot and Codex do not
have equivalent automatic dispatch: perform the same steps manually in order. For every task,
plan, check architecture, implement, test risky changes, review, then close the bead. Keep handoff
state in the bead so it survives context resets.

- **orchestrator** routes work; it does not implement. **planner** decomposes work into beads,
  dependencies and acceptance criteria. **architect** records system decisions in ADR/arc42 and
  fills §2b. **onboarder** maps an existing project into memory, this file and arc42.
- **implementer** analyzes the approach before coding, follows architecture and quality gates, and
  hands work to the reviewer. **tester** covers negative, boundary and failure cases for risky work.
  **reviewer** checks architecture, design, risks and §3a gates; it returns changes or records PASS.
- Audit roles are read-only unless stated: **security-advisor**, **quality-check**,
  **dependency-auditor**, **test-gap-advisor**, **performance-advisor**, **docs-sync**,
  **accessibility-checker**, and **requirements-check** report findings as Beads issues. The
  **modernization-advisor** writes a report for the architect and does not change code or beads.

Reusable skills live in `.agents/skills/` using the open `SKILL.md` format, discovered by Codex
and Copilot; aiflow mirrors them to `.claude/skills/` for Claude Code. Their detailed bodies load
only when relevant, so they keep this always-loaded file short. Slash commands and dispatchable
subagents remain Claude-specific in `.claude/commands/` and `.claude/agents/`. Stack skills cover
embedded, mobile, web and backend; architecture skills cover API, messaging, storage and cloud;
cross-cutting skills cover security, SEO, YAGNI and memory setup. Skill descriptions state when
all compatible agents should use them.

Keep agent/command/skill frontmatter valid YAML. Quote descriptions containing `: `; malformed
frontmatter silently removes an item from Claude's roster. The pre-commit hook and
`.github/scripts/check-frontmatter.py` validate it when Python and PyYAML are available.

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
- **Start every task on a task branch.** Check `git status` and the current branch first. For
  gitflow, update `develop`, then create `feature/<slug>` (or `bugfix/<slug>`) from `develop`;
  for docs/CI-only work use `chore/<slug>`. Never implement a feature directly on `develop` or
  `main`. Do not switch branches with uncommitted user changes.
- Codex and other agents do not have Claude's queue/stop hooks: when queue mode is enabled, run
  `aiflow next` after closing a bead and apply this same branch/build/review flow to each task.
- **Finish every task through the configured flow:** run the project's build, tests and checks on
  the task branch; commit the change; open/merge a PR into `develop` (or follow the repo's stated
  local merge policy); then validate `develop`. Promote `develop` to `main` only when the user or
  repository explicitly requests it. Never skip a branch or target `main` with feature work.
- **Builds and versions:** feature/PR and develop builds are validation or snapshot builds. They
  must not tag, publish a release, rewrite `VERSION`, or promote themselves to `main`. Keep the
  project's snapshot convention on `develop` if configured; do not strip `-SNAPSHOT` or bump a
  release version as part of ordinary task work. There is no `aiflow release` step in the agent
  workflow. A release policy, if the project has one, is handled separately by its maintainers.
- **Branching model:** follow `docs/branching.md` / `.aiflow/branching.json` for allowed sources,
  merge directions and PR rules. The local pre-push hook enforces some rules; it does not replace
  checking the intended source and target. Never bypass governance.
- **gitflow model — picking a branch type:**
  - `feature/*`, `bugfix/*` — branch from `develop`, merge back to `develop`. Never target `main`.
  - `chore/*` — docs-only changes and CI/workflow-file-only changes (`.github/workflows/**`)
    count as `chore/*`, not `feature/*`, even if the diff is substantial. May target `develop`
    or `main`. Never triggers a release.
  - `hotfix/*` — only for urgent production fixes; branch from `main`, then merge the fix to
    `main` and back to `develop` according to `docs/branching.md`. Do not bump versions or publish.
- Never merge to `main` without an explicit user or repository instruction. This applies equally
  to Claude Code, Copilot and Codex CLI.
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
(`.agents/skills/memory-setup/SKILL.md`; mirrored under `.claude/skills/`). Load it when memory or
context routing is relevant, or consult `.claude/memory/memory-policy.md` once memory is on.

---

## 9. Communication & token budget

- Be concise, except for code, commits, PRs and security warnings, which require clear full prose.
  Claude Code's caveman output mode is optional (`AIFLOW_CAVEMAN=off`).
- Use `rtk <command>` for noisy shell output when installed; keep errors and diffs visible. Use
  graphify/cocoindex only when enabled and useful for this codebase; avoid loading whole files
  before targeted search. See §8 and `.claude/memory/memory-policy.md`.
- Claude Code users should compact after init/onboarding, each closed bead and before long Ralph or
  refactor work. Persist decisions in Beads, memory or ADRs first. Codex/Copilot users should start
  a fresh thread at those points and reread this file and the active bead.
- Match model effort to the work: strongest reasoning for architecture, planning, review and
  security; implementation models for bounded coding and tests; lighter models for scans, docs
  drift and mapping. Escalate when scope grows. Claude routing is configured in
  `.aiflow/config.json`; Codex/Copilot users choose an equivalent model manually.
- The optional ponytail skill checks new code/dependencies for YAGNI. All agents should keep
  output focused and use targeted code search; RTK is an optional shell wrapper, not a Claude hook.

---
## 10. Definition of Done (quick checklist)

- [ ] Acceptance criteria met and verified
- [ ] §2 architecture rules honoured — layering, interfaces at seams, DAO/DTO separation, reuse
      over duplication — **or** the deviation was asked about *before* coding and is recorded
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
- [ ] Queue refreshed (`aiflow next`): next task started, or the stop reason named (§4b)
