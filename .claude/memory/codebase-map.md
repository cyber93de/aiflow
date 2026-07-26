# aiflow codebase map (self)

## bin/
- `aiflow` — bash dispatcher. Subcommands: init, install-deps, change-settings, shell, sync,
  close-sync, ollama, index, ralph, onboard, security-check/quality-check/requirements-check/
  dependency-check/test-gap/perf-check/docs-check, release, protect, cost, upgrade, doctor, version.
- `aiflow.ps1` / `aiflow.cmd` — Windows launcher (must mirror `aiflow`).

## lib/ (the logic)
- `init.sh` — new/existing-project detection, copies `templates/*` (no clobber), runs the interactive
  Q&A, writes `.aiflow/config.json`, git/svn/none init, beads init, calls `apply.sh`, offers
  install-deps + onboard. **Biggest file; the Q&A order lives here.**
- `apply.sh` — renders everything from config (see [[architecture]]). Reads `.remote.*` (with legacy
  `.vcs` string fallback), `.vcs.system`, `.mcp.*`, `.memory.*`, `.ollama.*`, `.sync.*`, `.teamPrefs.*`.
- `settings.sh` — `change-settings`: re-run Q&A with current values as defaults, rewrite config via
  `jq -n`, re-apply. **Must mirror every field init.sh writes.**
- `install-deps.sh` — installs only enabled tools (winget/scoop/brew/apt/dnf/pacman/scripts). Core:
  claude, beads, dolt, jq, host CLI. Optional: task-master, ccr, rtk, graphify(uv), cocoindex(uv),
  ollama. A container engine (Podman/Docker) is never auto-installed.
- `ollama.sh` — `aiflow ollama pull|add|list`; installs ollama, starts daemon, pulls config models.
- `doctor.sh` — prerequisite checks (each `--version` probe wrapped in `timeout 5`) + per-project
  summary block (remote/host-mcp/vcs/ollama/memory).
- `branching.sh` — writes `.aiflow/branching.json` + `docs/branching.md`, creates branches (git only).
- `upgrade.sh` — updates the dependency toolchain.

## templates/ (copied into target projects)
- `AGENTS.md` — agent-agnostic operating rules every coding agent reads (style, task workflow
  incl. sync gate, agents, memory/context stack, git rules). Sections marked "(Claude Code only)"
  are subagents/hooks/slash-commands/Ralph loop that only Claude Code can dispatch automatically.
  `CLAUDE.md` is a one-line `@AGENTS.md` import (Claude Code's native memory-import syntax).
  `.github/copilot-instructions.md` points Copilot at `AGENTS.md`; Codex CLI reads `AGENTS.md`
  directly by convention (no pointer file needed).
- `.aiflow/*.sh`(+`.ps1`) — audit/ralph helpers + `bd-close-sync.sh` (pull-before-push on close) +
  `version.sh`/`release.sh`/`hotfix.sh` (gitflow version bump/release/hotfix — see [[architecture]]).
- `.claude/agents/*` — 13 subagents; `.claude/commands/*` — slash-commands;
  `.claude/skills/<name>/SKILL.md` — auto-offered skills (Claude matches `description` to context;
  first one shipped: `seo-optimization`); `.claude/hooks/*` — caveman, format, beads-sync
  (SessionStart auto-pull); `.claude/settings.json` — permissions + hooks + MCP allow-list. All
  Claude Code-only.
- `.githooks/*` — commit-msg, pre-commit, pre-push enforcement (pre-push also enforces the gitflow
  branching model + blocks `-SNAPSHOT`/`-HOTFIX` VERSION from reaching `main` — vendor-neutral,
  works regardless of which agent/human pushes).
- `docker/` — Dockerfile + `run.sh` (Podman OR Docker, auto-detected). **No Dagger** (removed).
- `.env.example` — token layout; `docs/architecture/` — arc42 + ADR seed.

## release-workflows/ (repo root, NOT under templates/)
- One release-publish CI template per host (`github.yml`, `gitlab.yml`, `gitea.yml`,
  `forgejo.yml`, `bitbucket.yml`) — deliberately outside `templates/` (which is blindly copied
  whole) so `apply.sh` copies only the one matching `remote.type`, never clobbering an existing
  file at the target path.

## docs/ (GitHub Pages, just-the-docs)
- `_config.yml` + pages incl. index, getting-started, features, memory, agents, workflows,
  **multi-agent** (Claude Code/Copilot/Codex CLI support), models, remotes, team, configuration,
  config-schema, commands, faq, contributing. Deployed by `.github/workflows/pages.yml`.

## .github/workflows/
- `ci.yml` (validate: bash -n + shellcheck + JSON + PowerShell + dry-run build),
  `release.yml` (VERSION bump → tag + per-OS archives), `pages.yml` (docs deploy).

## Root
- `install.sh` / `install.ps1` (offer git/svn/ollama), `VERSION`, `LICENSE` (MIT),
  `CHANGELOG.md`, `README.md` / `README.de.md`, `AGENTS.md`/`CLAUDE.md` (this repo's own — see
  the "Agents & quality gates (self-hosted aiflow)" section of the root `CLAUDE.md`).
