#!/usr/bin/env bash
# aiflow apply - render project files from .aiflow/config.json (idempotent).
# Called by `aiflow init` and `aiflow change-settings`. Never stores anything global.
set -uo pipefail

CFG=".aiflow/config.json"
[ -f "$CFG" ] || { echo "no $CFG - run 'aiflow init' first" >&2; exit 1; }

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (install jq). It reads .aiflow/config.json." >&2; exit 1
fi
j() { jq -r "$1 // empty" "$CFG" 2>/dev/null; }

PROJ_DIR="$(pwd)"
CAVEMAN_ON="$(j '.caveman.enabled')"; CAVEMAN_MODE="$(j '.caveman.mode')"
RTK_ON="$(j '.rtk.enabled')"
ROUTER_ON="$(j '.router.enabled')"
GRAPHIFY_ON="$(j '.graphify.enabled')"
TASKMASTER_ON="$(j '.taskmaster.enabled')"
FS_ON="$(j '.mcp.filesystem')"
CTX7_ON="$(j '.mcp.context7')"
COCO_ON="$(j '.mcp.cocoindex')"
MEMORY_ON="$(j '.memory.enabled')"
MEMORY_GRAPH="$(j '.memory.graph')"; MEMORY_INT="$(j '.memory.intensity')"; [ -z "$MEMORY_INT" ] && MEMORY_INT=normal
CLAUDE_AUTH="$(j '.claude.auth')"; [ -z "$CLAUDE_AUTH" ] && CLAUDE_AUTH=apikey
# local version control (git/svn/none)
VCS_SYS="$(j '.vcs.system')"; [ -z "$VCS_SYS" ] && VCS_SYS=git
# remote host: new schema (.remote.*) with fallback to legacy string .vcs
REMOTE_TYPE="$(j '.remote.type')"
if [ -z "$REMOTE_TYPE" ]; then REMOTE_TYPE="$(jq -r 'if (.vcs|type)=="string" then .vcs else empty end' "$CFG" 2>/dev/null)"; fi
[ -z "$REMOTE_TYPE" ] && REMOTE_TYPE=github
REMOTE_URL="$(j '.remote.baseUrl')"
REMOTE_API="$(j '.remote.api')"
REMOTE_TOKENENV="$(j '.remote.tokenEnv')"; [ -z "$REMOTE_TOKENENV" ] && REMOTE_TOKENENV=GITHUB_TOKEN
REMOTE_MCP="$(j '.remote.mcp')"
# derive the git-host MCP from the remote type when not explicitly set
if [ -z "$REMOTE_MCP" ]; then
  case "$REMOTE_TYPE" in
    github|github-enterprise) REMOTE_MCP=github ;;
    gitlab|gitlab-self)       REMOTE_MCP=gitlab ;;
    bitbucket)                REMOTE_MCP=bitbucket ;;
    forgejo)                  REMOTE_MCP=forgejo ;;
    gitea)                    REMOTE_MCP=gitea ;;
    *)                        REMOTE_MCP=none ;;
  esac
fi
SYNC_ONCLOSE="$(j '.sync.askOnClose')"
OLLAMA_ON="$(j '.ollama.enabled')"; OLLAMA_URL="$(j '.ollama.url')"; [ -z "$OLLAMA_URL" ] && OLLAMA_URL="http://localhost:11434"
TEAM_ON="$(j '.teamPrefs.enabled')"; TEAM_STYLE="$(j '.teamPrefs.codeStyle')"
# back-compat: keep VCS as the remote host name for existing logic below
VCS="$REMOTE_TYPE"
AIM="$(j '.project.aim')"; ARCH="$(j '.project.architecture')"
OS="$(j '.dev.os')"; IDE="$(j '.dev.ide')"

