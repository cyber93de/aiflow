#!/usr/bin/env bash
# Branch hotfix/<name> off main for an urgent production fix, and mark the in-progress
# version with a -HOTFIX suffix (mirrors how develop carries -SNAPSHOT). The suffix is
# stripped again by 'aiflow release' when the hotfix is merged back into main.
# Usage: aiflow hotfix <name>
set -uo pipefail
MODEL=".aiflow/branching.json"
[ -f "$MODEL" ] || { echo "no branching model (.aiflow/branching.json). Configure via 'aiflow change-settings'." >&2; exit 1; }
[ "$(jq -r '.model // "none"' "$MODEL" 2>/dev/null)" = gitflow ] || { echo "hotfix/* is only defined for the gitflow branching model." >&2; exit 1; }

NAME="${1:-}"
[ -n "$NAME" ] || { echo "usage: aiflow hotfix <name>" >&2; exit 1; }
BRANCH="hotfix/$NAME"

[ -n "$(git status --porcelain)" ] && { echo "working tree not clean - commit/stash first." >&2; exit 1; }
cur="$(git branch --show-current)"
[ "$cur" = main ] || { echo "checkout 'main' before starting a hotfix. On: $cur" >&2; exit 1; }
git show-ref --verify --quiet "refs/heads/$BRANCH" && { echo "branch '$BRANCH' already exists." >&2; exit 1; }

NEWVER="$(bash .aiflow/version.sh start-hotfix)" || exit 1

git switch -q -c "$BRANCH"
echo "$NEWVER" > VERSION
git add VERSION
AIFLOW_ALLOW_DIRECT_PUSH=1 AIFLOW_SKIP_VERIFY=1 git commit -q -m "chore: start hotfix $NEWVER"
echo ">> branched $BRANCH from main, VERSION -> $NEWVER"
echo "   fix the issue, then merge $BRANCH -> main and run 'aiflow release --yes' to cut the patch release."
