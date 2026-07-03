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
3. **Implement:** smallest change that satisfies AC. Follow §2 architecture + §3 style.
4. **Verify:** run tests + formatter + linter. AC must be demonstrably met.
5. **Review gate:** run `/review-ac` (self-review against AC + diff review). Fix findings.
6. **Commit:** reference the bead id in the message (see §7).
7. **Close** the bead with a note on how AC were verified: `bd close <id> --reason "…"`.
8. **Sync gate (mandatory when enabled):** the moment a bead is closed locally, if
   `.aiflow/config.json → sync.askOnClose` is `true`, run `aiflow close-sync <bead-id>`.
   It **asks** (never automatic) whether to `git push` and whether to Dolt-sync the issue DB.
   It **pulls before it pushes** (`bd dolt pull` → `bd dolt push`) so it never clobbers a
   teammate's changes. Do not push or sync silently, and do not skip the prompt.

A task is **DONE** only when: AC met • tests pass • style/lint clean • review gate passed • bead closed • sync gate honoured.

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
- **implementer** — write code for one ready bead, Google style, with tests.
- **reviewer** — review a diff for correctness + AC + style. Does not write features.
- **tester** — write/extend tests, find edge cases, raise coverage.
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
- [ ] Tests written/updated and passing
- [ ] Google style + lint clean
- [ ] `/review-ac` passed, findings fixed
- [ ] Bead updated/closed, commit references bead id
- [ ] Docs/architecture updated if structure changed