# ---------- .mcp.json (only enabled servers) ----------
tmp="$(mktemp)"; echo '{"mcpServers":{}}' > "$tmp"
add_mcp() { # name  json
  jq --argjson v "$2" ".mcpServers.\"$1\" = \$v" "$tmp" > "$tmp.n" && mv "$tmp.n" "$tmp"
}
# ---- git-host MCP (chosen by remote.mcp; token from remote.tokenEnv) ----
# Each host has its own MCP server. Self-hosted variants get their base URL wired in
# (GITHUB_HOST / GITLAB_API_URL / GITEA_URL) so enterprise/self-managed installs work.
ref() { printf '${%s}' "$1"; }   # emit a literal ${VAR} for .env expansion
host_only() { printf '%s' "$1" | sed -E 's#^https?://##; s#/.*$##'; }
case "$REMOTE_MCP" in
  github)
    if printf '%s' "$REMOTE_URL" | grep -qiE '(^$|github\.com)'; then
      add_mcp github "$(jq -n --arg t "$(ref "$REMOTE_TOKENENV")" \
        '{command:"docker",args:["run","-i","--rm","-e","GITHUB_PERSONAL_ACCESS_TOKEN","ghcr.io/github/github-mcp-server"],env:{GITHUB_PERSONAL_ACCESS_TOKEN:$t}}')"
    else  # GitHub Enterprise: pass the host
      add_mcp github "$(jq -n --arg t "$(ref "$REMOTE_TOKENENV")" --arg h "$(host_only "$REMOTE_URL")" \
        '{command:"docker",args:["run","-i","--rm","-e","GITHUB_PERSONAL_ACCESS_TOKEN","-e","GITHUB_HOST","ghcr.io/github/github-mcp-server"],env:{GITHUB_PERSONAL_ACCESS_TOKEN:$t,GITHUB_HOST:$h}}')"
    fi ;;
  gitlab)
    add_mcp gitlab "$(jq -n --arg t "$(ref "$REMOTE_TOKENENV")" --arg u "${REMOTE_URL:-https://gitlab.com}" \
      '{command:"npx",args:["-y","@modelcontextprotocol/server-gitlab"],env:{GITLAB_PERSONAL_ACCESS_TOKEN:$t,GITLAB_API_URL:($u+"/api/v4")}}')" ;;
  bitbucket)
    add_mcp bitbucket "$(jq -n --arg t "$(ref "$REMOTE_TOKENENV")" --arg u "$REMOTE_URL" \
      '{command:"npx",args:["-y","@aashari/mcp-server-atlassian-bitbucket"],env:{ATLASSIAN_BITBUCKET_ACCESS_TOKEN:$t,BITBUCKET_BASE_URL:$u}}')" ;;
  forgejo|gitea)
    add_mcp "$REMOTE_MCP" "$(jq -n --arg t "$(ref "$REMOTE_TOKENENV")" --arg u "$REMOTE_URL" \
      '{command:"npx",args:["-y","gitea-mcp-server"],env:{GITEA_URL:$u,GITEA_ACCESS_TOKEN:$t}}')" ;;
  none|"") : ;;   # custom/generic host with no known MCP — use CLI/REST instead
esac
# Filesystem
[ "$FS_ON" = "true" ] && add_mcp filesystem "$(jq -n --arg d "$PROJ_DIR" '{command:"npx",args:["-y","@modelcontextprotocol/server-filesystem",$d]}')"
# graphify (structural code graph: imports / call-graph / relationships)
[ "$GRAPHIFY_ON" = "true" ] && add_mcp graphify '{"command":"python","args":["-m","graphify.serve","graphify-out/graph.json"]}'
# cocoindex-code (semantic RAG code search: AST chunks + local embeddings, no key, incremental)
[ "$COCO_ON" = "true" ] && add_mcp cocoindex-code '{"command":"ccc","args":["mcp"]}'
# task-master (task decomposition; claude-code provider needs no key)
[ "$TASKMASTER_ON" = "true" ] && add_mcp task-master '{"command":"npx","args":["-y","task-master-ai"],"env":{"MODEL":"claude-code/sonnet"}}'
# context7 (live library docs). CONTEXT7_API_KEY optional (higher rate limits); works keyless.
[ "$CTX7_ON" = "true" ] && add_mcp context7 '{"command":"npx","args":["-y","@upstash/context7-mcp"],"env":{"CONTEXT7_API_KEY":"${CONTEXT7_API_KEY}"}}'
jq '. + {"$comment":"Generated by aiflow from .aiflow/config.json. Edit via: aiflow change-settings. Tokens come from .env (gitignored)."}' "$tmp" > .mcp.json
rm -f "$tmp"
echo "  .mcp.json rendered (host-mcp=$REMOTE_MCP filesystem=$FS_ON context7=$CTX7_ON graphify=$GRAPHIFY_ON cocoindex=$COCO_ON task-master=$TASKMASTER_ON)"

