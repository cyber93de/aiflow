#!/usr/bin/env bash
# aiflow init - copy templates, ask a few questions, write .aiflow/config.json, apply.
# Everything is project-scoped. No global state, no tokens stored globally.
set -uo pipefail

AIFLOW_HOME="${AIFLOW_HOME:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TPL="$AIFLOW_HOME/templates"

TARGET="."; FORCE=0; NO_GIT=0; NO_BEADS=0; YES=0; INSTALL_DEPS=0; NO_TOKENSAVE=0
for a in "$@"; do
  case "$a" in
    --force) FORCE=1;; --no-git) NO_GIT=1;; --no-beads) NO_BEADS=1;; --yes|-y) YES=1;;
    --install-deps) INSTALL_DEPS=1;; --no-install-deps) INSTALL_DEPS=-1;;
    --no-token-saving) NO_TOKENSAVE=1;;
    -*) echo "unknown flag: $a" >&2; exit 2;; *) TARGET="$a";;
  esac
done
mkdir -p "$TARGET"; TARGET="$(cd "$TARGET" && pwd)"

# ---- detect new vs existing (brownfield) project BEFORE we add our files ----
EXISTING=0
if { [ -d "$TARGET/.git" ] && git -C "$TARGET" rev-parse --verify HEAD >/dev/null 2>&1; } \
   || [ -n "$(ls -A "$TARGET" 2>/dev/null | grep -vE '^\.git$')" ]; then
  EXISTING=1
fi
if [ "$EXISTING" = 1 ]; then
  echo ">> aiflow init -> $TARGET  (existing project: files preserved, onboarding offered)"
else
  echo ">> aiflow init -> $TARGET  (new project)"
fi

