#!/usr/bin/env bash
# Cut a release per the branching model: set the release version on main, tag it, then
# bump develop to the next dev version. Run on main after merging develop -> main.
# Usage: aiflow release [--push]
set -uo pipefail
MODEL=".aiflow/branching.json"
[ -f "$MODEL" ] || { echo "no branching model (.aiflow/branching.json). Configure via 'aiflow change-settings'." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

[ "$(jq -r '.release.auto // false' "$MODEL")" = true ] || { echo "auto-release is disabled in the branching model." >&2; exit 1; }
TAGS="$(jq -r '.release.tag.enabled // true' "$MODEL")"
STRAT="$(jq -r '.release.versionStrategy // "semver"' "$MODEL")"
PUSH=0; [ "${1:-}" = "--push" ] && PUSH=1

# guards
[ -n "$(git status --porcelain)" ] && { echo "working tree not clean - commit/stash first." >&2; exit 1; }
cur="$(git branch --show-current)"
[ "$cur" = main ] || { echo "checkout 'main' (after merging develop) before releasing. On: $cur" >&2; exit 1; }

REL="$(bash .aiflow/version.sh release)"
echo ">> releasing $REL on main"
echo "$REL" > VERSION
git add VERSION
AIFLOW_ALLOW_DIRECT_PUSH=1 AIFLOW_SKIP_VERIFY=1 git commit -q -m "chore(release): $REL"

if [ "$TAGS" = true ]; then
  if [ "$STRAT" = calver ]; then TAG="$REL"; else TAG="v$REL"; fi
  git tag -a "$TAG" -m "release $REL"
  echo "   tagged $TAG"
fi

# bump develop
NEXT="$(bash .aiflow/version.sh next-dev "$REL")"
if git show-ref --verify --quiet refs/heads/develop; then
  git switch -q develop
  echo "$NEXT" > VERSION
  git add VERSION
  AIFLOW_ALLOW_DIRECT_PUSH=1 AIFLOW_SKIP_VERIFY=1 git commit -q -m "chore: start $NEXT"
  git switch -q main
  echo "   develop bumped to $NEXT"
fi

if [ "$PUSH" = 1 ]; then
  AIFLOW_ALLOW_DIRECT_PUSH=1 git push --follow-tags origin main develop 2>/dev/null || \
    echo "   ! push failed (protected branches usually need PR/CI; push tags/branches as your flow allows)"
fi
echo ">> release done: main=$REL  develop=$NEXT  (push with --push, or via your PR/CI flow)"