# ---------- git branching governance + hooks (only when local VCS is git) ----------
if [ "$VCS_SYS" = "git" ]; then
  bash "$(dirname "${BASH_SOURCE[0]}")/branching.sh" || true

  # git hooks (enforce conventional commits + lint/test).
  # Beads also installs git hooks (.beads/hooks) for JSONL sync. A repo can have only one
  # core.hooksPath, so when Beads is present we merge our enforcement INTO .beads/hooks (the
  # superset = beads sync + our checks) and point there. Otherwise we use .githooks.
  if [ -d .git ]; then
    if [ -d .beads/hooks ]; then
      cp -f .githooks/pre-commit .githooks/commit-msg .githooks/pre-push .beads/hooks/ 2>/dev/null || true
      chmod +x .beads/hooks/* 2>/dev/null || true
      git config core.hooksPath .beads/hooks
      echo "  git hooks enforced (core.hooksPath=.beads/hooks; merged with Beads sync)"
    else
      chmod +x .githooks/* 2>/dev/null || true
      git config core.hooksPath .githooks
      echo "  git hooks enforced (core.hooksPath=.githooks)"
    fi
  fi
else
  echo "  git branching/hooks skipped (vcs.system=$VCS_SYS)"
fi

# ---------- Beads <-> remote issue sync config ----------
# Beads has its OWN host integration (`bd github` / `bd gitlab`), separate from the MCP server.
# Without owner/repo set, host sync never runs and issues stay local-only.
# We derive owner/repo from the git remote (non-secret; token stays in .env).
if { [ "$REMOTE_TYPE" = "github" ] || [ "$REMOTE_TYPE" = "gitlab" ]; } && [ -d .beads ] && command -v bd >/dev/null 2>&1; then
  GIT_REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
  HOSTRE='github\.com'; [ "$REMOTE_TYPE" = gitlab ] && HOSTRE='gitlab\.com'
  # supports git@host:owner/repo.git and https://host/owner/repo(.git)
  SLUG="$(printf '%s' "$GIT_REMOTE_URL" | sed -E "s#^.*${HOSTRE}[:/]+##; s#\.git\$##")"
  R_OWNER="${SLUG%%/*}"; R_REPO="${SLUG#*/}"
  if [ -n "$R_OWNER" ] && [ -n "$R_REPO" ] && [ "$R_OWNER" != "$SLUG" ]; then
    bd config set "$REMOTE_TYPE.owner" "$R_OWNER" >/dev/null 2>&1 || true
    bd config set "$REMOTE_TYPE.repo"  "$R_REPO"  >/dev/null 2>&1 || true
    echo "  beads<->$REMOTE_TYPE sync configured ($R_OWNER/$R_REPO; run 'bd $REMOTE_TYPE sync' or push to sync)"
  else
    echo "  ! beads<->$REMOTE_TYPE: no '$REMOTE_TYPE' origin remote yet — add one, then re-run 'aiflow change-settings'"
  fi
elif [ "$REMOTE_TYPE" = "custom" ]; then
  echo "  beads<->remote: custom host ($REMOTE_URL, api=$REMOTE_API) — Dolt sync via 'refs/dolt/data' on 'origin'; token in \$$REMOTE_TOKENENV"
fi

# ---------- rtk (set by aiflow, project-scoped; never global) ----------
if [ "$RTK_ON" = "true" ]; then
  if command -v rtk >/dev/null 2>&1; then
    rtk init >/dev/null 2>&1 && echo "  rtk output-filtering enabled (project hook)" || echo "  ! rtk init failed"
  else
    echo "  ! rtk enabled in config but 'rtk' not installed - see README"
  fi
fi

# ---------- memory (project aim + dev setup) ----------
if [ "$MEMORY_ON" = "true" ] || [ -n "$AIM" ]; then
  mkdir -p .claude/memory
  cat > .claude/memory/project-aim.md <<EOF
# Project aim
**Goal:** ${AIM:-<describe what this project should achieve>}

**Target architecture:** ${ARCH:-<describe the intended architecture>}

(Keep this current. Agents read it every session. Detailed view: docs/architecture/.)
EOF
  cat > .claude/memory/dev-environment.md <<EOF
