---
layout: default
title: Changelog
parent: Support
nav_order: 4
description: "aiflow changelog and release history: 0.8.0 orchestrated agent network, binding architecture rules, model tiers, Windows/WSL prerequisites; 0.7.0 queue mode (Beads as a work queue), four self-testing CI guards, hardened git hooks, project-update reach; 0.6.0 model routing for audit subagents, ponytail YAGNI skill, memory-setup skill; 0.5.0 native PowerShell (no more Git Bash on Windows) + OS-scoped release archives; 0.4.0 real multi-agent tooling (CLI installs, Copilot token-optimization, CodexSaver, open-ralph-wiggum); 0.3.0 agent-agnostic core + gitflow automation + Skills; 0.2.0 cross-platform scripts + self-update; 0.1.1 quality-gate release; and the 0.1.0 first public release."
---

# Changelog
{: .no_toc }

aiflow follows [Keep a Changelog](https://keepachangelog.com/) and
[Semantic Versioning](https://semver.org/). The authoritative, always-current changelog lives in the
repository: **[CHANGELOG.md](https://github.com/Cyber93de/aiflow/blob/main/CHANGELOG.md)**.

## 0.8.0 — an orchestrated agent network, binding architecture rules, Windows/WSL

Highlights:

- **The agent roster became a network, with an orchestrator.** Agents knew the rules but not each
  other, so routing lived in your head. The new **orchestrator** agent and `/orchestrate
  <goal|bead>` decide which specialist handles each step, dispatch exactly one at a time, judge the
  result and route on — planner → architect (when boundaries are crossed) → implementer → tester
  (risky changes) → reviewer → close. It never writes code, and every handover is written **into
  the bead**, so it survives a `/compact`. Every agent file gained a "Net & handoffs" section, and
  the audit agents stay outside the delivery loop: they only file beads, which re-enter at the top.
  See [Agents](agents).
- **Architecture rules are now binding (`AGENTS.md` §2).** What was an `[EDIT ME]` placeholder is a
  MANDATORY section in every language: layered with inward dependencies, interfaces at every seam,
  DAO as the only thing that talks to a store, DTOs across process boundaries, domain objects that
  never leave the domain. §2c makes it stick — a task that does not fit is **not implemented as
  is**: the agent stops before writing code, asks in PO language with options and consequences, and
  the answer is recorded. The reviewer treats each rule as a BLOCKER.
- **Model tiers per activity.** Instead of "Haiku for five audit agents", `aiflow apply` stamps a
  model per *kind of work*: reasoning (Opus, or Fable) for architecture, planning, review and
  security; Sonnet for implementation and tests; Haiku for mechanical scans. Override a whole tier
  or move a single agent, both surviving `aiflow change-settings`. See [Models](models).
- **Windows without MinGW.** aiflow's CLI runs in PowerShell + Git Bash, but anything that
  *compiles native code* belongs in WSL. `docs/installation.md` gained a Windows prerequisites
  section, `aiflow doctor` reports WSL, WSL2, the in-distro toolchain and firmware virtualisation —
  and warns when a MinGW/MSYS `gcc` sits on the Windows PATH. `install-deps` installs
  `build-essential` *inside* WSL and never falls back to MinGW.
- **New projects land on `main`, not `master`.** `aiflow init` never passed `--initial-branch`, so
  on older git the mainline was `master` — while the whole branching governance references `main`
  by name and therefore never applied. `init` forces `main` now, and `aiflow apply` renames an
  existing `master`, printing the remote-migration commands.

## 0.7.0 — queue mode, four CI guards, hardened git hooks

Highlights:

- **Queue mode — a closed task no longer ends the session.** Beads is treated as an authoritative
  work queue: after closing an issue the agent refreshes the queue and starts the next task instead
  of asking what to do. `aiflow next` ranks the candidates (priority → unblocks-most → continuation
  of the issue just closed) and exits `3` when nothing is actionable; a Claude Code `Stop` hook
  hands the next task back once if the agent forgets. Four documented reasons to stop, and the
  agent must name the one that applies. Opt out with `beads.queueMode` or `AIFLOW_QUEUE_MODE=off`.
  See [Workflows](workflows#queue-mode--a-closed-task-is-not-a-finished-session).
- **Four mechanical guards in CI, each with its own self-test.** The twin guard now looks *inside*
  a `.sh`/`.ps1` pair (a step added to one half only is reported), a new guard rejects `[ -x ]`
  gates in front of interpreted calls (the exec bit is invisible to `bash` and Windows drops it),
  the rendered-copy guard covers the agent/command/skill roster, and the Python CI helpers are
  finally compiled and linted themselves.
- **Git hooks that hold up in practice.** `pre-commit` now judges the **staged** content rather
  than your working tree, hooks warn about issue ids that do not exist, path lists are read with
  `core.quotePath=false` so non-ASCII filenames stop slipping through, merge and revert commits
  pass `commit-msg`, and scopes may be path-shaped (`docs(.aiflow)`).
- **`aiflow project-update` reaches further and still deletes nothing.** It now refreshes
  `.githooks/*` and `router-config.example.json` under the `*.bak` rule — so a shipped hook
  improvement finally arrives in existing projects — and reports helpers aiflow no longer ships
  instead of removing them.
- **Runs on macOS's system bash again.** Empty arrays under `set -u` and `mapfile` (bash 4+) broke
  `project-update` and `ollama pull` on bash 3.2; a macOS CI job now proves the fix, after
  asserting the runner really is on 3.2.

## 0.6.0 — cheap-model audit routing, ponytail, memory-setup skill

Highlights:

- **Model routing for audit-only subagents** — `modelRouting.enabled` (on by default) stamps
  `model: haiku` into the frontmatter of the 5 subagents that only do mechanical/background
  checks (**docs-sync**, **test-gap-advisor**, **dependency-auditor**, **performance-advisor**,
  **onboarder**), so they run on Haiku 4.5 instead of the session's main model — every other
  subagent keeps the session default since it needs real reasoning. Toggle it with
  `aiflow change-settings`.
- **ponytail** — a new YAGNI decision-ladder [skill](agents#slash-commands-and-skills) (off by default): before new
  code, dependencies, or abstractions, checks whether it needs to exist at all, is already in the
  codebase, is stdlib, a native platform feature, an installed dependency, or a one-liner — only
  then writes the minimum-viable new code. `/ponytail-review` audits a diff for over-engineering
  regardless of the toggle. Inspired by [dietrichgebert/ponytail](https://github.com/dietrichgebert/ponytail),
  reimplemented (not vendored) the same way as caveman.
- **memory-setup skill** — `AGENTS.md`'s Memory section shrank to a short toggle + essentials; the
  full context-routing stack, team preferences, and Ollama routing detail moved to a dedicated,
  auto-offered [skill](agents#slash-commands-and-skills). REST/Database rules and the Ralph-loop decision (both
  needed reliably on every relevant task) stay inline in `AGENTS.md` rather than moving to a
  skill — skills are Claude-Code-only and pattern-matched, not a guaranteed load.

## 0.5.1 — reliability fixes for `aiflow update` and `install-deps.ps1`

Highlights:

- **`aiflow update` no longer leaves stale files behind** after the 0.5.0 OS-split — it now
  removes the old `bin/`/`lib/` before installing the new archive.
- **`install-deps.ps1`'s DeepSeek/uv/bun auto-install path fixed** — a PowerShell native-exe
  argument-passing quirk was silently mangling a `jq` filter and crashing the installer.

## 0.5.0 — native PowerShell, no more Git Bash on Windows

Highlights:

- **Every core tool script now has a behavior-equivalent PowerShell twin** (`lib/*.ps1` for all
  10 `lib/*.sh` scripts) — **Windows needs no Git Bash or WSL at all anymore**, removing the
  0.4.1/0.4.2 launcher workarounds entirely.
- **OS-scoped release archives** — the Windows zip ships only PowerShell scripts, the Linux/macOS
  tarballs only bash; `templates/` still ships both shells to every OS since a generated project
  may target either regardless of host.
- Fixed a `jq` default-value bug that could silently flip an explicitly-set `false` config value
  back to `true`, and a PowerShell 5.1 mis-parse of UTF-8 em-dashes in two tool scripts.

## 0.4.2 — Windows launcher fix (bash.exe resolution)

Highlights:

- **`aiflow init` and every bash-backed subcommand fixed on Windows** — plain `bash` on `PATH`
  often resolves to WSL's stub, which can't parse Windows-style paths at all. The launcher now
  resolves Git for Windows' own `bash.exe` explicitly.

## 0.4.1 — Windows launcher fix (path normalization)

Highlights:

- **`aiflow init` fixed on Windows** — the PowerShell launcher built `AIFLOW_HOME` with
  backslashes, which mangled when interpolated into forward-slash bash paths. Normalized once,
  up front.

## 0.4.0 — real multi-agent tooling

Highlights:

- **CLIs actually get installed now.** `aiflow install-deps` installs Claude Code, GitHub Copilot
  CLI, and OpenAI Codex CLI per `agents.*` (previously only Claude Code was ever installed);
  `aiflow doctor` reports all three plus `ralph`/`bun`.
- **Each agent gets a real token-saving mechanism**, not just Claude Code: GitHub Copilot gets the
  [token-optimization guide](https://github.com/olivomarco/github-copilot-token-optimization) baked
  into `.github/copilot-instructions.md`; OpenAI Codex CLI gets an optional
  [CodexSaver](https://github.com/fendouai/CodexSaver) MCP router (`codexsaver.enabled`) that
  routes cheap/bounded work to a cheaper worker.
- **Ralph loop rebuilt on [open-ralph-wiggum](https://github.com/Th0rgal/open-ralph-wiggum)** —
  genuinely agent-agnostic (Claude Code/Codex CLI/Copilot CLI via `--agent`), replacing the old
  Claude-only hand-rolled loop. Known limitation: completion-promise auto-stop isn't always
  reliable — `--max-iterations` remains the real safety bound.
- Docs swept throughout to reflect the real per-agent picture instead of Claude-only framing.

## 0.3.1 — hotfix: release-process correctness

Highlights:

- **`branching.sh` no longer loses history when creating a missing local `main`/`develop`.**
  Previously it always branched off current `HEAD`; now it creates the branch from
  `origin/<branch>` when that remote ref exists, so a diverged `origin/develop` is never
  silently ignored.
- **Hotfix-branch detection now recognises GitHub PR-merge commits**, not just local
  `git merge` ones — both `aiflow release`'s merge-into-develop step and the `pre-push`
  main-restriction guard previously only matched `Merge branch 'X'` subjects and silently let
  `Merge pull request #N from owner/X` commits through unchecked.
- **`aiflow release` falls back to `origin/<hotfix-branch>`** when the local branch was already
  deleted (e.g. GitHub's "delete branch on merge" default), so the fix still lands on `develop`.
- **`release.yml` never publishes a release for an in-progress `-SNAPSHOT`/`-HOTFIX` `VERSION`**
  — it previously tagged and published whatever `VERSION` said verbatim, which could briefly be
  a literal `-HOTFIX`-suffixed string right after a hotfix PR merge and before `aiflow release
  --yes` stripped it.

## 0.3.0 — agent-agnostic core, gitflow automation, Skills, multi-host releases

Highlights:

- **Agent-agnostic core** — `AGENTS.md` is the shared source of truth for Claude Code, GitHub
  Copilot, and OpenAI Codex CLI; `CLAUDE.md` is now a one-line `@AGENTS.md` import. Sections only
  Claude Code can run automatically (subagents, hooks, slash-commands, the Ralph loop) are marked
  **(Claude Code only)**.
- **`agents.{claude,copilot,codex}` config** renders per-agent MCP config from one server set:
  `.mcp.json` (Claude), `.codex/config.toml` (Codex CLI), `.vscode/mcp.json` (Copilot).
- **Gitflow branching automation** — `bugfix/*` alongside `feature/*`; `main` restricted to
  `develop`/`hotfix/*`/`chore/*` (enforced by `pre-push`); `aiflow hotfix <name>`; `main` may
  never carry a `-SNAPSHOT`/`-HOTFIX` version; `aiflow release` defaults to a dry run — only
  `--yes` actually cuts a release.
- **Predefined release-publish workflows** for GitHub, GitLab, Gitea, Forgejo, and Bitbucket,
  written once per project (never overwriting an existing one) from `release-workflows/`.
- **GitKraken MCP** toggle, independent of the chosen remote host.
- **Skills** (`.claude/skills/<name>/SKILL.md`) — a new mechanism distinct from slash-commands:
  Claude Code matches a skill's `description` against the current task and offers to run it
  automatically. Ships with **seo-optimization**.
- **`aiflow update` now works on archive installs**, not just git checkouts — checks the GitHub
  Releases API, downloads the matching per-OS archive, and verifies it against `SHA256SUMS.txt`.
- **`aiflow project-update` now also refreshes agent definitions** — any customised file is kept
  as `*.bak` before being replaced, and reported so you can reapply your changes; `.beads/`,
  `.claude/memory/*`, and your project settings (aim, architecture) always survive untouched.
- **SEO pass** on the docs site (robots.txt, 404, favicon, JSON-LD structured data, Google Search
  Console verification) and refreshed `llms.txt`/`llms-full.txt` for context7.

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
