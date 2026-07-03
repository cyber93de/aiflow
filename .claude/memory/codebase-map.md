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
- `CLAUDE.md` — operating rules every agent reads (style, task workflow incl. sync gate, agents,
  memory/context stack, git rules).
- `.aiflow/*.sh` — audit/release/ralph helpers + `bd-close-sync.sh` (pull-before-push on close).
- `.claude/agents/*` — 13 subagents; `.claude/commands/*` — slash skills; `.claude/hooks/*` —
  caveman, format, beads-sync (SessionStart auto-pull); `.claude/settings.json` — permissions + hooks
  + MCP allow-list.
- `.githooks/*` — commit-msg, pre-commit, pre-push enforcement.
- `docker/` — Dockerfile + `run.sh` (Podman OR Docker, auto-detected). **No Dagger** (removed).
- `.env.example` — token layout; `docs/architecture/` — arc42 + ADR seed.

## docs/ (GitHub Pages, just-the-docs)
- `_config.yml` + 13 pages (index, getting-started, features, memory, agents, models, remotes, team,
  configuration, commands, workflows, faq, contributing). Deployed by `.github/workflows/pages.yml`.

## .github/workflows/
- `ci.yml` (validate: bash -n + shellcheck + JSON + PowerShell + dry-run build),
  `release.yml` (VERSION bump → tag + per-OS archives), `pages.yml` (docs deploy).

## Root
- `install.sh` / `install.ps1` (offer git/svn/ollama), `VERSION` (0.1.0), `LICENSE` (MIT),
  `CHANGELOG.md`, `README.md` / `README.de.md`.