# Dev environment
- **OS:** ${OS:-unknown}
- **IDE:** ${IDE:-unknown}
- **Version control:** ${VCS_SYS}
- **Remote host:** ${REMOTE_TYPE}${REMOTE_URL:+ ($REMOTE_URL)}
- **Claude auth:** ${CLAUDE_AUTH}

Use this to pick correct shell/CLI commands and IDE-specific steps without re-asking.
EOF
  # ---- graph-memory learning policy (intensity-driven) ----
  case "$MEMORY_INT" in
    aggressive) MEM_RULE="Learn **aggressively**: after every non-trivial task, save durable facts (decisions, gotchas, env quirks, API shapes) to memory and refresh the graphify graph. Prefer the graph over re-reading files." ;;
    light)      MEM_RULE="Learn **sparingly**: only save high-value, long-lived facts. Refresh the graph on request." ;;
    off)        MEM_RULE="Graph-memory learning is **off**; rely on Beads + this file only." ;;
    *)          MEM_RULE="Learn at a **normal** pace: save durable non-obvious facts; refresh the graph when structure changes." ;;
  esac
  cat > .claude/memory/memory-policy.md <<EOF
# Memory & context policy
- **Learning intensity:** ${MEMORY_INT}
- **Graph memory (graphify):** $([ "$GRAPHIFY_ON" = true ] && echo enabled || echo disabled)
- **RAG code search (cocoindex-code):** $([ "$COCO_ON" = true ] && echo enabled || echo disabled)
- **External docs (context7):** $([ "$CTX7_ON" = true ] && echo enabled || echo disabled)

$MEM_RULE

