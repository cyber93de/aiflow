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
check "copilot" copilot "GitHub Copilot CLI: npm i -g @github/copilot (only if agents.copilot enabled)"
check "codex"   codex   "OpenAI Codex CLI: npm i -g @openai/codex (only if agents.codex enabled)"
check "git"     git     "https://git-scm.com"
check "node"    node    "https://nodejs.org (LTS)"
check "jq"      jq      "https://jqlang.github.io/jq/ (required to read .aiflow/config.json)"
check "bd"      bd      "Beads: https://github.com/steveyegge/beads (or /beads:init in Claude)"
check "ralph"   ralph   "Ralph loop (open-ralph-wiggum): npm i -g @th0rgal/ralph-wiggum (needs bun)"
check "codexsaver" codexsaver "cost-aware Codex CLI router (only if codexsaver.enabled): https://github.com/fendouai/CodexSaver"
check "bun"     bun     "runtime for the Ralph loop: https://bun.sh"
check "dolt"    dolt    "Beads backend (bd runs a dolt sql-server): https://docs.dolthub.com/introduction/installation"
if command -v podman >/dev/null 2>&1; then check "podman" podman "container engine for GitHub MCP + headless runs"
else check "docker" docker "container engine (or Podman): GitHub MCP + headless runs"; fi

# ---- Windows: WSL is where native builds belong, never MinGW (aiflow-53b) ----
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    echo
    echo "windows native-build toolchain (WSL, not MinGW):"
    if ! command -v wsl.exe >/dev/null 2>&1; then
      printf "  [MISS] %-10s -> WSL not available. Admin PowerShell: wsl --install   (then reboot)\n" "wsl"
      printf "  [----] %-10s    then: wsl --install -d Ubuntu\n" ""
    else
      # wsl.exe writes UTF-16LE; strip the NULs so the output is greppable from bash.
      WSL_LIST="$($TO wsl.exe -l -q 2>/dev/null | tr -d '\0\r' | grep -v '^[[:space:]]*$' | tr '\n' ' ')"
      if [ -z "$WSL_LIST" ]; then
        printf "  [MISS] %-10s -> WSL present but no distribution installed: wsl --install -d Ubuntu\n" "wsl distro"
      else
        printf "  [ok]   %-10s %s\n" "wsl" "distros: $WSL_LIST"
        WSL_V2="$($TO wsl.exe -l -v 2>/dev/null | tr -d '\0\r' | awk 'NR>1 && NF {print $NF}' | grep -c '^2$')"
        if [ "${WSL_V2:-0}" -gt 0 ]; then printf "  [ok]   %-10s %s distro(s) on WSL2\n" "wsl2" "$WSL_V2"
        else printf "  [MISS] %-10s -> distro is on WSL1: wsl --set-default-version 2 && wsl --set-version <distro> 2\n" "wsl2"; fi
        # gcc/g++ must live INSIDE the distro, not on the Windows PATH. Starting a cold distro
        # takes well over the 5s $TO budget used for --version probes, hence the longer bound.
        WSLTO=""; command -v timeout >/dev/null 2>&1 && WSLTO="timeout 25"
        GCCV="$($WSLTO wsl.exe -e sh -c 'command -v g++ >/dev/null && gcc --version 2>/dev/null | head -n1' 2>/dev/null | tr -d '\r')"
        if [ -n "$GCCV" ]; then
          printf "  [ok]   %-10s %s\n" "gcc/g++" "$GCCV"
        else
          printf "  [MISS] %-10s -> in WSL: sudo apt update && sudo apt install -y build-essential\n" "gcc/g++"
        fi
      fi
    fi
    # Hardware virtualisation - WSL2 cannot run without it, and the BIOS switch is easy to miss.
    # A running WSL2 distro is proof enough; only pay for the (slow) WMI probe when it isn't.
    if [ "${WSL_V2:-0}" -gt 0 ]; then
      printf "  [ok]   %-10s enabled (a WSL2 distro is running)\n" "vt-x/svm"
    else
      VT="$(timeout 20 powershell.exe -NoProfile -NonInteractive -Command \
            '(Get-CimInstance Win32_Processor | Select-Object -First 1).VirtualizationFirmwareEnabled' \
            2>/dev/null | tr -d '\r' | head -n1)"
      case "$VT" in
        True)  printf "  [ok]   %-10s enabled in BIOS/UEFI\n" "vt-x/svm" ;;
        False) printf "  [MISS] %-10s -> enable Intel VT-x / AMD SVM Mode in the BIOS/UEFI, then reboot\n" "vt-x/svm" ;;
        *)     printf "  [----] %-10s could not determine (Task Manager -> Performance -> CPU -> Virtualization)\n" "vt-x/svm" ;;
      esac
    fi
    # A MinGW/MSYS2 gcc on the Windows PATH is exactly what we do not want people using.
    if command -v gcc >/dev/null 2>&1 && gcc -dumpmachine 2>/dev/null | grep -qi 'mingw\|msys'; then
      printf "  [warn] %-10s MinGW/MSYS gcc on PATH (%s) - build native code in WSL instead\n" "mingw" "$(gcc -dumpmachine 2>/dev/null)"
    fi
    echo "  docs: https://cyber93de.github.io/aiflow/installation#windows-prerequisites-do-this-first"
    ;;
