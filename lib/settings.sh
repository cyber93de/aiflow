#!/usr/bin/env bash
# aiflow change-settings - re-adjust .aiflow/config.json, then re-apply. Project-scoped.
set -uo pipefail
AIFLOW_HOME="${AIFLOW_HOME:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CFG=".aiflow/config.json"
[ -f "$CFG" ] || { echo "no $CFG here - run 'aiflow init' first" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }
j() { jq -r "$1 // empty" "$CFG"; }

NO_TOKENSAVE=0
for a in "$@"; do
  case "$a" in
    --no-token-saving) NO_TOKENSAVE=1;;
    *) echo "unknown flag: $a" >&2; exit 2;;
  esac
done

TTY=/dev/tty; [ -r /dev/tty ] || TTY=/dev/stdin
ask()    { local p="$1" d="$2" a; printf "  %s [%s]: " "$p" "$d" >&2; read -r a <"$TTY" || a=""; echo "${a:-$d}"; }
ask_yn() { local p="$1" d="$2" a; printf "  %s (y/n) [%s]: " "$p" "$d" >&2; read -r a <"$TTY" || a=""; a="${a:-$d}"; case "$a" in [Yy]*) echo true;; [Nn]*) echo false;; true|false) echo "$a";; *) echo "$d";; esac; }
dyn() { [ "$1" = true ] && echo y || echo n; }

echo "Change settings (Enter keeps current):"
if [ "$NO_TOKENSAVE" = 1 ]; then
  echo "  --no-token-saving: caveman + rtk switched OFF (full, unfiltered output)."
  CAVE_ON=false; CAVE_MODE="$(j .caveman.mode)"; [ -z "$CAVE_MODE" ] && CAVE_MODE=full
  RTK_ON=false
else
  CAVE_ON="$(ask_yn 'caveman (terse output)?' "$(dyn "$(j .caveman.enabled)")")"
  CAVE_MODE="$(ask 'caveman mode (full/lite/ultra)' "$(j .caveman.mode)")"
  RTK_ON="$(ask_yn 'rtk CLI-output filtering?' "$(dyn "$(j .rtk.enabled)")")"
fi
GRAPHIFY_ON="$(ask_yn 'graphify structural code graph?' "$(dyn "$(j .graphify.enabled)")")"
COCO_ON="$(ask_yn 'cocoindex-code semantic RAG search?' "$(dyn "$(j .mcp.cocoindex)")")"
TM_ON="$(ask_yn 'claude-task-master?' "$(dyn "$(j .taskmaster.enabled)")")"
FS_ON="$(ask_yn 'filesystem MCP?' "$(dyn "$(j .mcp.filesystem)")")"
CTX7_ON="$(ask_yn 'context7 MCP (live library docs)?' "$(dyn "$(j .mcp.context7)")")"

# memory + graph intensity
MEM_ON="$(ask_yn 'persistent memory?' "$(dyn "$(j .memory.enabled)")")"
MEM_GRAPH="$(j .memory.graph)"; [ -z "$MEM_GRAPH" ] && MEM_GRAPH=false
MEM_INT="$(j .memory.intensity)"; [ -z "$MEM_INT" ] && MEM_INT=normal
if [ "$MEM_ON" = true ]; then
  MEM_GRAPH="$(ask_yn 'graph memory (learn codebase into knowledge graph)?' "$(dyn "$MEM_GRAPH")")"
  MEM_INT="$(ask 'memory learning intensity (aggressive/normal/light)' "$MEM_INT")"
fi

# Claude auth (token-based)
CLAUDE_AUTH="$(ask 'Claude auth (apikey/oauth)' "$(j .claude.auth)")"; [ -z "$CLAUDE_AUTH" ] && CLAUDE_AUTH=apikey

# local version control
VCS_SYS="$(ask 'Local version control (git/svn/none)' "$(j .vcs.system)")"; [ -z "$VCS_SYS" ] && VCS_SYS=git

