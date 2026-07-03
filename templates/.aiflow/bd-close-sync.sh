#!/usr/bin/env bash
# aiflow bd-close-sync - run AFTER a Beads issue is closed locally.
# Honours the rule: on every local issue close, ASK whether to push and whether to
# dolt-sync the configured remote (github/gitlab/custom). Never pushes silently.
#
# Usage:  .aiflow/bd-close-sync.sh <issue-id>
# Agents: the CLAUDE.md §Beads-sync rule tells the agent to call this after `bd close`.
set -uo pipefail

ISSUE="${1:-}"
CFG=".aiflow/config.json"
have() { command -v "$1" >/dev/null 2>&1; }
j() { have jq && [ -f "$CFG" ] && jq -r "$1 // empty" "$CFG" 2>/dev/null; }

[ "$(j '.sync.askOnClose')" = "true" ] || { echo "sync-on-close disabled in $CFG"; exit 0; }
REMOTE_TYPE="$(j '.remote.type')"; [ -z "$REMOTE_TYPE" ] && REMOTE_TYPE=github
[ "$REMOTE_TYPE" = none ] && { echo "no remote configured; nothing to sync"; exit 0; }

TTY=/dev/tty; [ -r /dev/tty ] || TTY=/dev/stdin
ask_yn() { local p="$1" a; printf "  %s (y/n) [y]: " "$p" >&2; read -r a <"$TTY" || a=""; case "${a:-y}" in [Yy]*) return 0;; *) return 1;; esac; }

echo "Beads issue ${ISSUE:-<closed>} closed locally."

# 1) push the git branch (issue JSONL + code)
if [ -d .git ] && ask_yn "Push the current branch to '$REMOTE_TYPE'?"; then
  git pull --rebase 2>/dev/null || true   # integrate teammates' commits first
  git push || echo "  ! git push failed (resolve, then push manually)"
fi

# 2) dolt-sync the Beads DB with the remote (issues live in Dolt; refs/dolt/data on origin).
#    PULL BEFORE PUSH so we merge teammates' issue changes instead of clobbering them.
if have bd && ask_yn "Dolt-sync Beads issues with the remote now?"; then
  bd dolt pull 2>/dev/null || echo "  ! bd dolt pull failed — resolve conflicts, then push"
  bd dolt push 2>/dev/null \
    || echo "  ! bd dolt push failed — run 'bd dolt pull' (merge) then 'bd dolt push' manually"
fi

echo "done."
