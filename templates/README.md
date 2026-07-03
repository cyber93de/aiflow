# aiflow

**aiflow turns any repository into a governed, AI-driven software-delivery pipeline with one
command.** It wires [Claude Code](https://docs.claude.com/en/docs/claude-code) together with
durable task tracking, autonomous work loops, a code knowledge graph, specialist review/audit
agents, cost controls, enforced code quality, and a configurable git branching model — so an AI
agent can take an issue, plan it, write the code in a consistent style, test it, review it against
acceptance criteria, audit it for security and quality, and ship it through a real release process.

It is **vendor-neutral** (your own Anthropic API key *or* Claude Code OAuth token — no third-party
hub), runs on **Windows, Linux and macOS**, and is **project-scoped**: secrets and settings live in
the project, never globally.

> 🇩🇪 Diese Anleitung gibt es auch auf **[Deutsch → README.de.md](README.de.md)**.

---

## Contents

1. [What is aiflow & why](#1-what-is-aiflow--why)
2. [New to AI coding? Start here](#2-new-to-ai-coding-start-here)
3. [Install](#3-install)
4. [Set up a project](#4-set-up-a-project)
5. [Command reference](#5-command-reference)
6. [Agents](#6-agents)
7. [Slash-command skills](#7-slash-command-skills)
8. [The bundled toolchain & why each piece is here](#8-the-bundled-toolchain--why-each-piece-is-here)
9. [The delivery workflow](#9-the-delivery-workflow)
10. [Autonomous work: the Ralph loop](#10-autonomous-work-the-ralph-loop)
11. [Audit agents (security, quality, deps, tests, perf, docs)](#11-audit-agents)
12. [Quality & enforcement](#12-quality--enforcement)
13. [Token & cost optimisation](#13-token--cost-optimisation)
14. [Model routing](#14-model-routing)
15. [Git branching governance](#15-git-branching-governance)
16. [Memory](#16-memory)
17. [Configuration model](#17-configuration-model)
18. [Tools are global, configuration is per-project](#18-tools-are-global-configuration-is-per-project)
19. [CI/CD](#19-cicd)
20. [Headless & containers](#20-headless--containers)
21. [Customising](#21-customising)
22. [Project layout](#22-project-layout)
23. [Upgrading](#23-upgrading)
24. [Troubleshooting](#24-troubleshooting)
25. [Contributing](#25-contributing)
26. [Feedback, ideas & bug reports](#26-feedback-ideas--bug-reports)
27. [License](#27-license)

---

## 1. What is aiflow & why

AI coding agents are powerful but forgetful and unstructured: they start each session from zero,
drift from your architecture, write in inconsistent styles, skip tests, and have no record of what
was decided. aiflow fixes that by installing a **complete, opinionated operating environment** for
Claude Code into your repo:

- **Durable tasks** in Beads (git/Dolt-backed) so work survives across sessions and context resets.
- **Specialist agents** for planning, implementing, reviewing, testing, security, quality, and more.
- **Autonomous loops** that finish whole tasks unattended and report status.
- **A code knowledge graph** so the agent answers from structure instead of re-reading files.
- **Enforced quality**: Google style, auto-format, lint, tests, and Conventional Commits via git hooks.
- **Cost controls**: terse output, CLI-output filtering, cheap-model routing, and usage measurement.
- **Git governance**: a configurable branching model with PR rules, releases, and versioning.
- **A real review trail**: acceptance-criteria checks, requirement audits, and prioritised findings.

Everything is files in your repo (`CLAUDE.md`, `.claude/`, `.aiflow/`, `.githooks/`), so the
behaviour is transparent and editable — no hidden config, no lock-in.

---

## 2. New to AI coding? Start here

A plain-language primer. Skip if you already know Claude Code.

- **AI / LLM:** software that predicts text and can write/edit code from instructions + context. It
  has **no memory between sessions** — you must supply the right context each time. Solving that
  "context problem" is most of what aiflow does.
- **Claude Code:** Anthropic's terminal/IDE agent that — with permission — reads files, runs
  commands, edits code, and uses tools. aiflow configures it for your project.
- **API key vs OAuth token:** Claude Code authenticates with an **Anthropic API key** (pay-per-use)
  or a **Claude Code OAuth token** (`claude setup-token`, uses your subscription). aiflow supports
  both; you keep them in `.env` (never committed).
- **Agent:** a focused AI worker with a role + system prompt (e.g. *reviewer*, *implementer*).
- **Skill / slash-command:** a reusable instruction you trigger with `/name` (e.g. `/implement`).
- **Hook:** a script the harness runs automatically on events (after an edit, at session start,
  before a push). aiflow uses hooks for auto-format, enforcement, and output style.
- **Memory:** durable facts stored in files (`.claude/memory/`) plus the Beads task store and the
  graphify code graph, so each session starts informed.
- **MCP (Model Context Protocol):** a standard for plugging external tools into the agent (GitHub
  issues, the filesystem, the code graph). aiflow generates the MCP config for you.
- **Claude's project settings:** plain files steer behaviour — `CLAUDE.md` (rules every agent
  follows), `.claude/settings.json` (permissions + hooks), and `docs/architecture/` (arc42 + ADRs).

The goal: a beginner runs `aiflow init`, answers a few questions, and gets a setup that nudges the
AI toward **high-quality, low-cost, reviewable** output by default.

---

## 3. Install

**Prerequisites you provide:** [Node.js](https://nodejs.org) (for `npm`) and **Git Bash** (on
Windows — the core logic is Bash; the PowerShell wrapper delegates to it). aiflow installs the rest.

**Windows (PowerShell):**
```powershell
cd C:\dev\aiflow
powershell -ExecutionPolicy Bypass -File .\install.ps1   # adds aiflow to PATH
# open a new terminal, then:
aiflow doctor
```
**Linux / macOS / Git-Bash:**
```bash
cd /path/to/aiflow
bash install.sh
aiflow doctor
```

`aiflow doctor` reports what's present/missing. To install the toolchain itself:
```bash
aiflow install-deps --all
```
This installs (user-global) claude, **beads + dolt** (its database backend), jq, the matching VCS
CLI (`gh`/`glab`), and — if enabled in a project — task-master, claude-code-router, rtk,
graphify + uv. On Windows it prefers **winget** (then scoop); macOS Homebrew; Linux the system
package manager / official scripts. **A container engine is never auto-installed** (install
**Podman or Docker** yourself if you want the GitHub MCP or headless container runs). You can also
just run `aiflow init` in a project — it offers to install exactly the tools you enable.

---

## 4. Set up a project

```bash
cd /path/to/your/project
aiflow init            # interactive — asks a few questions, then wires everything up
aiflow init . --yes    # accept all defaults (non-interactive / CI)
```

`aiflow init` asks, and writes your answers to **`.aiflow/config.json`**:

1. **caveman** terse output? + mode (`full` recommended / `lite` / `ultra`).
2. **rtk** CLI-output filtering?
3. **claude-code-router** for cheap/local models on easy tasks?
4. **graphify** code knowledge graph (memory optimisation)?
5. **claude-task-master** task decomposition?
6. **filesystem MCP**?
7. **VCS host** — github / gitlab / bitbucket.
8. **Project aim** — what it should achieve (→ memory).
9. **Target architecture** — hexagonal / layered / MVC / … (→ memory).
10. **OS & IDE** (VS Code / IntelliJ / other) — so the AI picks the right commands.
11. **Browse claude-code-templates** for extra configs?
12. **Git branching model** — simple / gitflow / none, then strict rules, PR-only, auto-release,
    version strategy, release tags, chore branches (see §15).
13. Offer to **install missing tools**.

It also creates `.env` (from `.env.example`), runs `git init` and `bd init`, and renders everything
from the config. Change any answer later with **`aiflow change-settings`** — it re-prompts and
re-applies.

### New vs existing (brownfield) projects

`aiflow init` detects which case it is (existing = the folder already has a git history or source
files) and adapts:

| | **New project** (empty folder) | **Existing project** (has code / git history) |
|---|---|---|
| Your files | none to protect | **preserved** — templates are copied *no-clobber*; an existing `CLAUDE.md`, `.gitignore`, etc. is never overwritten (use `--force` to replace) |
| `git init` | runs | skipped (keeps your history) |
| `bd init` | runs | runs only if `.beads/` is absent; git hooks are merged with Beads' hooks |
| Branching model | permanent branches created from the first commit | `main`/`develop` created from current `HEAD` only if missing; your current branch is untouched |
| Architecture knowledge | you fill `CLAUDE.md §1/§2` + arc42 + `project-aim` | aiflow **offers to run `aiflow onboard`**, which studies the code and writes `.claude/memory/codebase-map.md` + `conventions.md`, fills the `[EDIT ME]` blocks in `CLAUDE.md`, and populates `docs/architecture/arc42.md` |
| Recommended follow-up | start building | run baseline audits (`aiflow security-check`, `quality-check`, `dependency-check`, `test-gap`, `docs-check`) to seed the backlog |

**Recommended flow for an existing project:**
```bash
cd /path/to/existing/repo
aiflow init               # preserves your files; say "yes" to onboarding when asked
# (or run it explicitly later:)  aiflow onboard
# review & reconcile what was learned:
#   .claude/memory/codebase-map.md, CLAUDE.md §1/§2, docs/architecture/arc42.md
aiflow index              # build the graphify graph over the existing code
aiflow security-check     # optional: seed the backlog with prioritised findings
aiflow shell
```
If init had nothing to overwrite-protect but you re-run it on a configured project, it stays
idempotent; pass `--force` only when you deliberately want to reset aiflow's own templates to
defaults (your application code is never touched).

Then:
```bash
# fill .env: GITHUB_TOKEN (or GITLAB_/BITBUCKET_) + ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN
aiflow shell            # loads .env and starts Claude Code
```

---

## 5. Command reference

| Command | Purpose |
|---------|---------|
| `aiflow init [--yes] [--force] [--no-git] [--no-beads]` | Bootstrap a project (interactive Q&A). |
| `aiflow change-settings` | Re-adjust this project's config, then re-apply (alias `settings`). |
| `aiflow install-deps [--all]` | Install missing tools (enabled in config; `--all` = full set). |
| `aiflow doctor` | Check prerequisites + which tokens are set. |
| `aiflow shell [--router]` | Load `.env`, start Claude Code (`--router` = via claude-code-router). |
| `aiflow ralph "<task>"` | Headless Ralph loop until COMPLETE/BLOCKED. |
| `aiflow security-check` | Whole-project security audit → `[security-advisor]` Beads. |
| `aiflow quality-check` | Refactoring/quality audit → `[technical issue]` Beads. |
| `aiflow requirements-check` | Advisory issue-quality audit vs architecture (report only). |
| `aiflow dependency-check` | Dependency audit (vulns/outdated/unused/license) → `[dependency]` Beads. |
| `aiflow test-gap` | Untested critical paths → `[test gap]` Beads. |
| `aiflow perf-check` | Performance audit → `[performance]` Beads. |
| `aiflow docs-check` | Doc/code drift → `[docs]` Beads. |
| `aiflow onboard` | Learn an existing codebase into memory + CLAUDE.md + arc42. |
| `aiflow release [--push]` | Cut a release per the branching model (version bump + tag). |
| `aiflow protect` | Apply server-side branch protection (GitHub). |
| `aiflow index` | Build/refresh the graphify code knowledge graph. |
| `aiflow cost [...]` | Token/cost baseline via ccusage. |
| `aiflow upgrade` | Update the bundled toolchain (beads, rtk, graphify, …) to latest. |
| `aiflow version` | Print version. |

Inside Claude Code you also get the slash-command skills listed in §7.

---

## 6. Agents

Specialist subagents live in `.claude/agents/`. Claude picks the right one by its `description`, or
you invoke it explicitly. Three groups:

**Delivery agents** (do the work):
- **architect** — system design; produces ADRs + arc42 updates + a task breakdown. No feature code.
- **planner** — turns a goal/epic/issue into small Beads tasks with testable acceptance criteria
  and real dependencies.
- **implementer** — builds exactly one ready bead (code + tests) in Google style; stops as BLOCKED
  if criteria are unclear.
- **reviewer** — the quality gate; reviews a diff against acceptance criteria, correctness, tests,
  and style; verdict PASS / CHANGES REQUIRED.
- **tester** — writes meaningful tests, hunts edge cases; reports bugs instead of weakening tests.

**Audit agents** (manual via aiflow, read-only on code, file prioritised Beads — see §11):
- **security-advisor** → `[security-advisor]`
- **quality-check** → `[technical issue]`
- **dependency-auditor** → `[dependency]`
- **test-gap-advisor** → `[test gap]`
- **performance-advisor** → `[performance]`
- **docs-sync** → `[docs]`
- **requirements-check** — advisory; grades issue quality vs architecture, **report only** (no Beads, no changes).

**Brownfield agent:**
- **onboarder** — studies an existing codebase and persists what it learns into `.claude/memory/`,
  `CLAUDE.md`, and arc42, so future sessions start informed. Writes docs/memory only.

Customise any agent by editing its markdown (prompt, allowed `tools:`, `model:`). See §21.

---

## 7. Slash-command skills

Triggerable inside Claude Code (`.claude/commands/`):

- **Delivery:** `/intake-issue <n>` (pull a GitHub/GitLab/Bitbucket issue → Beads),
  `/decompose <goal|prd>` (claude-task-master → Beads), `/plan-epic`, `/implement [bead]`,
  `/review-ac`, `/arch "<question>"`.
- **Audits:** `/security-check`, `/quality-check`, `/requirements-check`, `/dependency-check`,
  `/test-gap`, `/perf-check`, `/docs-check`.
- **Brownfield / orientation:** `/onboard`, `/explain <path>`, `/standup`.

(Beads and the Ralph loop are also available as their own plugin skills, e.g. `/beads:ready`.)

---

## 8. The bundled toolchain & why each piece is here

Each tool earns its place by raising **quality**, cutting **token cost**, or making delivery
**autonomous and auditable**.

- **Claude Code** — the agent runtime everything builds on.
  https://docs.claude.com/en/docs/claude-code · *plans, edits, runs tools — not just chat.*
- **Beads (`bd`)** — git/Dolt-backed issue tracker. https://github.com/steveyegge/beads · *durable
  task memory with dependencies; work survives session/context resets.*
- **Dolt** — versioned SQL database backing Beads. https://github.com/dolthub/dolt · *branch/merge/
  diff history for tasks — a real audit trail.*
- **Ralph loop** — autonomous iterate-until-done loop. *finishes a task unattended, stops at
  COMPLETE/BLOCKED, writes `result.json`.*
- **claude-task-master** — goal/PRD → task tree with dependencies.
  https://github.com/eyaltoledano/claude-task-master · *good decomposition = better, reviewable
  output; uses the `claude-code` provider, no extra key.*
- **graphify** — queryable knowledge graph of your code (imports, call graphs) over MCP.
  https://github.com/safishamsi/graphify · *query structure instead of re-reading dozens of files —
  far fewer tokens, fewer DRY violations.*
- **ccusage** — token/cost analytics. https://github.com/ryoppippi/ccusage · *measure before you
  optimise (`aiflow cost`).*
- **claude-code-router** — route requests to different models (Anthropic, DeepSeek, local Ollama…).
  https://github.com/musistudio/claude-code-router · *cheap/local for easy work, top models for hard
  reasoning — typically 50–99% cheaper.*
- **rtk** — filters/compresses verbose command output before it enters context.
  https://www.rtk-ai.app/ · *keeps errors/diffs, trims noise — often 60–90% fewer tokens. aiflow
  enables it per project.*
- **caveman** — terse-output mode. *~75% fewer output tokens; code/commits/security stay normal.*
- **Podman / Docker** — containerise the headless loop (`docker/run.sh`, engine auto-detected). ·
  *reproducible "runs the same everywhere".*
- **claude-code-templates** — community marketplace of agents/commands/MCPs/hooks.
  https://github.com/davila7/claude-code-templates · *drop in extra battle-tested configs.*
- **Filesystem MCP** — safe structured file access.
  https://github.com/modelcontextprotocol/servers
- **GitHub / GitLab / Bitbucket** — issue intake into Beads from any of the three.

---

## 9. The delivery workflow

```
Issue (GitHub / GitLab / Bitbucket)
  └─ /intake-issue ─▶ Beads tasks (with acceptance criteria)
       └─ /decompose (claude-task-master) ─▶ subtasks + dependencies
            └─ /beads:ready ─▶ pick a task
                 └─ /implement ─▶ code + tests, Google style      (implementer)
                      └─ /review-ac ─▶ gate vs acceptance criteria (reviewer)
                           └─ commit (Conventional Commits + bead id) ─▶ PR ─▶ release
```

A task is **DONE** only when: acceptance criteria met • tests pass • style/lint clean • review gate
passed • bead closed • commit references the bead id (CLAUDE.md §10).

---

## 10. Autonomous work: the Ralph loop

For larger tasks, hand off to the **Ralph loop** — the agent iterates until `COMPLETE` or `BLOCKED`.

- **Interactive:** `/ralph-loop` inside Claude Code.
- **Headless:** `aiflow ralph "implement bd-12"` — each iteration writes `result.json`
  (`{status, summary, next, blocker}`); tuned via `.env` (`RALPH_MAX_ITERATIONS`,
  `RALPH_TIMEOUT_SECONDS`, `RALPH_PERMISSION_MODE`). Works with a token in env **or** your stored
  Claude login (OAuth).
- **In CI:** the same loop runs via `.github/workflows/agent.yml` on manual dispatch, the `agent`
  issue label, or nightly (§19).
- **Containerised:** `docker/run.sh` runs the loop in a container via **Podman or Docker**
  (auto-detected; override with `AIFLOW_CONTAINER=podman|docker`).

---

## 11. Audit agents

Run on demand; each scans the whole project read-only and files prioritised Beads issues with a
recognisable prefix so a human/PO can triage. They never modify code.

| Command | Finds | Beads prefix |
|---------|-------|--------------|
| `aiflow security-check` | injection, secrets, authz, crypto, SSRF/XSS, supply chain | `[security-advisor]` |
| `aiflow quality-check` | dead/now-simplifiable code, duplication, complexity | `[technical issue]` |
| `aiflow dependency-check` | vulnerable/outdated/unused deps, license conflicts | `[dependency]` |
| `aiflow test-gap` | untested critical / high-fan-in paths | `[test gap]` |
| `aiflow perf-check` | N+1, sync I/O, O(n²), missing pagination/indexes | `[performance]` |
| `aiflow docs-check` | README/CLAUDE/arc42/API drift | `[docs]` |

Severity maps to Beads priority (Critical→P0 … Low→P3); findings are de-duplicated against existing
open issues of the same prefix.

Separately, **`aiflow requirements-check`** is advisory-only: it grades each issue's description
quality/completeness against the architecture, flags undescribed cases, and writes
`.aiflow/requirements-report.md` — it changes nothing and does not decide what gets built.

---

## 12. Quality & enforcement

On by default:

- **Code style:** Google Style for **every** language (CLAUDE.md §3), with per-language formatters.
- **Auto-format:** a PostToolUse hook formats files right after the AI edits them.
- **pre-commit hook:** blocks the commit unless format + lint + unit tests pass.
- **commit-msg hook:** rejects non-**Conventional-Commit** messages.
- **pre-push hook:** enforces the branching model (§15).
- **Review gate:** `/review-ac` + the *reviewer* agent check every change against acceptance criteria.

Hooks live in `.githooks/` (wired via `core.hooksPath`, merged with Beads' own hooks). Emergency
bypasses exist (`AIFLOW_SKIP_VERIFY=1`, `AIFLOW_SKIP_COMMIT_LINT=1`, `AIFLOW_ALLOW_DIRECT_PUSH=1`)
but are discouraged.

---

## 13. Token & cost optimisation

The measured stack — **measure → route → filter → be terse → keep context lean**:

1. **Measure** — `aiflow cost` (ccusage) gives your baseline before you optimise.
2. **Route** — `aiflow shell --router` sends easy/background work to cheap or local models, top
   models to hard reasoning (§14).
3. **Filter** — rtk compresses noisy command output before it reaches context (errors/diffs kept).
4. **Be terse** — caveman trims filler from the AI's prose (code/commits/security stay normal),
   default mode `full`, configurable.
5. **Lean context** — graphify lets the agent query the code graph instead of re-reading files.

---

## 14. Model routing

`aiflow shell --router` runs Claude Code through **claude-code-router**. It classifies each request
and maps it to a model you choose:

| Route | When | Suggested model |
|-------|------|-----------------|
| `default` | normal interactive coding | strong (e.g. Sonnet) |
| `think` | hard reasoning / planning | top (e.g. Opus) |
| `background` | cheap/automatic steps, CI/CD chores | local Ollama / DeepSeek |
| `longContext` | very large inputs | long-context model |
| `webSearch` | web-search requests | web-capable model |

Config lives in your home dir (`~/.claude-code-router/config.json`, never committed) — copy the
template `.aiflow/router-config.example.json`. It has `Providers` (with API keys) and `Router`
(route → `provider,model`). Keys you might need: Anthropic, DeepSeek, OpenRouter, Gemini; Ollama is
local and needs none. A custom JS router (`CUSTOM_ROUTER_PATH`) enables conditional rules like
"CI → Ollama" or "auth/security code → top model" — so **coding uses higher models and CI/CD uses
lower ones** automatically.

---

## 15. Git branching governance

`aiflow init` / `aiflow change-settings` configure a per-project branching model. aiflow derives a
governance model in **`.aiflow/branching.json`** + a readable **`docs/branching.md`**, creates the
permanent branches, seeds `VERSION`, and installs enforcement.

- **Model** — `simple` (main + develop; temp branches any name) · `gitflow` (`feature/*` from
  develop, `hotfix/*` from main) · `none`.
- **Strict rules** — enforce branch sources/targets and naming (gitflow).
- **PR-only** — no direct push to main/develop; merge only via validated Pull Request.
- **Auto-release** — a merge of develop → main cuts a release.
- **Version strategy** — **SemVer** (`X.Y.0-SNAPSHOT` → `X.Y.0`, then develop → `X.(Y+1).0-SNAPSHOT`)
  or **CalVer** (`YYYY.MM`, develop bumped to next month).
- **Release tags** — tag each release (`v1.2.0` / `2026.06`).
- **chore/\*** — chore branches (from/to develop or main), independent of feature/hotfix rules.

Enforcement: the **`pre-push` hook** blocks direct pushes to protected branches and (strict gitflow)
rejects non-conforming names; **`aiflow protect`** applies real server-side branch protection on
GitHub (PR + CI required); **`aiflow release [--push]`** bumps the version, tags, and bumps develop.
Agents read the model and obey it (CLAUDE.md §7).

---

## 16. Memory

The model forgets between sessions, so aiflow persists what matters:

- **Beads** — the durable task store (dependencies, status, history).
- **graphify** — a structural map of the code (build with `aiflow index` / `/graphify .`); query it
  instead of re-reading files.
- **`.claude/memory/`** (optional, toggle in config) — durable, non-obvious facts: `project-aim.md`
  (goal + architecture), `dev-environment.md` (OS/IDE/VCS), plus anything `onboard`/`explain` learn.
  Indexed in `.claude/MEMORY.md`.

---

## 17. Configuration model

Everything is driven by **`.aiflow/config.json`** (committed; contains no secrets). Shape:

```jsonc
{
  "caveman":   { "enabled": true, "mode": "full" },
  "rtk":       { "enabled": true },
  "router":    { "enabled": false },
  "graphify":  { "enabled": true },
  "taskmaster":{ "enabled": true },
  "mcp":       { "filesystem": true },
  "memory":    { "enabled": true },
  "vcs": "github",
  "project": { "aim": "...", "architecture": "..." },
  "dev": { "os": "windows", "ide": "vscode" },
  "git": { "model": "gitflow", "strict": true, "prOnly": true,
           "autoRelease": true, "versionStrategy": "semver", "releaseTags": true, "chore": true }
}
```

`aiflow change-settings` edits it interactively and re-applies (regenerates `.mcp.json`, hooks,
branching model, memory, etc.). Secrets always stay in `.env` (gitignored).

---

## 18. Tools are global, configuration is per-project

- **Tools / binaries** — installed once per user (`npm -g`, `uv tool`, brew/winget); shared across
  projects. `aiflow install-deps` puts them there. The router config also lives in your home dir.
- **Configuration & secrets** — per project: `.env` (gitignored, never global), `.aiflow/config.json`,
  `CLAUDE.md`, `.mcp.json`, `.claude/`, `.githooks/`, memory. Switching projects switches config;
  nothing leaks between them.

---

## 19. CI/CD

- **`.github/workflows/agent.yml`** — runs the headless Ralph loop in CI on three triggers: manual
  dispatch (with a prompt), the **`agent`** issue label, or a nightly cron. It installs the
  toolchain, runs the loop, pushes a branch, opens a PR on `COMPLETE`, and comments on the issue.
  Auth from repo secrets `ANTHROPIC_API_KEY` **or** `CLAUDE_CODE_OAUTH_TOKEN`.
- **`.github/workflows/ci.yml`** — detects the stack (Node/Python/Go/Dart) and runs format + tests.

---

## 20. Headless & containers

The headless Ralph loop runs two ways, identically:
- **Direct:** `aiflow ralph "<task>"` (uses your local claude/login).
- **Container:** `docker/run.sh "<task>"` — builds `docker/Dockerfile`, mounts the repo, injects
  tokens. Uses **Podman or Docker** (auto-detected; override with `AIFLOW_CONTAINER=podman|docker`).

---

## 21. Customising

- **Rules for all agents:** edit `CLAUDE.md` (overview §1, architecture §2, style §3, workflow,
  git, DoD).
- **Architecture hints:** quick rules in `CLAUDE.md §2`; the big picture in `docs/architecture/`
  (arc42); decisions as ADRs (`/arch "<question>"` writes them via the *architect* agent).
- **Agents:** markdown in `.claude/agents/` — change the prompt, restrict `tools:`, set a `model:`,
  or add a new file. A good `description` ("Use when…") improves automatic selection.
- **Skills:** add `.claude/commands/<name>.md`.
- **Permissions:** `permissions.allow` in `.claude/settings.json` pre-approves routine commands (all
  `bd`, git, the toolchain CLIs, read-only shell, build/test, formatters, MCP servers); add your own
  there or in `.claude/settings.local.json` (gitignored), or manage at runtime with `/permissions`.
  File edits (Edit/Write) are intentionally not pre-approved.
- **High-level toggles:** `aiflow change-settings`.

---

## 22. Project layout

```
CLAUDE.md                  rules every agent follows (architecture, Google style, workflow, git, DoD)
README.md / README.de.md   this manual (EN/DE)
LICENSE                    MIT
.aiflow/
  config.json              your choices (committed, no secrets) — edit via change-settings
  branching.json           derived git governance model
  ralph-headless.sh        autonomous loop runner
  run-agent.sh             generic headless agent runner (audits, onboard)
  version.sh, release.sh, protect.sh   release/versioning/branch-protection
  router-config.example.json           claude-code-router template
.env / .env.example        tokens (gitignored)
.gitignore .gitattributes  protect secrets; force LF on scripts
.mcp.json                  generated MCP servers (per config): filesystem + github (vcs=github) + graphify + task-master
.claude/
  settings.json            permissions + hooks
  agents/                  architect, planner, implementer, reviewer, tester, security-advisor,
                           quality-check, dependency-auditor, test-gap-advisor, performance-advisor,
                           docs-sync, requirements-check, onboarder
  commands/                intake-issue, decompose, plan-epic, implement, review-ac, arch,
                           security-check, quality-check, requirements-check, dependency-check,
                           test-gap, perf-check, docs-check, onboard, explain, standup
  hooks/                   format.sh (auto-format), caveman.sh (terse output)
  memory/                  project-aim.md, dev-environment.md, … (when memory enabled)
.githooks/                 commit-msg (Conventional Commits), pre-commit (format+lint+test), pre-push (branching)
.github/workflows/         agent.yml (agent in CI) + ci.yml (lint/test)
docs/
  architecture/            arc42 + ADRs
  branching.md             human-readable branching model
.beads/                    Beads task store (Dolt-backed)
VERSION                    current version (when auto-release is on)
```

---

## 23. Upgrading

```bash
aiflow upgrade     # updates claude-code, task-master-ai, claude-code-router, graphify, beads,
                   # rtk to latest, rebuilds the graph, and re-applies your config
```
aiflow itself needs no upgrade tool — `upgrade` is about the **dependencies** it orchestrates.

---

## 24. Troubleshooting

- **MCP won't connect:** Docker running? `GITHUB_TOKEN` set in `.env` and started via `aiflow shell`?
  Token scopes (repo, issues)?
- **Ralph ends BLOCKED immediately:** read `result.json` / `.aiflow/ralph.log` — usually unclear
  acceptance criteria or missing access.
- **`bd` errors / no database:** Beads needs **dolt** — `aiflow install-deps` installs it.
- **Auto-format/lint does nothing:** install the relevant formatter (CLAUDE.md §3).
- **pre-push blocks a push:** that's the branching model; use a proper branch/PR, or
  `AIFLOW_ALLOW_DIRECT_PUSH=1` for tooling.
- **`--router` won't start:** install claude-code-router and create `~/.claude-code-router/config.json`.
- **Container run fails:** ensure Podman or Docker is installed and its daemon/machine is running;
  force one with `AIFLOW_CONTAINER=podman|docker`.
- **jq missing:** required to read the config — `aiflow install-deps` installs it.

---

## 25. Contributing

Found a bug or have an idea? Contributions are very welcome.

- **Issues:** open one at https://github.com/Cyber93de/aiflow/issues with steps to reproduce or a
  clear description of the feature.
- **Pull requests:** fork → branch (`feat/…`, `fix/…`) → make the change → ensure the hooks pass
  (Conventional Commits, format, lint, tests) → open a PR against `main`.
- **Style:** aiflow follows its own rules — Google style for all languages, Conventional Commits,
  small reviewable changes. The repo's own `.githooks` enforce them.
- Be kind and constructive. I appreciate everyone who helps improve the project.

---

## 26. Feedback, ideas & bug reports

Ideas, feature wishes, criticism, and bug reports are all very welcome — that's how aiflow improves.
Open a [Discussion](https://github.com/Cyber93de/aiflow/discussions) or an
[issue](https://github.com/Cyber93de/aiflow/issues) (repro steps + OS + `aiflow doctor` output for
bugs). There's no paid tier or donation ask — a ⭐ and honest feedback are the best support. Thank you!

---

## 27. License

MIT — Copyright (c) 2026 Cyber93de. See [LICENSE](LICENSE).