# remote host (token-based only)
echo "  github|github-enterprise|gitlab|gitlab-self|bitbucket|forgejo|gitea|custom|none"
REMOTE_TYPE="$(ask 'Remote type' "$(j .remote.type)")"; [ -z "$REMOTE_TYPE" ] && REMOTE_TYPE=github
REMOTE_URL="$(j .remote.baseUrl)"; REMOTE_API="$(j .remote.api)"; REMOTE_TOKENENV="$(j .remote.tokenEnv)"; REMOTE_MCP="$(j .remote.mcp)"
case "$REMOTE_TYPE" in
  github)             REMOTE_URL="https://github.com"; REMOTE_API="github-api"; REMOTE_TOKENENV="GITHUB_TOKEN"; REMOTE_MCP="github" ;;
  github-enterprise)  REMOTE_URL="$(ask 'GHE base URL' "$REMOTE_URL")"; REMOTE_API="github-api"; REMOTE_TOKENENV="GITHUB_TOKEN"; REMOTE_MCP="github" ;;
  gitlab)             REMOTE_URL="https://gitlab.com"; REMOTE_API="gitlab-api"; REMOTE_TOKENENV="GITLAB_TOKEN"; REMOTE_MCP="gitlab" ;;
  gitlab-self)        REMOTE_URL="$(ask 'GitLab base URL' "$REMOTE_URL")"; REMOTE_API="gitlab-api"; REMOTE_TOKENENV="GITLAB_TOKEN"; REMOTE_MCP="gitlab" ;;
  bitbucket)          REMOTE_URL="$(ask 'Bitbucket base URL' "${REMOTE_URL:-https://api.bitbucket.org/2.0}")"; REMOTE_API="bitbucket"; REMOTE_TOKENENV="BITBUCKET_TOKEN"; REMOTE_MCP="bitbucket" ;;
  forgejo)            REMOTE_URL="$(ask 'Forgejo base URL' "$REMOTE_URL")"; REMOTE_API="gitea-api"; REMOTE_TOKENENV="${REMOTE_TOKENENV:-GIT_REMOTE_TOKEN}"; REMOTE_MCP="forgejo" ;;
  gitea)              REMOTE_URL="$(ask 'Gitea base URL' "$REMOTE_URL")"; REMOTE_API="gitea-api"; REMOTE_TOKENENV="${REMOTE_TOKENENV:-GIT_REMOTE_TOKEN}"; REMOTE_MCP="gitea" ;;
  none)               REMOTE_URL=""; REMOTE_API=""; REMOTE_TOKENENV=""; REMOTE_MCP="none" ;;
  custom|*)
    REMOTE_URL="$(ask 'Base URL (e.g. https://git.example.com)' "$REMOTE_URL")"
    REMOTE_API="$(ask 'API flavour (gitlab-api/github-api/bitbucket/gitea-api/generic)' "${REMOTE_API:-generic}")"
    REMOTE_TOKENENV="$(ask 'Env var holding the token' "${REMOTE_TOKENENV:-GIT_REMOTE_TOKEN}")"
    REMOTE_MCP="$(ask 'Git-host MCP (github/gitlab/bitbucket/forgejo/gitea/none)' "${REMOTE_MCP:-none}")"
    ;;
esac
[ "$REMOTE_TYPE" != none ] && [ "$REMOTE_TYPE" != custom ] && REMOTE_MCP="$(ask 'Git-host MCP (github/gitlab/bitbucket/forgejo/gitea/none)' "$REMOTE_MCP")"

# dolt sync-on-close
SYNC_ONCLOSE="$(j .sync.askOnClose)"; [ -z "$SYNC_ONCLOSE" ] && SYNC_ONCLOSE=true
[ "$REMOTE_TYPE" = none ] && SYNC_ONCLOSE=false
[ "$REMOTE_TYPE" != none ] && SYNC_ONCLOSE="$(ask_yn 'ask to push + dolt-sync on each Beads issue close?' "$(dyn "$SYNC_ONCLOSE")")"
PSTART="$(j .sync.pullOnStart)"; [ -z "$PSTART" ] && PSTART=true
[ "$REMOTE_TYPE" != none ] && PSTART="$(ask_yn 'auto-pull shared Beads issues at session start?' "$(dyn "$PSTART")")"

# Ollama
OLLAMA_ON="$(ask_yn 'set up Ollama (local models)?' "$(dyn "$(j .ollama.enabled)")")"
OLLAMA_URL="$(j .ollama.url)"; [ -z "$OLLAMA_URL" ] && OLLAMA_URL="http://localhost:11434"
OLLAMA_JSON="$(jq -c '.ollama.models // []' "$CFG")"
if [ "$OLLAMA_ON" = true ]; then
  CUR="$(jq -r '(.ollama.models // []) | join(",")' "$CFG")"
  OLLAMA_MODELS="$(ask 'Ollama models (comma-separated; qwen3-coder recommended)' "${CUR:-qwen3-coder}")"
  OLLAMA_URL="$(ask 'Ollama URL' "$OLLAMA_URL")"
  OLLAMA_JSON="$(printf '%s' "$OLLAMA_MODELS" | jq -Rc 'split(",")|map(gsub("^ +| +$";""))|map(select(length>0))' 2>/dev/null)"; [ -z "$OLLAMA_JSON" ] && OLLAMA_JSON='[]'
fi
# router auto-on with ollama
ROUTER_DEF="$(dyn "$(j .router.enabled)")"; [ "$OLLAMA_ON" = true ] && ROUTER_DEF=y
ROUTER_ON="$(ask_yn 'claude-code-router (route easy/background tasks to cheap/local models)?' "$ROUTER_DEF")"

