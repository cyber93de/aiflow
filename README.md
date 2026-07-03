# aiflow

**aiflow turns any repository into a governed, AI-driven software-delivery pipeline with one
command.** It wires [Claude Code](https://docs.claude.com/en/docs/claude-code) together with durable
task tracking, a two-layer code memory (structural **graph** + semantic **RAG**), autonomous work
loops, specialist review/audit agents, token/cost controls, enforced code style, a configurable git
branching model, and first-class **team collaboration** — so an AI agent (or a whole team of humans
+ agents) can take an issue, plan it, write the code in a consistent style, test it, review it
against acceptance criteria, audit it, and ship it through a real release process.

- **Token-based & vendor-neutral** — your own Anthropic API key *or* Claude Code OAuth token; git
  hosts via **tokens only, never OAuth**. No third-party hub.
- **Local-first option** — run easy work on **Ollama** models (no key), keep top models for hard
  reasoning.
- **Project-scoped** — secrets and settings live in the project (`.env`, `.aiflow/config.json`),
  never globally.
- **Cross-platform** — Windows, Linux, macOS.

> 🇩🇪 Diese Anleitung gibt es auch auf **[Deutsch → README.de.md](README.de.md)**.

**Version 0.1.0 · MIT License · [Changelog](CHANGELOG.md)**

---

## Contents

1. [Why aiflow — the advantages](#1-why-aiflow--the-advantages)
2. [Feature overview](#2-feature-overview)
3. [Install](#3-install)
4. [Build a first project (walk-through)](#4-build-a-first-project-walk-through)
5. [The tools aiflow installs](#5-the-tools-aiflow-installs)
6. [Memory: why a graph *and* a RAG index](#6-memory-why-a-graph-and-a-rag-index)
7. [Agents — the full roster](#7-agents--the-full-roster)
8. [Slash-command skills](#8-slash-command-skills)
9. [Delivery workflow & branching models](#9-delivery-workflow--branching-models)
10. [Team collaboration (multiple members)](#10-team-collaboration-multiple-members)
11. [Configuring the remote host (GitHub / GitLab / custom)](#11-configuring-the-remote-host)
12. [Claude access, Ollama & adding more models](#12-claude-access-ollama--adding-more-models)
13. [Working with context7](#13-working-with-context7)
14. [Adding your own MCP servers](#14-adding-your-own-mcp-servers)
15. [Configuration you should tune (CLAUDE.md, team preferences, …)](#15-configuration-you-should-tune)
16. [Command reference](#16-command-reference)
17. [Token & cost optimisation](#17-token--cost-optimisation)
18. [CI/CD & building releases](#18-cicd--building-releases)
19. [Project layout](#19-project-layout)
20. [FAQ](#20-faq)
21. [Troubleshooting](#21-troubleshooting)
22. [Credits & thanks](#22-credits--thanks)
23. [Feedback, ideas & bug reports](#23-feedback-ideas--bug-reports)
24. [Contributing](#24-contributing)
25. [License](#25-license)

📖 **Full documentation site:** [cyber93de.github.io/aiflow](https://cyber93de.github.io/aiflow/)

---

## 1. Why aiflow — the advantages

- **Better memory, fewer hallucinations.** Two complementary code indexes plus durable task memory
  mean the agent *looks things up* instead of guessing or re-reading dozens of files. See §6.
- **Big token reduction.** caveman (terse output ~75% fewer output tokens), rtk (CLI-output
  filtering 60–90% fewer), graph + RAG retrieval (~70% fewer than reading whole files), and optional
  cheap/local model routing. Measured with `aiflow cost`.
- **Team-ready.** Issues live in a shared Dolt database that syncs over your git remote. Atomic
  claiming prevents two people grabbing the same task; pull-before-push prevents clobbering. See §10.
- **Governed & auditable.** Conventional Commits, enforced Google style, a review gate against
  acceptance criteria, security/quality/deps/test/perf/docs audits, a real branching + release model.
- **Autonomous when you want it.** The Ralph loop finishes a task unattended (locally, in a
  container, or in CI) and stops at `COMPLETE`/`BLOCKED`.
- **Yours, not a hub.** Everything runs on your keys/tokens and your infrastructure; secrets never
  leave the project.

---

## 2. Feature overview

| Area | What you get |
|------|--------------|
| **Task tracking** | Beads (`bd`) — Dolt-backed issues with dependencies, status, history; survives context resets |
| **Code memory** | **graphify** (structural graph) + **cocoindex-code** (semantic RAG) + `.claude/memory/` facts |
| **External docs** | **context7** MCP — live, version-correct library documentation |
| **Version control** | Choose **git**, **svn**, or **none** at setup |
| **Remote host** | GitHub, GitHub Enterprise, GitLab, self-managed GitLab, Bitbucket, Forgejo, Gitea, or a custom URL — **token-based** |
| **Host MCP** | The matching git-host MCP is wired automatically (per remote type) |
| **Models** | Claude (API key *or* OAuth) + optional **Ollama** local models, selectable & auto-installed |
| **Model routing** | claude-code-router sends easy/background work to cheap/local models |
| **Agents** | 5 delivery + 6 audit + 1 brownfield specialist subagents |
| **Autonomy** | Ralph loop (interactive / headless / containerised / CI) |
| **Quality** | Google style, conventional commits, format/lint/test git hooks, review gate |
| **Branching** | simple / gitflow / none, PR-only, auto-release, SemVer/CalVer |
| **Team** | shared issue DB, atomic claim, session-start auto-pull, pull-before-push, shared preferences |
| **Token savings** | caveman + rtk on by default, graph/RAG retrieval, cost routing |

---

## 3. Install

**Prerequisites:** [Node.js](https://nodejs.org) (LTS). Everything else aiflow can install for you.

```bash
git clone https://github.com/Cyber93de/aiflow.git
cd aiflow
```

**Linux / macOS / Git-Bash:**
```bash
bash install.sh          # symlinks 'aiflow' onto your PATH
```

**Windows (PowerShell):**
```powershell
./install.ps1            # adds bin to PATH + creates the aiflow shim
```

The installer **asks once** whether to also install **git**, **Subversion (svn)**, and **Ollama** —
so a later `aiflow init` only has to ask *which* Ollama models you want. Then:

```bash
aiflow doctor            # see what's present / missing
aiflow install-deps --all   # install the rest of the toolchain (optional; init offers it too)
```

Or grab a packaged build from
**[github.com/Cyber93de/aiflow/releases](https://github.com/Cyber93de/aiflow/releases)**.

---

## 4. Build a first project (walk-through)

```bash
mkdir my-app && cd my-app
aiflow init                 # interactive Q&A → writes .aiflow/config.json → renders everything
```

`aiflow init` asks (Enter = the sensible default; token-saving + intensive graph memory are **on**):

1. **caveman / rtk** — token-saving output + CLI filtering (default on).
2. **graphify** (structural graph) and **cocoindex-code** (semantic RAG) — code memory (default on).
3. **task-master**, **filesystem MCP**, **context7 MCP** (default on).
4. **Memory** — enable persistent memory, graph learning, and **intensity** (default `aggressive`).
5. **Claude access** — `apikey` (ANTHROPIC_API_KEY) or `oauth` (`claude setup-token`).
6. **Version control** — `git` / `svn` / `none`.
7. **Remote host** — `github | github-enterprise | gitlab | gitlab-self | bitbucket | forgejo |
   gitea | custom | none`, plus which **host MCP** to wire. Token-based.
8. **Sync rule** — ask to push + Dolt-sync each time a Beads issue is closed; auto-pull at session start.
9. **Ollama** — set it up? which models? (`qwen3-coder` recommended).
10. **Shared team preferences** — code style, etc.
11. **Project aim / architecture / OS / IDE**, and the **git branching model** (if VCS = git).

Then fill secrets and start:

```bash
# edit .env → your git-host token + (ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)
aiflow shell                # loads .env, launches Claude Code with all MCPs wired
```

Inside the session:

```text
/beads:ready                # what's ready to work
bd create "Add health endpoint" -t task --claim   # create + claim a task
/implement                  # implementer builds it (code + tests, Google style)
/review-ac                  # reviewer gates it against acceptance criteria
```

**Existing codebase?** `aiflow init` detects it and offers `aiflow onboard`, which learns the code
into `.claude/memory/`, `CLAUDE.md`, and arc42 docs so the agent starts informed. Build the code
indexes any time with **`aiflow index`** (graph + RAG).

---

## 5. The tools aiflow installs

`aiflow install-deps` installs only what your config enables (`--all` = full set). All are
user-space; Docker is never auto-installed.

**Core (always):** Claude Code · Beads (`bd`) · Dolt (Beads' database backend) · jq · the git-host
CLI matching your remote (`gh`/`glab`).

**Optional (when enabled):** claude-task-master · claude-code-router · rtk · **graphify**
(needs `uv`) · **cocoindex-code** (`ccc`, needs `uv`) · **Ollama** (+ your selected models).

Headless container runs (`docker/run.sh`) and the GitHub MCP work with **Podman or Docker** —
install either one yourself (never auto-installed).

`aiflow doctor` shows what's present, plus a per-project summary (remote + host MCP, VCS, Ollama
models, memory: graph/rag/context7 + intensity).

---

## 6. Memory: why a graph *and* a RAG index

LLMs forget between sessions and burn tokens re-reading files. aiflow gives the agent a **layered
context stack** so it *routes* a question to the cheapest source that answers it. The full routing
table is written to `.claude/memory/memory-policy.md`:

| Need | Source | Why |
|------|--------|-----|
| Current task, deps, decisions, session state | **Beads** (`bd`) | structured work memory, survives compaction |
| Durable project facts / gotchas / env quirks | **memory files** (`.claude/memory/`) | prose not in code/git |
| Where a symbol is defined, who calls it, dependency direction | **graphify** (MCP) | exact structural graph — no re-scan |
| "Find the code about concept X" / semantic / fuzzy | **cocoindex-code** (`ccc` / MCP) | AST-aware RAG, local embeddings, ~70% fewer tokens |
| External library/framework API docs | **context7** (MCP) | live upstream docs, avoids hallucination |
| Anything still unresolved | read the file(s) | only after graph + RAG narrowed the target |

**Why a graph?** Code is a graph (imports, calls, types). A graph answers *structural* questions
("who calls `parseToken`? what does `auth` depend on?") exactly and cheaply — no guessing, no
re-reading, and it discourages DRY violations because the agent can *see* existing code.

**Why also RAG?** A graph doesn't answer *fuzzy* questions ("where is retry logic handled?").
cocoindex-code chunks the code AST-aware, embeds it **locally** (sentence-transformers, no API key),
and searches by meaning — ~70% fewer tokens than opening files. It's incremental: only changed files
re-embed.

Refresh **both** indexes with one command after significant changes:

```bash
aiflow index            # = graphify build  +  ccc index   (incremental)
```

---

## 7. Agents — the full roster

Specialist subagents live in `.claude/agents/`. Claude picks one by its `description`, or you invoke
it explicitly. Customise any by editing its markdown (prompt, allowed `tools:`, `model:`).

### Delivery agents (do the work)
| Agent | Role |
|-------|------|
| **architect** | System design — produces ADRs, arc42 updates, and a task breakdown. No feature code. |
| **planner** | Turns a goal/epic/issue into small Beads tasks with testable acceptance criteria + real dependencies. |
| **implementer** | Builds exactly one ready bead (code + tests) in Google style; stops as BLOCKED if criteria are unclear. |
| **reviewer** | The quality gate — reviews a diff against acceptance criteria, correctness, tests, style. Verdict PASS / CHANGES REQUIRED. |
| **tester** | Writes meaningful tests, hunts edge cases; reports bugs instead of weakening tests. |

### Audit agents (manual, read-only on code, file prioritised Beads)
| Agent | Command | Files issues labelled |
|-------|---------|-----------------------|
| **security-advisor** | `aiflow security-check` | `[security-advisor]` |
| **quality-check** | `aiflow quality-check` | `[technical issue]` |
| **dependency-auditor** | `aiflow dependency-check` | `[dependency]` |
| **test-gap-advisor** | `aiflow test-gap` | `[test gap]` |
| **performance-advisor** | `aiflow perf-check` | `[performance]` |
| **docs-sync** | `aiflow docs-check` | `[docs]` |
| **requirements-check** | `aiflow requirements-check` | *report only* (advisory; grades issue quality vs architecture; no changes) |

### Brownfield agent
| Agent | Role |
|-------|------|
| **onboarder** | Studies an existing codebase and persists what it learns into `.claude/memory/`, `CLAUDE.md`, and arc42 — future sessions start informed. Writes docs/memory only. |

---

## 8. Slash-command skills

Triggerable inside Claude Code (`.claude/commands/`):

- **Delivery:** `/intake-issue <n>` (pull a GitHub/GitLab/Bitbucket issue → Beads),
  `/decompose <goal|prd>` (task-master → Beads), `/plan-epic`, `/implement [bead]`, `/review-ac`,
  `/arch "<question>"`.
- **Audits:** `/security-check`, `/quality-check`, `/requirements-check`, `/dependency-check`,
  `/test-gap`, `/perf-check`, `/docs-check`.
- **Brownfield / orientation:** `/onboard`, `/explain <path>`, `/standup`.

Beads and the Ralph loop also ship as plugin skills (`/beads:ready`, `/beads:decision`, `/ralph-loop`).

---

## 9. Delivery workflow & branching models

```
Issue (GitHub / GitLab / Bitbucket / …)
  └─ /intake-issue ─▶ Beads tasks (with acceptance criteria)
       └─ /decompose (task-master) ─▶ subtasks + dependencies
            └─ bd ready --claim ─▶ pick & claim a task
                 └─ /implement ─▶ code + tests, Google style      (implementer)
                      └─ /review-ac ─▶ gate vs acceptance criteria (reviewer)
                           └─ commit (Conventional Commits + bead id) ─▶ PR ─▶ release
                                └─ aiflow close-sync ─▶ push + Dolt-sync issues
```

**Branching models** (`aiflow init` / `change-settings`, only when VCS = git). aiflow writes
`.aiflow/branching.json` + a readable `docs/branching.md`, creates permanent branches, seeds
`VERSION`, and installs enforcement:

- **Model** — `simple` (main + develop) · `gitflow` (`feature/*` from develop, `hotfix/*` from main) · `none`.
- **Strict rules** — enforce branch sources/targets and naming.
- **PR-only** — no direct push to main/develop; merge only via a validated PR.
- **Auto-release** — merging develop → main cuts a release.
- **Version strategy** — SemVer or CalVer; optional release tags.
- **chore/\*** — chore branches independent of feature/hotfix rules.

Enforcement: the `pre-push` hook blocks direct pushes to protected branches; `aiflow protect`
applies real server-side branch protection on GitHub; `aiflow release [--push]` bumps the version,
tags, and bumps develop.

---

## 10. Team collaboration (multiple members)

Beads issues live in a **shared Dolt database** that syncs via `refs/dolt/data` on your git remote —
one issue graph for the whole team, no extra server.

- **Sync at session start.** A `SessionStart` hook auto-runs `bd dolt pull` (safe, best-effort, never
  pushes; opt-out via `sync.pullOnStart`). Or manually: `aiflow sync`.
- **Claim atomically.** `bd ready --claim` / `bd update <id> --claim` sets assignee = you + status =
  in_progress in one step, so **two people never grab the same task**. `bd ready --unassigned` shows
  free work.
- **Pull before push, always.** `aiflow sync` and `aiflow close-sync` pull first, so you merge
  teammates' issue changes instead of clobbering them. On conflict: `bd dolt pull` (merge), resolve,
  push. Never force-push.
- **Status is the coordination signal.** Keep it current; stale status = duplicate work.
- **Discovered work → a new bead** (`--deps discovered-from:<id>`); **decisions → `/beads:decision`**
  (recorded with rationale) so the whole team sees the *why*.
- **Shared preferences** (code style, language) live in a committed `.aiflow/team-prefs.json` — the
  whole team inherits them; personal tweaks stay local.

---

## 11. Configuring the remote host

aiflow is **token-based only — no OAuth for git hosts**. Pick the type at init/change-settings; the
matching CLI and MCP are wired automatically.

| Remote type | Base URL | Token env (`.env`) | Host MCP wired |
|-------------|----------|--------------------|----------------|
| `github` | github.com | `GITHUB_TOKEN` | github-mcp-server |
| `github-enterprise` | your GHE URL | `GITHUB_TOKEN` | github-mcp-server (`GITHUB_HOST` set) |
| `gitlab` / `gitlab-self` | gitlab.com / your URL | `GITLAB_TOKEN` | server-gitlab (`GITLAB_API_URL` set) |
| `bitbucket` | your URL | `BITBUCKET_TOKEN` | atlassian-bitbucket |
| `forgejo` / `gitea` | your URL | `GIT_REMOTE_TOKEN` | gitea-mcp-server (`GITEA_URL` set) |
| `custom` | any URL | your env var | pick from the list (or `none`) |

**GitHub example:** create a PAT with repo + issues + pull_requests scope → put it in `.env` as
`GITHUB_TOKEN`. **GitLab example:** create a personal access token with `api` scope → `GITLAB_TOKEN`.
For self-managed/enterprise, give the base URL at init; aiflow wires the API URL / host into the MCP.

Beads issue sync (`bd github`/`bd gitlab`) and Dolt sync use the same remote. Change any of this
later with `aiflow change-settings` (re-renders `.mcp.json`, hooks, everything).

---

## 12. Claude access, Ollama & adding more models

**Claude access** (`.aiflow/config.json → claude.auth`, both supported, OAuth wins if both set):
- `apikey` → `ANTHROPIC_API_KEY` (pay-per-use, [console.anthropic.com](https://console.anthropic.com)).
- `oauth` → run `claude setup-token` → `CLAUDE_CODE_OAUTH_TOKEN` (uses your Claude plan).

**Ollama (local, no API key).** Enable at init, or:
```bash
aiflow ollama add qwen3-coder     # add a model to config + pull it
aiflow ollama pull                # pull every model listed in config
aiflow ollama list                # what's installed
```
Selected models are written into `.aiflow/router-config.json` as a provider, so they're actually
used for easy/background work:
```bash
aiflow shell --router             # routes cheap/background steps to local models
```

**Adding more / cloud models** (DeepSeek, OpenRouter, Gemini, …): add the provider + key to
`~/.claude-code-router/config.json` (never committed) and enable `router` in the config. `.env` also
lists optional keys (`DEEPSEEK_API_KEY`, `OPENROUTER_API_KEY`, `GEMINI_API_KEY`). Route trivial steps
to cheap models, keep top Claude models for hard reasoning; measure with `aiflow cost`.

---

## 13. Working with context7

**context7** is an MCP server that fetches **live, version-correct documentation** for the libraries
you use — so the agent codes against the real current API instead of a stale memory. It's enabled by
default (`mcp.context7`).

- In a session, just ask normally ("use the latest `zod` schema API") — the agent calls context7 to
  pull current docs. You can also nudge it: *"check context7 for the current Prisma migrate API"*.
- It works **keyless**; a `CONTEXT7_API_KEY` in `.env` raises rate limits.
- Pair it with the code indexes: **context7** = *external* library docs, **graphify/cocoindex** =
  *your* code.

---

## 14. Adding your own MCP servers

aiflow generates `.mcp.json` from `.aiflow/config.json`, but you can add any extra MCP server —
your edits to servers aiflow doesn't manage are preserved on re-render. Add an entry:

```jsonc
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "@scope/my-mcp-server"],
      "env": { "MY_TOKEN": "${MY_TOKEN}" }   // secrets via .env, never inline
    }
  }
}
```

Then allow it in `.claude/settings.json` under `permissions.allow` (e.g. `"mcp__my-server"`) and put
any secret in `.env` (gitignored). For community-vetted servers, browse the marketplace:
`npx claude-code-templates@latest`. Tip: prefer a focused MCP over a broad one — fewer tools = less
context and fewer wrong turns.

---

## 15. Configuration you should tune

Everything is driven by **`.aiflow/config.json`** (committed, no secrets). Edit it interactively with
`aiflow change-settings` (re-renders `.mcp.json`, hooks, branching, memory). The files most worth
tuning:

- **`CLAUDE.md`** — the operating rules every agent reads (project overview, architecture hints, code
  style, task workflow, git rules, the memory/context stack, communication). **Fill the `[EDIT ME]`
  blocks** (§1 overview, §2 architecture) — this is the single biggest quality lever.
- **`.aiflow/team-prefs.json`** ("preferences") — shared, versioned team/user preferences: code
  style preset, language, conventions. Committed so the team inherits them; overrides `CLAUDE.md §3`.
- **`.claude/memory/`** — `project-aim.md` (goal + architecture), `dev-environment.md`,
  `memory-policy.md` (the retrieval routing + learning intensity). Keep these current.
- **`.claude/settings.json`** — permissions (allow/deny), hooks (caveman, formatter, beads-sync),
  MCP allow-list.
- **`.aiflow/branching.json` / `docs/branching.md`** — the branching + release model.
- **`.env`** — all tokens/keys (gitignored, never global).

Shape of `config.json`:
```jsonc
{
  "caveman":  { "enabled": true, "mode": "full" },
  "rtk":      { "enabled": true },
  "router":   { "enabled": false },
  "graphify": { "enabled": true },
  "taskmaster": { "enabled": true },
  "mcp":      { "filesystem": true, "context7": true, "cocoindex": true },
  "memory":   { "enabled": true, "graph": true, "intensity": "aggressive" },
  "claude":   { "auth": "apikey" },
  "vcs":      { "system": "git" },
  "remote":   { "type": "github", "baseUrl": "https://github.com",
                "api": "github-api", "tokenEnv": "GITHUB_TOKEN", "mcp": "github" },
  "sync":     { "askOnClose": true, "pullOnStart": true },
  "ollama":   { "enabled": false, "url": "http://localhost:11434", "models": [] },
  "teamPrefs":{ "enabled": false, "codeStyle": "google" },
  "project":  { "aim": "…", "architecture": "…" },
  "dev":      { "os": "windows", "ide": "vscode" },
  "git":      { "model": "gitflow", "strict": true, "prOnly": true,
                "autoRelease": true, "versionStrategy": "semver", "releaseTags": true, "chore": true }
}
```

---

## 16. Command reference

```text
aiflow init [path] [--force] [--no-git] [--no-beads] [--yes]   bootstrap a project
aiflow install-deps [--all]        install missing tools (enabled in config; --all = full set)
aiflow change-settings             re-adjust config, then re-render everything
aiflow shell [--router]            load .env then launch Claude Code (--router = cheap/local models)
aiflow sync [pull|push|both]       team sync: git + Beads(dolt) pull/push
aiflow close-sync <id>             on issue close: prompt to push + Dolt-sync the remote
aiflow ollama [pull|add <m>|list]  manage local Ollama models
aiflow index                       refresh code memory: graphify (graph) + cocoindex (RAG)
aiflow ralph "<prompt|bead id>"    run the headless Ralph loop
aiflow onboard                     learn an existing codebase into memory + CLAUDE.md + arc42
aiflow security-check | quality-check | requirements-check | dependency-check
aiflow test-gap | perf-check | docs-check      on-demand audits → Beads issues
aiflow release [--push]            cut a release per the branching model
aiflow protect                     apply server-side branch protection (GitHub)
aiflow cost [...]                  token/cost baseline via ccusage
aiflow doctor                      check prerequisites + project summary
aiflow upgrade                     update the bundled toolchain
aiflow version
```

---

## 17. Token & cost optimisation

- **caveman** — terse output mode (~75% fewer output tokens; code/commits/security stay normal). On by default.
- **rtk** — filters/compresses verbose command output before it enters context (60–90% fewer). On by default.
- **graph + RAG retrieval** — answer from graphify/cocoindex instead of reading whole files (~70% fewer).
- **model routing** — send easy/background steps to cheap or local (Ollama) models via `aiflow shell --router`.
- **measure first** — `aiflow cost` (ccusage) shows real spend so you optimise what matters.

---

## 18. CI/CD & building releases

- **`.github/workflows/ci.yml`** — validates the toolchain on push/PR: `bash -n` on all scripts,
  shellcheck (advisory), JSON validation of templates, PowerShell parse, and a **dry-run build** of
  the per-OS archives (uploaded as an artifact).
- **`.github/workflows/release.yml`** — on every push to `main`, if `VERSION` has no matching tag it
  builds per-OS archives (`linux.tar.gz`, `macos.tar.gz`, `windows.zip` + SHA256SUMS), tags
  `v<VERSION>`, and publishes a GitHub Release. **Bump `VERSION`, push → a release is cut.**
- **Projects** also get `.github/workflows/ci.yml` (detects Node/Python/Go/Dart → format + tests)
  and `.github/workflows/agent.yml` (runs the Ralph loop in CI on manual dispatch, the `agent` issue
  label, or nightly; auth from `ANTHROPIC_API_KEY` **or** `CLAUDE_CODE_OAUTH_TOKEN` repo secrets).

Build locally the same way CI does:
```bash
ver=$(cat VERSION); stage="aiflow-$ver"
mkdir -p "dist/$stage" && cp -r bin lib templates install.sh install.ps1 README*.md LICENSE VERSION "dist/$stage/"
( cd dist && tar -czf "aiflow-$ver-linux.tar.gz" "$stage" )
```

---

## 19. Project layout

```
your-project/
├─ .aiflow/
│  ├─ config.json            # the single source of truth (committed)
│  ├─ team-prefs.json        # shared team preferences (committed)
│  ├─ router-config.json     # generated: Ollama/cost providers (gitignored)
│  ├─ bd-close-sync.sh       # close → prompt push + Dolt-sync
│  └─ *.sh                   # audit/release/ralph helpers
├─ .beads/                   # Beads issue database (Dolt)
├─ .claude/
│  ├─ agents/  commands/     # subagents + slash commands
│  ├─ hooks/                 # caveman, formatter, beads-sync (SessionStart)
│  ├─ memory/                # project-aim, dev-environment, memory-policy
│  └─ settings.json          # permissions + hooks + MCP allow-list
├─ .githooks/                # commit-msg, pre-commit, pre-push (enforcement)
├─ docs/architecture/        # arc42 + ADRs
├─ .mcp.json                 # generated from config (host MCP, graphify, cocoindex, context7, …)
├─ CLAUDE.md                 # operating rules every agent reads
└─ .env                      # secrets (gitignored, never global)
```

---

## 20. FAQ

**Do I need an Anthropic API key?** Either an API key *or* a Claude Code OAuth token (`claude
setup-token`) — pick `claude.auth` at init.

**Does it work offline / privately?** Code indexing (cocoindex-code) and embeddings are **local**
(no key). With Ollama you can run models locally too. Claude itself still calls Anthropic.

**Is my data sent anywhere?** Secrets stay in `.env` (gitignored, never global). Only what Claude
needs for a request goes to Anthropic (or your local models via the router).

**graphify vs cocoindex — do I need both?** They're complementary: graphify answers *structural*
questions exactly; cocoindex answers *semantic/fuzzy* ones cheaply. Both are recommended (§6).

**How do I add another model?** Ollama: `aiflow ollama add <model>`. Cloud: add it to
`~/.claude-code-router/config.json` and enable `router` (§12).

**How do I use GitLab / Bitbucket / self-hosted instead of GitHub?** `aiflow change-settings` → pick
the remote type (or `custom` + base URL) → put the token in `.env` (§11).

**Can several people work in one project?** Yes — that's a core feature (§10): shared Dolt issue DB,
atomic claim, session-start pull, pull-before-push.

**How do I change my mind later?** `aiflow change-settings` re-runs the Q&A and re-renders
`.mcp.json`, hooks, branching, and memory from the new config.

**Do I have to pre-install tools?** No. The installer offers git/svn/ollama; `aiflow install-deps`
(or `aiflow init`) installs the rest.

**Something references the wrong git host / token?** Re-run `aiflow change-settings`; check `.env`
has the token env named in `remote.tokenEnv`; `aiflow doctor` shows the resolved config.

---

## 21. Troubleshooting

- **`jq is required`** — install jq (`aiflow install-deps` does). aiflow reads/writes `config.json` with it.
- **`bd`/Dolt errors** — `aiflow install-deps` installs both; `bd dolt status` checks the server.
- **MCP server won't start** — run `aiflow doctor`; check the tool is installed (`ccc`, `graphify`,
  Docker for the GitHub MCP) and the token env in `.env` matches `remote.tokenEnv`.
- **Ollama models unused** — enable `router` and run `aiflow shell --router`; confirm
  `.aiflow/router-config.json` lists your models and `ollama list` has them.
- **Dolt sync conflict** — `bd dolt pull` (merge), resolve, then `bd dolt push`. Never force-push.
- **Report a bug** — open an issue at https://github.com/Cyber93de/aiflow/issues with repro steps.

---

## 22. Credits & thanks

aiflow is glue. Enormous thanks to the projects it stands on — please star and support them:

- **[Claude Code](https://docs.claude.com/en/docs/claude-code)** (Anthropic) — the agent runtime everything builds on.
- **[Beads](https://github.com/steveyegge/beads)** — Dolt-backed issue tracker; durable task memory across sessions.
- **[Dolt](https://github.com/dolthub/dolt)** (DoltHub) — the versioned SQL database that makes team issue-sync work.
- **[graphify](https://github.com/safishamsi/graphify)** — the structural code knowledge graph over MCP.
- **[CocoIndex](https://github.com/cocoindex-io/cocoindex)** & **[cocoindex-code](https://github.com/cocoindex-io/cocoindex-code)** — the incremental, AST-aware semantic RAG index (`ccc`).
- **[Context7](https://github.com/upstash/context7)** (Upstash) — live, version-correct library docs over MCP.
- **[claude-task-master](https://github.com/eyaltoledano/claude-task-master)** — goal/PRD → task tree.
- **[claude-code-router](https://github.com/musistudio/claude-code-router)** — model routing for cost/local models.
- **[Ollama](https://ollama.com)** — local model runtime (no API key).
- **[rtk](https://www.rtk-ai.app/)** — CLI-output filtering to cut context.
- **[ccusage](https://github.com/ryoppippi/ccusage)** — token/cost analytics.
- **[claude-code-templates](https://github.com/davila7/claude-code-templates)** — community agents/commands/MCPs/hooks.
- **[Model Context Protocol](https://github.com/modelcontextprotocol/servers)** — the MCP servers ecosystem.

Trademarks and projects belong to their respective owners; aiflow is an independent integration and
is not affiliated with or endorsed by them.

---

## 23. Feedback, ideas & bug reports

**This project lives on your input — and it's very welcome.** Whether it's a rough idea, a feature
wish, a "why does it work like that?", or straight-up criticism: bring it on. Honest feedback is how
aiflow gets better.

- 💡 **Ideas & suggestions** — open a [GitHub Discussion](https://github.com/Cyber93de/aiflow/discussions)
  or an [issue](https://github.com/Cyber93de/aiflow/issues). No idea is too small or too wild.
- 🗣️ **Criticism welcome** — tell us what's confusing, clunky, or missing. Disagreement is useful.
- 🐛 **Bug reports** — open an [issue](https://github.com/Cyber93de/aiflow/issues) with steps to
  reproduce, your OS, and the relevant `aiflow doctor` output. Small repro = fast fix.
- 🙌 **Support** — if aiflow helps you, a ⭐ on the repo, a shared link, or a kind word genuinely
  makes the day. Thank you for being here.

There is **no paid tier and no donation ask** — the best support is your feedback, a star, and
telling a friend.

---

## 24. Contributing

Issues and PRs welcome at **https://github.com/Cyber93de/aiflow**. aiflow dogfoods itself: it uses
Beads for its own tasks, Conventional Commits, and the CI workflow (`bash -n`, shellcheck, JSON +
PowerShell validation) must pass. Keep changes project-scoped and secret-free.

---

## 25. License

**MIT** — Copyright (c) 2026 Cyber93de. See [LICENSE](LICENSE).

aiflow vendors nothing — it installs/invokes external tools, each under its own license. See
[THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for attribution.

---

<sub>**Topics / keywords:** Claude Code · Anthropic Claude · AI coding agent · agentic software
delivery · MCP (Model Context Protocol) · Beads · Dolt · graphify · code knowledge graph · CocoIndex ·
cocoindex-code · semantic code search · RAG · Context7 · Ollama · local LLM · claude-code-router ·
rtk · caveman · token optimization · Ralph loop · gitflow · Conventional Commits · GitHub · GitLab ·
Bitbucket · Forgejo · Gitea. &nbsp;·&nbsp; Suggested GitHub repo topics: `claude-code`, `anthropic`,
`ai-agent`, `mcp`, `beads`, `rag`, `code-search`, `ollama`, `context7`, `rtk`, `caveman`,
`developer-tools`, `cli`.</sub>
