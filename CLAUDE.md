# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:6cd5cc61 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->


## Build & Test

No build step — aiflow is Bash + PowerShell + templates. Validate like CI does:

```bash
# syntax: every shell script + the CLI entry point
find . -name '*.sh' -not -path './.git/*' -not -path './.beads/*' -exec bash -n {} +
bash -n bin/aiflow
# all JSON templates/configs
find . -name '*.json' -not -path './.git/*' -not -path './.beads/*' -exec jq empty {} +
# advisory lint
shellcheck -S error lib/*.sh bin/aiflow templates/.aiflow/*.sh
# PowerShell twins: parse-only syntax check (no execution)
powershell -NoProfile -Command '
  $err=$false
  Get-ChildItem -Recurse -Filter *.ps1 templates,bin | ForEach-Object {
    $tokens=$null; $e=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$e)
    if ($e.Count -gt 0) { $err=$true; "PARSE ERROR: $($_.FullName)"; $e }
  }
  if ($err) { exit 1 }'
# render test: init into a temp dir and inspect the generated project
AIFLOW_HOME="$PWD" bash lib/init.sh /tmp/aiflow-rendertest --yes --no-beads --no-install-deps
```

## Architecture Overview

- **`bin/aiflow`** — CLI dispatcher (Bash); `bin/aiflow.ps1` is a thin PowerShell shim.
- **`lib/*.sh`** — subcommand implementations (`init`, `apply`, `settings`, `doctor`,
  `install-deps`, `branching`, `ollama`, `upgrade`, `update`, `project-update`). `update.sh`
  self-updates the aiflow install (`git pull` in `AIFLOW_HOME`); `project-update.sh` refreshes
  a single project's mechanical scripts from the installed templates and bumps
  `.aiflow/config.json`'s `meta.aiflowVersion` stamp. `init.sh` copies `templates/` into a target
  project, asks the Q&A, writes `.aiflow/config.json`; `apply.sh` renders everything
  (`.mcp.json`, hooks, memory, branching) from that config — **idempotent**.
- **`templates/`** — everything a generated project receives: `CLAUDE.md` (operating rules incl.
  quality gates §3a/§3b/§3c), `.claude/agents|commands|hooks`, `.aiflow/*.sh` helpers, git hooks,
  CI workflows, docker. **Template changes are the product** — most features land here.
- **`docs/`** — GitHub Pages site (just-the-docs); `docs/assets/terminal/` holds the GIF sources
  (`make-casts.mjs` + agg; regenerate after CLI-output changes).
- Releases: bump `VERSION` + update `CHANGELOG.md`, push to `main` → `release.yml` tags and
  publishes per-OS archives. A pushed `VERSION` without a matching tag always cuts a release.

## Conventions & Patterns

- Google Shell Style; scripts start `set -uo pipefail` (CLI: `set -euo pipefail`); user-facing
  strings terse; no secrets anywhere (tokens only via generated `.env`, gitignored).
- Cross-platform: the CLI itself (`bin/aiflow` / `lib/*.sh`) requires Git-Bash on Windows —
  `bin/aiflow.ps1` delegates those to Bash. Everything a project *invokes on its own* (Claude
  Code hooks, `.aiflow/*` checks, `docker/run.*`) ships as a `.sh` + `.ps1` pair; `apply.sh`
  picks the interpreter per `dev.os` in `.aiflow/config.json` when it writes
  `.claude/settings.json`. Keep both twins in sync when editing one.
- Keep README.md and README.de.md **in sync** (same sections, both languages), and mirror
  user-visible changes into `docs/` + `CHANGELOG.md` + `docs/changelog.md` + `docs/llms-full.txt`.
- Conventional Commits referencing the bead id, e.g. `feat: … (aiflow-xyz)`.

## Agents & quality gates (self-hosted aiflow)

This repo runs on its own 0.1.1 agent roster: `.claude/agents/` + `.claude/commands/` mirror
`templates/.claude/` (keep them in sync when templates change — that is part of shipping a
template change). Audit helpers live in `.aiflow/` (`aiflow security-check | quality-check |
requirements-check | a11y-check | modernize-check | ralph` work here).

The full quality-gate definitions (§3a metrics/tests/logging, §3b REST, §3c database) live in
**`templates/CLAUDE.md`** and apply here *in spirit*, adapted to a Bash/templates codebase:
static analysis = `bash -n` + shellcheck + `jq empty`; tests = the render test above (init into a
temp dir and assert the generated project); no REST/database surface. The review gate
(`/review-ac`) and the recorded-decisions rule apply unchanged.