# team preferences
TEAM_ON="$(ask_yn 'shared team/user preferences (code style)?' "$(dyn "$(j .teamPrefs.enabled)")")"
TEAM_STYLE="$(j .teamPrefs.codeStyle)"; [ -z "$TEAM_STYLE" ] && TEAM_STYLE=google
[ "$TEAM_ON" = true ] && TEAM_STYLE="$(ask 'code style preset (google/airbnb/standard/custom)' "$TEAM_STYLE")"

AIM="$(ask 'project aim' "$(j .project.aim)")"
ARCH="$(ask 'architecture' "$(j .project.architecture)")"
OS="$(ask 'OS' "$(j .dev.os)")"
IDE="$(ask 'IDE' "$(j .dev.ide)")"

GIT_MODEL="$(j .git.model)"; [ -z "$GIT_MODEL" ] && GIT_MODEL=none
GIT_STRICT=false; GIT_PRONLY=false; GIT_AUTOREL=false; GIT_VER=none; GIT_TAGS=true; GIT_CHORE=false
if [ "$VCS_SYS" = git ]; then
  echo "Git branching model:"
  GIT_MODEL="$(ask 'model (simple/gitflow/none)' "$GIT_MODEL")"
  if [ "$GIT_MODEL" != none ] && [ -n "$GIT_MODEL" ]; then
    GIT_STRICT="$(ask_yn 'strict branch rules?' "$(dyn "$(j .git.strict)")")"
    GIT_PRONLY="$(ask_yn 'merges only via PR (no direct push to main/develop)?' "$(dyn "$(j .git.prOnly)")")"
    GIT_AUTOREL="$(ask_yn 'auto-release on develop->main?' "$(dyn "$(j .git.autoRelease)")")"
    if [ "$GIT_AUTOREL" = true ]; then
      GIT_VER="$(ask 'version strategy (semver/calver)' "$(j .git.versionStrategy)")"
      GIT_TAGS="$(ask_yn 'git tag on release?' "$(dyn "$(j .git.releaseTags)")")"
    fi
    GIT_CHORE="$(ask_yn 'allow chore/* branches?' "$(dyn "$(j .git.chore)")")"
  fi
fi

jq -n \
  --argjson cave "$CAVE_ON" --arg cmode "$CAVE_MODE" \
  --argjson rtk "$RTK_ON" --argjson router "$ROUTER_ON" --argjson gfy "$GRAPHIFY_ON" \
  --argjson tm "$TM_ON" --argjson fs "$FS_ON" --argjson ctx7 "$CTX7_ON" --argjson coco "$COCO_ON" \
  --argjson mem "$MEM_ON" --argjson memg "$MEM_GRAPH" --arg memi "$MEM_INT" \
  --arg cauth "$CLAUDE_AUTH" --arg vsys "$VCS_SYS" \
  --arg rtype "$REMOTE_TYPE" --arg rurl "$REMOTE_URL" --arg rapi "$REMOTE_API" --arg rtok "$REMOTE_TOKENENV" --arg rmcp "$REMOTE_MCP" \
  --argjson sync "$SYNC_ONCLOSE" --arg pstart "$PSTART" \
  --argjson oll "$OLLAMA_ON" --arg ollurl "$OLLAMA_URL" --argjson ollm "$OLLAMA_JSON" \
  --argjson team "$TEAM_ON" --arg tstyle "$TEAM_STYLE" \
  --arg aim "$AIM" --arg arch "$ARCH" --arg os "$OS" --arg ide "$IDE" \
  --arg gmodel "$GIT_MODEL" --argjson gstrict "$GIT_STRICT" --argjson gpr "$GIT_PRONLY" \
  --argjson gauto "$GIT_AUTOREL" --arg gver "$GIT_VER" --argjson gtags "$GIT_TAGS" --argjson gchore "$GIT_CHORE" \
  '{caveman:{enabled:$cave,mode:$cmode},rtk:{enabled:$rtk},router:{enabled:$router},
    graphify:{enabled:$gfy},taskmaster:{enabled:$tm},mcp:{filesystem:$fs,context7:$ctx7,cocoindex:$coco},
    memory:{enabled:$mem,graph:$memg,intensity:$memi},
    claude:{auth:$cauth},
    vcs:{system:$vsys},
    remote:{type:$rtype,baseUrl:$rurl,api:$rapi,tokenEnv:$rtok,mcp:$rmcp},
    sync:{askOnClose:$sync,pullOnStart:($pstart=="true")},
    ollama:{enabled:$oll,url:$ollurl,models:$ollm},
    teamPrefs:{enabled:$team,codeStyle:$tstyle},
    project:{aim:$aim,architecture:$arch},
    dev:{os:$os,ide:$ide},
    git:{model:$gmodel,strict:$gstrict,prOnly:$gpr,autoRelease:$gauto,versionStrategy:$gver,releaseTags:$gtags,chore:$gchore},
    templates_search:false}' > "$CFG.n" && mv "$CFG.n" "$CFG"
echo "  updated $CFG"
bash "$AIFLOW_HOME/lib/apply.sh"
