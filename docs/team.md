---
layout: default
title: Team collaboration
parent: Concepts
nav_order: 3
description: "Team collaboration in aiflow: a shared Dolt issue graph over your git remote, atomic Beads claiming, session-start auto-pull, and pull-before-push for many members."
---

# Team collaboration (multiple members)
{: .no_toc }

1. TOC
{:toc}

---

Beads issues live in a **shared Dolt database** that syncs via `refs/dolt/data` on your git remote —
one issue graph for the whole team, no extra server.

## The rules

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

## A typical team session

```bash
aiflow sync                       # pull latest code + issues (the hook does this too)
bd ready --unassigned             # see free work
bd update aiflow-abc --claim      # claim one atomically
# ... implement, verify, /review-ac ...
bd close aiflow-abc --reason "…"  # close with a note
aiflow close-sync aiflow-abc      # prompts: push? Dolt-sync? (pulls before pushing)
```

## Why Dolt?

Beads stores issues in [Dolt](https://github.com/dolthub/dolt), a versioned SQL database. That's what
makes safe multi-writer sync possible — branch/merge/diff semantics for your tasks, carried over the
git remote you already use. No separate issue server to run or pay for.
