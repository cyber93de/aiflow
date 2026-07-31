# Copilot instructions

Code only, no explanation unless asked. Bullets over paragraphs. Keep responses terse — every
token here and in every reply is billed on every agent step.

Read **`AGENTS.md`** in the repo root before making any change — it is the single, agent-agnostic
source of truth for this project (code style, quality gates, task workflow via Beads, git/branching
rules, definition of done). Sections marked "(Claude Code only)" describe automation you don't
have (subagents, slash-commands, hooks) — follow the same rules and steps manually instead.

Key points from `AGENTS.md` that apply directly to you:
- Work is tracked in Beads (`bd`) — check `bd ready`, claim with `bd update <id> --claim`, close
  with `bd close <id> --reason "…"`. Don't invent your own TODO list.
- Follow the branching model in `docs/branching.md` / `.aiflow/branching.json` — which branch
  type to use, and that `main` only ever receives `develop`/`hotfix/*`/`chore/*`.
- Never cut a release (`aiflow release --yes`, or merging into `main`) without the user's
  explicit go-ahead first.
- Google Style Guides for code, mandatory tests (unit + BDD e2e, >80% coverage), no code smells,
  logging, `.http` files for REST changes — see `AGENTS.md` §3/§3a/§3b/§3c for the full detail.
- Before adding new code/dependencies/abstractions, check `.claude/skills/ponytail/SKILL.md`'s
  decision ladder (needed? already in the codebase? stdlib? platform feature? installed dep? a
  one-liner? only then write it) if `ponytail.enabled` is set in `.aiflow/config.json` — see
  `AGENTS.md` §5/§9.

**Token discipline** (this file and `AGENTS.md` are always-on context, billed every step —
see the [Copilot token-optimization guide](https://github.com/olivomarco/github-copilot-token-optimization)):
- Keep this file and `AGENTS.md` to landmines only — non-obvious rules an agent would otherwise
  get wrong. Delete anything discoverable by reading the code; never let generated boilerplate
  accumulate here.
- Default to **Auto** model selection; once in a long thread, keep the model, reasoning effort,
  and tool/MCP set stable — changing any of them discards the cached prompt prefix and the
  cache-discount pricing that comes with it. Start a fresh chat with a short handoff summary
  instead of switching mid-thread.
- On a large repo, prefer scoping additional instructions with `applyTo:` paths over growing this
  file further.