# ---- copy static templates (no clobber unless --force) ----
copy_flag="-rn"; [ "$FORCE" = 1 ] && copy_flag="-rf"
shopt -s dotglob
for item in "$TPL"/*; do cp $copy_flag "$item" "$TARGET/" 2>/dev/null || true; done
shopt -u dotglob
chmod +x "$TARGET/.aiflow/"*.sh "$TARGET/.claude/hooks/"*.sh "$TARGET/.githooks/"* "$TARGET/docker/"*.sh 2>/dev/null || true
cd "$TARGET"

# ---- detect OS default ----
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) OS_DEF=windows;; Darwin) OS_DEF=macos;; Linux) OS_DEF=linux;; *) OS_DEF=unknown;;
esac

# ---- interactive helpers (read from tty so piping still works) ----
TTY=/dev/tty; [ -r /dev/tty ] || TTY=/dev/stdin
ask()    { local p="$1" d="$2" a; if [ "$YES" = 1 ]; then echo "$d"; return; fi; printf "  %s [%s]: " "$p" "$d" >&2; read -r a <"$TTY" || a=""; echo "${a:-$d}"; }
# ask_yn always emits true/false (also in --yes mode).
ask_yn() { local p="$1" d="$2" a; if [ "$YES" = 1 ]; then a="$d"; else printf "  %s (y/n) [%s]: " "$p" "$d" >&2; read -r a <"$TTY" || a=""; a="${a:-$d}"; fi; case "$a" in [Yy]*|true) echo true;; *) echo false;; esac; }

echo; echo "Configure this project (Enter = default):"
if [ "$NO_TOKENSAVE" = 1 ]; then
  echo "  --no-token-saving: caveman + rtk are OFF (full, unfiltered output)."
  CAVE_ON=false; CAVE_MODE=full; RTK_ON=false
else
  echo "  Token-saving defaults (caveman + rtk) and intensive graph-memory learning are ON by default."
  CAVE_ON="$(ask_yn 'Save tokens with caveman (terse output)?' y)"
  CAVE_MODE=full
  [ "$CAVE_ON" = true ] && CAVE_MODE="$(ask 'caveman mode (full recommended / lite / ultra)' full)"
  RTK_ON="$(ask_yn 'Save tokens by filtering CLI output with rtk?' y)"
fi
GRAPHIFY_ON="$(ask_yn 'Use graphify (structural code graph: imports/call-graph) for memory?' y)"
COCO_ON="$(ask_yn 'Use cocoindex-code (semantic code RAG search, local, ~70% fewer tokens)?' y)"
TM_ON="$(ask_yn 'Use claude-task-master for task decomposition?' y)"
FS_ON="$(ask_yn 'Enable filesystem MCP?' y)"
CTX7_ON="$(ask_yn 'Enable context7 MCP (live library docs)?' y)"

# ---- Claude memory + graph-memory intensity ----
echo; echo "Claude memory (intensive graph-memory learning is recommended):"
MEM_ON="$(ask_yn 'Enable persistent Claude memory?' y)"
MEM_GRAPH=false; MEM_INT=off
if [ "$MEM_ON" = true ]; then
  MEM_GRAPH="$(ask_yn 'Learn the codebase into a knowledge graph (graph memory)?' y)"
  MEM_INT="$(ask 'Memory learning intensity (aggressive / normal / light)' aggressive)"
fi

# ---- Claude access: OAuth vs API key (token-based; no OAuth for Git hosts) ----
echo; echo "Claude access (token-based; pick how you authenticate):"
CLAUDE_AUTH="$(ask 'Claude auth (apikey = ANTHROPIC_API_KEY / oauth = claude setup-token)' apikey)"

# ---- local version control: git / svn / none ----
echo; echo "Version control:"
VCS_SYS="$(ask 'Local version control (git / svn / none)' git)"

# ---- remote host: token-based only (no OAuth) ----
echo; echo "Remote host (API tokens only — no OAuth):"
echo "  github | github-enterprise | gitlab | gitlab-self | bitbucket | forgejo | gitea | custom | none"
REMOTE_TYPE="$(ask 'Remote type' github)"
REMOTE_URL=""; REMOTE_API=""; REMOTE_TOKENENV=""; REMOTE_MCP=""
case "$REMOTE_TYPE" in
  github)             REMOTE_URL="https://github.com"; REMOTE_API="github-api"; REMOTE_TOKENENV="GITHUB_TOKEN"; REMOTE_MCP="github" ;;
  github-enterprise)  REMOTE_URL="$(ask 'GHE base URL (e.g. https://github.example.com)' '')"; REMOTE_API="github-api"; REMOTE_TOKENENV="GITHUB_TOKEN"; REMOTE_MCP="github" ;;
  gitlab)             REMOTE_URL="https://gitlab.com"; REMOTE_API="gitlab-api"; REMOTE_TOKENENV="GITLAB_TOKEN"; REMOTE_MCP="gitlab" ;;
  gitlab-self)        REMOTE_URL="$(ask 'GitLab base URL (e.g. https://gitlab.example.com)' '')"; REMOTE_API="gitlab-api"; REMOTE_TOKENENV="GITLAB_TOKEN"; REMOTE_MCP="gitlab" ;;
  bitbucket)          REMOTE_URL="$(ask 'Bitbucket base URL' 'https://api.bitbucket.org/2.0')"; REMOTE_API="bitbucket"; REMOTE_TOKENENV="BITBUCKET_TOKEN"; REMOTE_MCP="bitbucket" ;;
  forgejo)            REMOTE_URL="$(ask 'Forgejo base URL (e.g. https://code.example.com)' '')"; REMOTE_API="gitea-api"; REMOTE_TOKENENV="GIT_REMOTE_TOKEN"; REMOTE_MCP="forgejo" ;;
  gitea)              REMOTE_URL="$(ask 'Gitea base URL (e.g. https://git.example.com)' '')"; REMOTE_API="gitea-api"; REMOTE_TOKENENV="GIT_REMOTE_TOKEN"; REMOTE_MCP="gitea" ;;
  none)               REMOTE_URL=""; REMOTE_API=""; REMOTE_TOKENENV=""; REMOTE_MCP="none" ;;
  custom|*)
    echo "  Custom host — pick the matching API + MCP:"
    REMOTE_URL="$(ask 'Base URL (e.g. https://git.example.com)' '')"
    REMOTE_API="$(ask 'API flavour (gitlab-api / github-api / bitbucket / gitea-api / generic)' generic)"
    REMOTE_TOKENENV="$(ask 'Env var holding the token' GIT_REMOTE_TOKEN)"
    REMOTE_MCP="$(ask 'Git-host MCP to wire (github / gitlab / bitbucket / forgejo / gitea / none)' none)"
    ;;
esac
# offer to override the auto-picked MCP (so the list is always available)
if [ "$REMOTE_TYPE" != none ] && [ "$REMOTE_TYPE" != custom ]; then
  REMOTE_MCP="$(ask "Git-host MCP to wire (github/gitlab/bitbucket/forgejo/gitea/none)" "$REMOTE_MCP")"
fi

# ---- dolt sync-on-close rule ----
SYNC_ONCLOSE=true
[ "$REMOTE_TYPE" = none ] && SYNC_ONCLOSE=false
[ "$REMOTE_TYPE" != none ] && SYNC_ONCLOSE="$(ask_yn 'Ask to push + dolt-sync the remote each time a Beads issue is closed?' y)"

# ---- Ollama (local models, no key) ----
echo; echo "Ollama (local models — no API key needed):"
OLLAMA_ON="$(ask_yn 'Set up Ollama for local models?' n)"
OLLAMA_URL="http://localhost:11434"; OLLAMA_MODELS=""
if [ "$OLLAMA_ON" = true ]; then
  echo "  Suggested: qwen3-coder (recommended, newest Qwen), qwen3, llama3.1, deepseek-r1, gemma2, mistral"
  OLLAMA_MODELS="$(ask 'Models to install (comma-separated)' 'qwen3-coder')"
  OLLAMA_URL="$(ask 'Ollama URL' "$OLLAMA_URL")"
fi
# router auto-on when Ollama is set up (so the local models actually get used)
ROUTER_ON="$(ask_yn 'Use claude-code-router (route easy/background tasks to cheap/local models)?' "$([ "$OLLAMA_ON" = true ] && echo y || echo n)")"

# ---- team/user-wide preferences (shared, versioned) ----
echo; echo "Shared team preferences (versioned in .aiflow/team-prefs.json):"
TEAM_ON="$(ask_yn 'Use shared team/user preferences (code style, language)?' n)"
TEAM_STYLE=google
[ "$TEAM_ON" = true ] && TEAM_STYLE="$(ask 'Code style preset (google / airbnb / standard / custom)' google)"

AIM="$(ask 'Project aim (what should it achieve?)' '')"
ARCH="$(ask 'Target architecture (e.g. hexagonal, MVC, layered...)' '')"
OS="$(ask 'Your OS (windows / macos / linux)' "$OS_DEF")"
IDE="$(ask 'Your IDE (vscode / intellij / other)' vscode)"
TPL_SEARCH="$(ask_yn 'Browse claude-code-templates for extra configs now?' n)"

# ---- git branching governance (only when local VCS is git) ----
GIT_MODEL=none; GIT_STRICT=false; GIT_PRONLY=false; GIT_AUTOREL=false; GIT_VER=none; GIT_TAGS=true; GIT_CHORE=false
if [ "$VCS_SYS" = git ]; then
  echo; echo "Git branching model:"
  GIT_MODEL="$(ask 'Branching model (simple / gitflow / none)' simple)"
  if [ "$GIT_MODEL" != none ]; then
    GIT_STRICT="$(ask_yn 'Enable strict branch rules?' y)"
    GIT_PRONLY="$(ask_yn 'Merges only via Pull Requests (no direct push to main/develop)?' y)"
    GIT_AUTOREL="$(ask_yn 'Auto-create a release when develop merges into main?' n)"
    if [ "$GIT_AUTOREL" = true ]; then
      GIT_VER="$(ask 'Version strategy (semver / calver)' semver)"
      GIT_TAGS="$(ask_yn 'Create a git tag on each release?' y)"
    fi
    GIT_CHORE="$(ask_yn 'Allow chore/* branches?' y)"
  fi
fi

# ---- write .aiflow/config.json ----
mkdir -p .aiflow
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
# ollama models (comma-separated) -> trimmed JSON array
OLLAMA_JSON="$(printf '%s' "$OLLAMA_MODELS" | jq -Rc 'split(",")|map(gsub("^ +| +$";""))|map(select(length>0))' 2>/dev/null)"
[ -z "$OLLAMA_JSON" ] && OLLAMA_JSON='[]'
cat > .aiflow/config.json <<EOF
{
  "caveman":   { "enabled": $CAVE_ON, "mode": "$CAVE_MODE" },
  "rtk":       { "enabled": $RTK_ON },
  "router":    { "enabled": $ROUTER_ON },
  "graphify":  { "enabled": $GRAPHIFY_ON },
  "taskmaster":{ "enabled": $TM_ON },
  "mcp":       { "filesystem": $FS_ON, "context7": $CTX7_ON, "cocoindex": $COCO_ON },
  "memory":    { "enabled": $MEM_ON, "graph": $MEM_GRAPH, "intensity": "$MEM_INT" },
  "claude":    { "auth": "$CLAUDE_AUTH" },
  "vcs":       { "system": "$VCS_SYS" },
  "remote": {
    "type": "$REMOTE_TYPE",
    "baseUrl": "$(esc "$REMOTE_URL")",
    "api": "$REMOTE_API",
    "tokenEnv": "$REMOTE_TOKENENV",
    "mcp": "$REMOTE_MCP"
  },
  "sync":    { "askOnClose": $SYNC_ONCLOSE, "pullOnStart": true },
  "ollama":  { "enabled": $OLLAMA_ON, "url": "$(esc "$OLLAMA_URL")", "models": $OLLAMA_JSON },
  "teamPrefs": { "enabled": $TEAM_ON, "codeStyle": "$TEAM_STYLE" },
  "project": { "aim": "$(esc "$AIM")", "architecture": "$(esc "$ARCH")" },
  "dev": { "os": "$OS", "ide": "$IDE" },
  "git": {
    "model": "$GIT_MODEL",
    "strict": $GIT_STRICT,
    "prOnly": $GIT_PRONLY,
    "autoRelease": $GIT_AUTOREL,
    "versionStrategy": "$GIT_VER",
    "releaseTags": $GIT_TAGS,
    "chore": $GIT_CHORE
  },
  "templates_search": $TPL_SEARCH,
  "meta": { "aiflowVersion": "$(esc "$(cat "$AIFLOW_HOME/VERSION" 2>/dev/null || echo 0.0.0)")" }
}
EOF
echo "  wrote .aiflow/config.json"

# ---- .env ----
[ -f .env ] || { [ -f .env.example ] && cp .env.example .env && echo "  .env created (fill in tokens!)"; }

# ---- local version control ----
case "$VCS_SYS" in
  git)  [ "$NO_GIT" = 0 ] && [ ! -d .git ] && { git init -q && echo "  git initialised"; } ;;
  svn)  if command -v svn >/dev/null 2>&1; then
          [ -d .svn ] || echo "  svn selected — run 'svnadmin create' / 'svn checkout' for your repo (aiflow won't auto-create it)"
        else echo "  ! svn selected but 'svn' not installed"; fi ;;
  none) echo "  version control: none (git init / hooks / branching governance skipped)" ;;
esac

# ---- beads ----
if [ "$NO_BEADS" = 0 ]; then
  if command -v bd >/dev/null 2>&1; then [ -d .beads ] || { bd init >/dev/null 2>&1 || true; echo "  beads initialised"; }
  else echo "  ! 'bd' not found - install Beads or /beads:init in Claude later"; fi
fi

# ---- render everything from config ----
bash "$AIFLOW_HOME/lib/apply.sh"

# ---- install missing tools (so you don't pre-install anything) ----
DO_DEPS=0
if [ "$INSTALL_DEPS" = 1 ]; then DO_DEPS=1
elif [ "$INSTALL_DEPS" = -1 ]; then DO_DEPS=0
elif [ "$YES" = 0 ]; then [ "$(ask_yn 'Install the enabled tools now (claude, beads, + chosen extras)?' y)" = true ] && DO_DEPS=1; fi
if [ "$DO_DEPS" = 1 ]; then DEPS_ARGS=""; [ "$YES" = 1 ] && DEPS_ARGS="--yes"; bash "$AIFLOW_HOME/lib/install-deps.sh" $DEPS_ARGS; fi

# ---- graphify build (automated) ----
if [ "$GRAPHIFY_ON" = true ] && command -v graphify >/dev/null 2>&1; then
  echo "  building graphify knowledge graph..."; graphify build . >/dev/null 2>&1 || graphify . >/dev/null 2>&1 || echo "    (run 'aiflow index' inside Claude with /graphify . )"
fi

# ---- cocoindex-code RAG index (build so semantic search is ready) ----
if [ "$COCO_ON" = true ] && command -v ccc >/dev/null 2>&1; then
  echo "  building cocoindex-code RAG index..."; ccc index >/dev/null 2>&1 || echo "    (run 'aiflow index' later to build the RAG index)"
fi

# ---- Ollama models (pull selected models so they're ready to use) ----
if [ "$OLLAMA_ON" = true ]; then
  bash "$AIFLOW_HOME/lib/ollama.sh" pull || echo "  (run 'aiflow ollama pull' later to fetch models)"
fi

# ---- optional: browse claude-code-templates ----
if [ "$TPL_SEARCH" = true ]; then
  echo "  launching claude-code-templates browser..."; npx -y claude-code-templates@latest || true
fi

# ---- existing project: offer to learn the codebase into memory ----
DID_ONBOARD=0
if [ "$EXISTING" = 1 ] && command -v claude >/dev/null 2>&1; then
  if [ "$YES" = 0 ] && [ "$(ask_yn 'Existing codebase detected - learn it now into memory + CLAUDE.md + arc42 (aiflow onboard)?' y)" = true ]; then
    set -a; [ -f .env ] && . ./.env; set +a
    bash .aiflow/run-agent.sh onboarder && DID_ONBOARD=1 || echo "  (run 'aiflow onboard' later)"
  fi
fi

cat <<EOF

Done.
EOF
if [ "$EXISTING" = 1 ]; then
  cat <<EOF
This is an EXISTING project. Your files were preserved (no overwrite without --force).
Next steps:
  1) edit .env        -> GITHUB_TOKEN + (ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)
  2) $([ "$DID_ONBOARD" = 1 ] && echo 'review what onboard learned:' || echo 'learn the codebase:  aiflow onboard   ->') .claude/memory/codebase-map.md + CLAUDE.md §1/§2 + docs/architecture/
  3) reconcile CLAUDE.md / docs/architecture with reality, then: aiflow shell
  4) optional baseline audits: aiflow security-check | quality-check | dependency-check | test-gap | docs-check
EOF
else
  cat <<EOF
This is a NEW project. Next steps:
  1) edit .env        -> GITHUB_TOKEN + (ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN)
  2) review CLAUDE.md + .claude/memory/project-aim.md (fill the [EDIT ME] blocks)
  3) aiflow shell     -> start Claude Code (secrets loaded)
EOF
fi
echo "  Change any choice later: aiflow change-settings   |   full manual: README.md / README.de.md"
