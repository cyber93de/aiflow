#!/usr/bin/env bash
# aiflow update - self-update the aiflow installation (AIFLOW_HOME) to the latest release.
# Only touches the aiflow install itself. For a single project's copied templates, see
# `aiflow project-update`.
set -uo pipefail

AIFLOW_HOME="${AIFLOW_HOME:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OLD_VER="$(cat "$AIFLOW_HOME/VERSION" 2>/dev/null || echo 0.0.0)"

if [ ! -d "$AIFLOW_HOME/.git" ]; then
  echo "aiflow install at $AIFLOW_HOME is not a git checkout - can't self-update automatically." >&2
  echo "Re-clone or re-download the latest release instead." >&2
  exit 1
fi

if [ -n "$(git -C "$AIFLOW_HOME" status --porcelain 2>/dev/null)" ]; then
  echo "aiflow install has local changes - refusing to update. Commit/stash in $AIFLOW_HOME first." >&2
  exit 1
fi

echo ">> updating aiflow ($AIFLOW_HOME)..."
git -C "$AIFLOW_HOME" fetch --tags origin >/dev/null 2>&1 || { echo "fetch failed" >&2; exit 1; }
git -C "$AIFLOW_HOME" pull --ff-only origin main || { echo "update failed (not fast-forward?) - resolve manually in $AIFLOW_HOME" >&2; exit 1; }

NEW_VER="$(cat "$AIFLOW_HOME/VERSION" 2>/dev/null || echo 0.0.0)"
if [ "$OLD_VER" = "$NEW_VER" ]; then
  echo ">> already on latest (aiflow $NEW_VER)."
else
  echo ">> aiflow updated: $OLD_VER -> $NEW_VER"
  echo "   Run 'aiflow project-update' in each project to pull the new templates in."
fi
