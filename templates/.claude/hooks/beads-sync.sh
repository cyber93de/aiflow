#!/usr/bin/env bash
# SessionStart hook: pull the latest shared Beads issues so team members never start
# from a stale issue graph. Safe + non-blocking: only runs when a remote exists, never
# fails the session, never pushes (push is a deliberate act — see 'aiflow sync' / close-sync).
set -uo pipefail
have() { command -v "$1" >/dev/null 2>&1; }

# only in a beads project with a git origin (team setup)
[ -d .beads ] || exit 0
have bd || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

# respect an opt-out
if have jq && [ -f .aiflow/config.json ]; then
  [ "$(jq -r '.sync.pullOnStart // true' .aiflow/config.json 2>/dev/null)" = "false" ] && exit 0
fi

# fast, quiet, best-effort pull of the shared issue DB
if bd dolt pull >/dev/null 2>&1; then
  echo "beads: pulled latest shared issues (bd dolt pull)"
else
  echo "beads: could not pull shared issues — run 'aiflow sync' (resolve conflicts if any)"
fi
exit 0
