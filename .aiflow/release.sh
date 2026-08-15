#!/usr/bin/env bash
# Cut a release per the branching model: set the release version on main, tag it, then
# bump develop to the next dev version. Run on main after merging develop|hotfix/* -> main.
# Release kind is auto-detected from VERSION's suffix: "-SNAPSHOT" = minor release (develop),
# "-HOTFIX" = patch release (hotfix/*, started via 'aiflow hotfix'). Either way the suffix is
# stripped - main must never carry a -SNAPSHOT or -HOTFIX version. A hotfix release also merges
# the hotfix branch into develop so the fix isn't lost.
# Usage: aiflow release [--push] [--yes]
# Without --yes this prints a dry run only — releasing must always be a deliberate,
# user-approved action (agents: ask the user before adding --yes).
set -uo pipefail
MODEL=".aiflow/branching.json"
[ -f "$MODEL" ] || { echo "no branching model (.aiflow/branching.json). Configure via 'aiflow change-settings'." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

[ "$(jq -r '.release.auto // false' "$MODEL")" = true ] || { echo "auto-release is disabled in the branching model." >&2; exit 1; }
TAGS="$(jq -r 'if .release.tag.enabled == null then true else .release.tag.enabled end' "$MODEL")"
STRAT="$(jq -r '.release.versionStrategy // "semver"' "$MODEL")"

PUSH=0; YES=0
for a in "$@"; do
  case "$a" in
    --push) PUSH=1 ;;
    --yes|-y) YES=1 ;;
  esac
done

# guards
[ -n "$(git status --porcelain)" ] && { echo "working tree not clean - commit/stash first." >&2; exit 1; }
cur="$(git branch --show-current)"
[ "$cur" = main ] || { echo "checkout 'main' (after merging develop or hotfix/*) before releasing. On: $cur" >&2; exit 1; }

CURVER="$( [ -f VERSION ] && cat VERSION || echo "" )"
IS_HOTFIX=false
if [ "$STRAT" = semver ]; then
  case "$CURVER" in
    *-HOTFIX) IS_HOTFIX=true ;;
    *-*) IS_HOTFIX=false ;;                                    # -SNAPSHOT: develop release
    *) echo "VERSION '$CURVER' has no -SNAPSHOT/-HOTFIX suffix - nothing to release." >&2; exit 1 ;;
  esac
fi

HOTFIX_BRANCH=""
if [ "$IS_HOTFIX" = true ]; then
  # supports both local "git merge" ("Merge branch 'X'") and GitHub PR-merge subjects
  # ("Merge pull request #N from owner/X") - X may itself contain slashes (e.g. hotfix/foo).
  HOTFIX_BRANCH="$(git log -1 --merges --pretty=%s 2>/dev/null | sed -nE \
    -e "s/^Merge branch '([^']*)'.*/\1/p" \
    -e "s|^Merge pull request #[0-9]+ from [^/]+/(.*)|\1|p")"
  case "$HOTFIX_BRANCH" in hotfix/*) ;; *) HOTFIX_BRANCH="" ;; esac
fi

REL="$(bash .aiflow/version.sh release)"
NEXT="$(bash .aiflow/version.sh next-dev "$REL")"
KIND="release"; $IS_HOTFIX && KIND="hotfix release (patch)"

if [ "$YES" != 1 ]; then
  echo ">> DRY RUN - this would cut a $KIND:"
  echo "     $CURVER  ->  $REL   (on main)"
  echo "     develop bumped to: $NEXT"
  [ "$IS_HOTFIX" = true ] && [ -n "$HOTFIX_BRANCH" ] && echo "     hotfix commits from '$HOTFIX_BRANCH' will also be merged into develop"
  echo "   Releasing is a deliberate, user-approved action - re-run with --yes to actually release."
  echo "   (aiflow agents: ask the user for explicit confirmation before adding --yes.)"
  exit 0
fi

echo ">> releasing $REL on main"
echo "$REL" > VERSION
git add VERSION
AIFLOW_ALLOW_DIRECT_PUSH=1 AIFLOW_SKIP_VERIFY=1 git commit -q -m "chore(release): $REL"

if [ "$TAGS" = true ]; then
  if [ "$STRAT" = calver ]; then TAG="$REL"; else TAG="v$REL"; fi
  git tag -a "$TAG" -m "release $REL"
  echo "   tagged $TAG"
fi

# bump develop (and fold the hotfix fix back in, so it isn't lost there)
if git show-ref --verify --quiet refs/heads/develop; then
  git switch -q develop
  MERGE_REF=""
  if [ "$IS_HOTFIX" = true ] && [ -n "$HOTFIX_BRANCH" ]; then
    if git show-ref --verify --quiet "refs/heads/$HOTFIX_BRANCH"; then MERGE_REF="$HOTFIX_BRANCH"
    # local branch is often already gone by now (e.g. GitHub's "delete branch on merge"
    # after a PR merge) - fall back to the remote-tracking ref so the fix still lands here.
    elif git show-ref --verify --quiet "refs/remotes/origin/$HOTFIX_BRANCH"; then MERGE_REF="origin/$HOTFIX_BRANCH"
    fi
  fi
  if [ -n "$MERGE_REF" ]; then
    # VERSION always conflicts here (hotfix carries X.Y.Z-HOTFIX, develop carries its own
    # -SNAPSHOT) - that's expected and harmless, since VERSION gets overwritten with $NEXT
    # right after anyway. Any other conflict is a real one and aborts for manual resolution.
    ok=true
    git merge --no-ff --no-commit -q "$MERGE_REF" >/dev/null 2>&1 || ok=false
    if [ "$ok" = false ]; then
      conflicted="$(git diff --name-only --diff-filter=U)"
      if [ "$conflicted" = "VERSION" ]; then
        git checkout --ours VERSION >/dev/null 2>&1
        git add VERSION
        ok=true
      fi
    fi
    if [ "$ok" = true ]; then
      git commit -q -m "merge $HOTFIX_BRANCH into develop (hotfix from release $REL)"
      echo "   merged $HOTFIX_BRANCH into develop"
    else
      echo "   ! could not auto-merge $HOTFIX_BRANCH into develop (conflicts beyond VERSION) - resolve manually, then bump VERSION yourself." >&2
      git merge --abort
      git switch -q main
      exit 1
    fi
  fi
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
