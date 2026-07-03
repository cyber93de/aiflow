#!/usr/bin/env bash
# Apply server-side branch protection on the host so the PR-only / merge rules are actually
# enforced for everyone (the pre-push hook only protects the local user). GitHub via gh.
# Usage: aiflow protect
set -uo pipefail
MODEL=".aiflow/branching.json"; CFG=".aiflow/config.json"
[ -f "$MODEL" ] || { echo "no branching model. Run 'aiflow change-settings' first." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

VCS="$( [ -f "$CFG" ] && jq -r '.vcs // "github"' "$CFG" || echo github )"
PRONLY="$(jq -r '.pullRequests.required // false' "$MODEL")"
BRANCHES="$(jq -r '(.pullRequests.protectedBranches // ["main","develop"])[]' "$MODEL")"

if [ "$VCS" != github ]; then
  echo "Server-side protection for '$VCS' is not automated. Configure it in your host:"
  echo "  - require PRs to ${BRANCHES//$'\n'/, }, block direct pushes, require CI to pass."
  exit 0
fi
command -v gh >/dev/null 2>&1 || { echo "gh (GitHub CLI) not found. Install it, or set protection in the GitHub UI." >&2; exit 1; }
repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || { echo "not a GitHub repo / not authed (gh auth login)." >&2; exit 1; }

for b in $BRANCHES; do
  echo ">> protecting $repo:$b"
  gh api -X PUT "repos/$repo/branches/$b/protection" \
    -H "Accept: application/vnd.github+json" \
    -f "required_pull_request_reviews[required_approving_review_count]=1" \
    -F "required_status_checks[strict]=true" \
    -f "required_status_checks[contexts][]=ci" \
    -F "enforce_admins=true" \
    -F "restrictions=null" >/dev/null 2>&1 \
    && echo "   PR required + CI required on $b" \
    || echo "   ! failed for $b (need admin + repo:admin token scope)"
done
[ "$PRONLY" = true ] || echo "note: PR-only is OFF in the model; protection applied anyway for safety."
echo ">> done. Verify in repo Settings → Branches."
