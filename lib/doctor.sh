#!/usr/bin/env bash
# aiflow doctor - check prerequisites
set -uo pipefail

TO=""; command -v timeout >/dev/null 2>&1 && TO="timeout 5"   # never let a --version probe hang
check() {
  local name="$1" cmd="$2" hint="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  [ok]   %-10s %s\n" "$name" "$($TO "$cmd" --version 2>/dev/null | head -n1)"
  else
    printf "  [MISS] %-10s -> %s\n" "$name" "$hint"
  fi
}

echo "aiflow doctor"
echo "core:"
check "claude"  claude  "npm i -g @anthropic-ai/claude-code"
check "git"     git     "https://git-scm.com"
check "node"    node    "https://nodejs.org (LTS)"
check "jq"      jq      "https://jqlang.github.io/jq/ (required to read .aiflow/config.json)"
check "bd"      bd      "Beads: https://github.com/steveyegge/beads (or /beads:init in Claude)"
check "dolt"    dolt    "Beads backend (bd runs a dolt sql-server): https://docs.dolthub.com/introduction/installation"
if command -v podman >/dev/null 2>&1; then check "podman" podman "container engine for GitHub MCP + headless runs"
else check "docker" docker "container engine (or Podman): GitHub MCP + headless runs"; fi

echo
echo "task / memory / vcs:"
check "task-master" task-master "claude-task-master: npm i -g task-master-ai"
check "graphify" graphify "structural code graph: uv tool install graphifyy && graphify install"
check "ccc"     ccc     "cocoindex-code (semantic RAG): uv tool install 'cocoindex-code[full]'"
check "uv"      uv      "https://docs.astral.sh/uv/ (installs graphify + cocoindex-code)"
check "gh"      gh      "GitHub CLI: https://cli.github.com (only if remote=github)"
check "glab"    glab    "GitLab CLI: https://gitlab.com/gitlab-org/cli (only if remote=gitlab)"
check "svn"     svn     "Subversion (only if vcs.system=svn)"
check "ollama"  ollama  "local models: https://ollama.com/download (only if ollama enabled)"

echo
echo "cost / token-efficiency stack:"
check "ccr"     ccr     "claude-code-router: npm i -g @musistudio/claude-code-router"
check "rtk"     rtk     "rtk output filter: see rtk-ai.app (aiflow enables it per project)"
if command -v npx >/dev/null 2>&1; then
  echo "  [ok]   ccusage    via 'aiflow cost'"
  echo "  [ok]   templates  via 'npx claude-code-templates@latest'"
else echo "  [MISS] npx        needs node (for ccusage + claude-code-templates)"; fi

if command -v jq >/dev/null 2>&1 && [ -f .aiflow/config.json ]; then
  echo
  echo "this project (.aiflow/config.json):"
  printf "  remote:  %s (%s) — host MCP: %s\n" \
    "$(jq -r '.remote.type // "?"' .aiflow/config.json)" \
    "$(jq -r '.remote.baseUrl // "" | if .=="" then "public" else . end' .aiflow/config.json)" \
    "$(jq -r '.remote.mcp // "none"' .aiflow/config.json)"
  printf "  vcs:     %s   ollama: %s\n" \
    "$(jq -r '.vcs.system // "git"' .aiflow/config.json)" \
    "$(jq -r 'if .ollama.enabled then (.ollama.models|join(",")) else "off" end' .aiflow/config.json)"
  printf "  memory:  graph(graphify)=%s  rag(cocoindex)=%s  context7=%s  intensity=%s\n" \
    "$(jq -r '.graphify.enabled // false' .aiflow/config.json)" \
    "$(jq -r '.mcp.cocoindex // false' .aiflow/config.json)" \
    "$(jq -r '.mcp.context7 // false' .aiflow/config.json)" \
    "$(jq -r '.memory.intensity // "normal"' .aiflow/config.json)"
fi

echo
echo "env:"
ENV_VARS="GITHUB_TOKEN GITLAB_TOKEN GIT_REMOTE_TOKEN ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN CONTEXT7_API_KEY"
# also show the configured remote token env, if any
if command -v jq >/dev/null 2>&1 && [ -f .aiflow/config.json ]; then
  RTOK="$(jq -r '.remote.tokenEnv // empty' .aiflow/config.json 2>/dev/null)"
  case " $ENV_VARS " in *" $RTOK "*) : ;; *) [ -n "$RTOK" ] && ENV_VARS="$ENV_VARS $RTOK";; esac
fi
for v in $ENV_VARS; do
  if [ -n "${!v:-}" ]; then echo "  [set]  $v"; else echo "  [----] $v (not in shell env; .env is loaded by 'aiflow shell')"; fi
done
