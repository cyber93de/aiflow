# Copilot instructions

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
