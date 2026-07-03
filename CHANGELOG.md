# Changelog

All notable changes to **aiflow** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Nothing yet._

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

[Unreleased]: https://github.com/Cyber93de/aiflow/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Cyber93de/aiflow/releases/tag/v0.1.0