## Context stack — which source to hit, in order (fewest tokens first)
| Need | Use | Why |
|------|-----|-----|
| Current task, deps, decisions, session state | **Beads** (\`bd\`) | structured work memory, survives compaction |
| Durable project facts / gotchas / env quirks | **memory files** (this dir) | prose facts not in code/git |
| Where a symbol is defined, who calls it, dependency direction | **graphify** MCP | exact structural graph, no re-scan |
| "Find code about concept X" / semantic / fuzzy | **cocoindex-code** (\`ccc search\` / MCP) | AST-aware RAG, ~70% fewer tokens than reading files |
| External library / framework API docs | **context7** MCP | live upstream docs, avoids hallucination |
| Anything still unresolved | read the file(s) | only after graph + RAG have narrowed the target |

**Rule:** never scan whole files first. Route the question through graphify (structure) and
cocoindex-code (semantics) to locate the few relevant chunks, then open only those.
Refresh both indexes with \`aiflow index\` after significant code changes.
EOF
  cat > .claude/MEMORY.md <<EOF
# Project Memory Index
- [Project aim](memory/project-aim.md) — goal + target architecture
- [Dev environment](memory/dev-environment.md) — OS, IDE, VCS, remote, Claude auth
- [Memory policy](memory/memory-policy.md) — learning intensity + graph memory
EOF
  # flip CLAUDE.md memory toggle on
  grep -q 'AIFLOW_MEMORY: off' CLAUDE.md 2>/dev/null && sed -i 's/AIFLOW_MEMORY: off/AIFLOW_MEMORY: on/' CLAUDE.md
  echo "  memory written (aim + dev environment + policy: intensity=$MEMORY_INT graph=$MEMORY_GRAPH)"
fi

# ---------- claude-code-router config (wire Ollama + cost providers so they're used) ----------
if [ "$ROUTER_ON" = "true" ] || [ "$OLLAMA_ON" = "true" ]; then
  mkdir -p .aiflow
  OLLAMA_MODELS_JSON="$(j '.ollama.models' )"; [ -z "$OLLAMA_MODELS_JSON" ] && OLLAMA_MODELS_JSON='[]'
  # Provider list: Ollama (local, keyless) when enabled. Default easy/background route -> first ollama model.
  ROUTER_TMP="$(mktemp)"
  jq -n --arg url "${OLLAMA_URL%/}/v1" --argjson models "$OLLAMA_MODELS_JSON" --argjson ollama "${OLLAMA_ON:-false}" '
    {
      "Providers": (
        if $ollama and ($models|length>0) then
          [ { "name":"ollama", "api_base_url":$url, "api_key":"ollama", "models":$models } ]
        else [] end
      ),
      "Router": (
        if $ollama and ($models|length>0)
        then { "background": ("ollama," + $models[0]), "default": "" }
        else {} end
      ),
      "$comment": "Generated by aiflow. Fill real cost-provider keys in ~/.claude-code-router/config.json (never commit). Ollama needs no key."
    }' > "$ROUTER_TMP" && mv "$ROUTER_TMP" .aiflow/router-config.json
  echo "  router-config.json written (ollama=$OLLAMA_ON models=$(printf '%s' "$OLLAMA_MODELS_JSON" | jq -r 'length'))"
fi

# ---------- team/user-wide shared preferences (versioned) ----------
if [ "$TEAM_ON" = "true" ]; then
  [ -f .aiflow/team-prefs.json ] || cat > .aiflow/team-prefs.json <<EOF
{
  "\$comment": "Shared, versioned team/user preferences. Committed to the repo so the whole team inherits them. Personal overrides stay local (not here).",
  "codeStyle": "${TEAM_STYLE:-google}",
  "language": "en",
  "conventions": {
    "commits": "conventional-commits",
    "reviewGate": "/review-ac"
  }
}
EOF
  TP_STYLE="$(jq -r '.codeStyle // "google"' .aiflow/team-prefs.json 2>/dev/null)"
  echo "  team-prefs.json present (codeStyle=$TP_STYLE) — shared across users/teams"
fi

# ---------- OS-aware Claude Code hook commands (bash on mac/linux, PowerShell on Windows) ----------
if [ -f .claude/settings.json ]; then
  case "$OS" in
    windows)
      HOOK_FMT='powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/format.ps1'
      HOOK_CAVE='powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/caveman.ps1'
      HOOK_BEADS='powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/beads-sync.ps1'
      ;;
    *)
      HOOK_FMT='bash .claude/hooks/format.sh'
      HOOK_CAVE='bash .claude/hooks/caveman.sh'
      HOOK_BEADS='bash .claude/hooks/beads-sync.sh'
      ;;
  esac
  jq --arg fmt "$HOOK_FMT" --arg cave "$HOOK_CAVE" --arg beads "$HOOK_BEADS" '
    .hooks.SessionStart = [ { hooks: [ {type:"command", command:$cave}, {type:"command", command:$beads} ] } ] |
    .hooks.PostToolUse  = [ { matcher:"Edit|Write", hooks: [ {type:"command", command:$fmt} ] } ]
  ' .claude/settings.json > .claude/settings.json.tmp && mv .claude/settings.json.tmp .claude/settings.json
  echo "  settings.json hooks wired for OS=${OS:-unknown} ($([ "$OS" = windows ] && echo powershell || echo bash))"
fi

# ---------- README: "Built with aiflow" badge (idempotent; never touches the rest of the file) ----------
BADGE='[![Built with aiflow](https://img.shields.io/badge/built%20with-aiflow-6b46c1)](https://github.com/cyber93de/aiflow)'
inject_badge() {
  local rf="$1"
  [ -f "$rf" ] || return 0
  grep -q "built%20with-aiflow" "$rf" && return 0
  if head -n1 "$rf" | grep -q '^# '; then
    { head -n1 "$rf"; echo ""; echo "$BADGE"; tail -n +2 "$rf"; } > "$rf.tmp" && mv "$rf.tmp" "$rf"
  else
    { echo "$BADGE"; echo ""; cat "$rf"; } > "$rf.tmp" && mv "$rf.tmp" "$rf"
  fi
  echo "  $rf: added 'Built with aiflow' badge"
}
inject_badge README.md
inject_badge README.de.md

# ---------- Beads close -> push + dolt sync rule ----------
# Wire a helper the agent/user runs to honour the 'ask on close' rule. Non-automatic: it prompts.
if [ "$SYNC_ONCLOSE" = "true" ]; then
  mkdir -p .aiflow
  cp -f "$(dirname "${BASH_SOURCE[0]}")/../templates/.aiflow/bd-close-sync.sh" .aiflow/bd-close-sync.sh 2>/dev/null || true
  chmod +x .aiflow/bd-close-sync.sh 2>/dev/null || true
  echo "  bd-close-sync enabled (on issue close: prompt to push + dolt-sync $REMOTE_TYPE)"
fi

echo "apply done."