esac

echo
echo "task / memory / vcs:"
check "task-master" task-master "claude-task-master: npm i -g task-master-ai"
check "graphify" graphify "structural code graph: uv tool install graphifyy && graphify install (repo: https://github.com/Graphify-Labs/graphify)"
check "ccc"     ccc     "cocoindex-code (semantic RAG): uv tool install 'cocoindex-code[full]'"
check "uv"      uv      "https://docs.astral.sh/uv/ (installs graphify + cocoindex-code)"
check "gh"      gh      "GitHub CLI: https://cli.github.com (only if remote=github)"
check "glab"    glab    "GitLab CLI: https://gitlab.com/gitlab-org/cli (only if remote=gitlab)"
check "svn"     svn     "Subversion (only if vcs.system=svn)"
check "ollama"  ollama  "local models: https://ollama.com/download (only if ollama enabled)"

echo
echo "cost / token-efficiency stack:"
check "ccr"     ccr     "claude-code-router: npm i -g @musistudio/claude-code-router"
check "rtk"     rtk     "rtk output filter: https://github.com/rtk-ai/rtk (aiflow enables it per project)"
if command -v npx >/dev/null 2>&1; then
  echo "  [ok]   ccusage    via 'aiflow cost'"
  echo "  [ok]   templates  via 'npx claude-code-templates@latest'"
else echo "  [MISS] npx        needs node (for ccusage + claude-code-templates)"; fi

if command -v jq >/dev/null 2>&1 && [ -f .aiflow/config.json ]; then
  echo
  echo "this project (.aiflow/config.json):"
  printf "  agents:  claude=%s copilot=%s codex=%s  codexsaver=%s  modelRouting=%s  ponytail=%s\n" \
    "$(jq -r 'if .agents.claude == null then true else .agents.claude end' .aiflow/config.json)" \
    "$(jq -r '.agents.copilot // false' .aiflow/config.json)" \
    "$(jq -r '.agents.codex // false' .aiflow/config.json)" \
    "$(jq -r '.codexsaver.enabled // false' .aiflow/config.json)" \
    "$(jq -r 'if .modelRouting.enabled == null then true else .modelRouting.enabled end' .aiflow/config.json)" \
    "$(jq -r 'if .ponytail.enabled then (.ponytail.mode // "full") else "off" end' .aiflow/config.json)"
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
echo "git hooks:"
# core.hooksPath lives in .git/config, which is never cloned - so a fresh clone silently runs
# no hooks at all until someone sets it. `aiflow apply` does it; a clone needs it again.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  HP="$(git config --get core.hooksPath || true)"
  if [ -n "$HP" ] && [ -d "$HP" ]; then
    echo "  [ok]   core.hooksPath=$HP"
  else
    HINT=".githooks"; [ -d .beads/hooks ] && [ ! -d .githooks ] && HINT=".beads/hooks"
    echo "  [----] core.hooksPath is not set - commit/push rules do NOT run in this clone"
    echo "         fix: git config core.hooksPath $HINT   (or: aiflow apply)"
  fi
else
  echo "  [----] not a git work tree"
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
