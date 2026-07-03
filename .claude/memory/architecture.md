# aiflow architecture (self)

aiflow is a **config-driven project bootstrapper** for Claude Code. It has no runtime service — it
renders files into a target project and installs tools.

## The pipeline

```
aiflow init / change-settings
   → interactive Q&A (lib/init.sh, lib/settings.sh)
   → write .aiflow/config.json   (the single source of truth)
   → lib/apply.sh reads config and RENDERS everything:
        .mcp.json                (only enabled MCP servers + host MCP per remote type)
        git branching + hooks     (lib/branching.sh; only when vcs.system=git)
        beads↔host sync config    (bd config owner/repo from the git remote)
        .claude/memory/*          (project-aim, dev-environment, memory-policy)
        .aiflow/router-config.json (Ollama/cost providers, when router/ollama on)
        .aiflow/team-prefs.json   (shared preferences, when teamPrefs on)
        .aiflow/bd-close-sync.sh  (when sync.askOnClose on)
   → lib/install-deps.sh installs only enabled tools (user-space)
```

`apply.sh` is **idempotent**: re-running it (via `change-settings`) reproduces the same output from
the config. Nothing is stored globally; secrets live only in `.env` (gitignored).

## Entry points

- `bin/aiflow` — POSIX bash dispatcher (Linux/macOS/Git-Bash).
- `bin/aiflow.ps1` + `bin/aiflow.cmd` — Windows launcher (mirrors the bash subcommands).
- Both delegate to `lib/*.sh`. **Keep the two dispatchers in sync** when adding a subcommand.

## Design invariants (do not break)

- **Project-scoped only.** No global state; every token/setting lives in the project.
- **Token-based, never OAuth** for git hosts. Claude may use API key *or* OAuth token.
- **Config is the source of truth.** Don't hand-edit rendered files as the primary path — change
  `.aiflow/config.json` (or the Q&A) and re-apply.
- **Windows + POSIX parity.** Every user-facing subcommand exists in both `bin/aiflow` and
  `bin/aiflow.ps1`, and help text matches.
- **Two dispatchers, one behaviour.** README EN + DE and the docs site must stay consistent.

See [[codebase-map]] for the file-by-file map, [[config-schema]] for the config shape, and
[[design-decisions]] for why things are the way they are.
