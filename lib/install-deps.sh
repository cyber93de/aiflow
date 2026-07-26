#!/usr/bin/env bash
# aiflow install-deps - install the toolchain so you don't have to pre-install anything.
# Installs ONLY tools that are (a) missing and (b) enabled in .aiflow/config.json
# (or everything with --all). User-space installers; Docker is never auto-installed.
set -uo pipefail
have() { command -v "$1" >/dev/null 2>&1; }
say()  { echo ">> $*"; }
warn() { echo "  ! $*" >&2; }

ALL=0; YES=0
for a in "$@"; do case "$a" in --all) ALL=1;; --yes|-y) YES=1;; esac; done

# OS
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) OS=windows;; Darwin) OS=macos;; Linux) OS=linux;; *) OS=unknown;; esac

# config-driven toggles (default off unless --all or no config)
cfg() { if have jq && [ -f .aiflow/config.json ]; then jq -r "$1 // \"$2\"" .aiflow/config.json; else echo "$2"; fi; }
if [ "$ALL" = 1 ] || [ ! -f .aiflow/config.json ]; then
  RTK=true; TM=true; ROUTER=true; GFY=true   # global/--all: offer the full set
  AGENT_CLAUDE=true; AGENT_COPILOT=true; AGENT_CODEX=true
else
  RTK="$(cfg .rtk.enabled false)"; TM="$(cfg .taskmaster.enabled false)"
  ROUTER="$(cfg .router.enabled false)"; GFY="$(cfg .graphify.enabled false)"
  AGENT_CLAUDE="$(cfg .agents.claude true)"    # default true: back-compat, aiflow's origin agent
  AGENT_COPILOT="$(cfg .agents.copilot false)"
  AGENT_CODEX="$(cfg .agents.codex false)"
fi
OLLAMA="$(cfg .ollama.enabled false)"
COCO="$(cfg .mcp.cocoindex false)"; [ "$ALL" = 1 ] && COCO=true

npmg() { # install a global npm package, retry with sudo on permission error
  have npm || { warn "npm not found - install Node.js first (https://nodejs.org)"; return 1; }
  npm install -g "$1" 2>/dev/null || sudo npm install -g "$1" 2>/dev/null || { warn "failed: npm i -g $1"; return 1; }
}
install_uv() {
  have uv && return 0
  say "installing uv (for graphify)"
  if [ "$OS" = windows ]; then powershell -NoProfile -c "irm https://astral.sh/uv/install.ps1 | iex" || warn "install uv manually: https://docs.astral.sh/uv/";
  else curl -LsSf https://astral.sh/uv/install.sh | sh || warn "install uv manually: https://docs.astral.sh/uv/"; fi
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
}
install_rtk() {
  say "installing rtk"
  if have brew; then brew install rtk
  else curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh || warn "install rtk manually: https://www.rtk-ai.app/docs/getting-started/installation/"; fi
}
install_dolt() { # Beads backend (bd runs a dolt sql-server)
  have dolt && return 0
  say "installing dolt (Beads database backend)"
  if have brew; then brew install dolt
  elif [ "$OS" = windows ]; then
    if have winget; then winget install --id DoltHub.Dolt -e --source winget
    elif have scoop; then scoop install dolt
    else warn "install dolt manually: https://docs.dolthub.com/introduction/installation"; fi
  else sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash' || warn "install dolt: https://docs.dolthub.com/introduction/installation"; fi
}
install_vcs_cli() {
  # remote host: new schema .remote.type, fallback to legacy string .vcs
  local rt; rt="$(cfg .remote.type '')"; [ -z "$rt" ] && rt="$(cfg .vcs github)"
  case "$rt" in
    github)  have gh   || { say "GitHub CLI"; if have brew; then brew install gh; elif have winget; then winget install --id GitHub.cli -e; elif have scoop; then scoop install gh; else (sudo apt-get install -y gh) 2>/dev/null || warn "install gh: https://cli.github.com"; fi; } ;;
    gitlab)  have glab || { say "GitLab CLI"; if have brew; then brew install glab; elif have winget; then winget install --id glab.glab -e; elif have scoop; then scoop install glab; else warn "install glab: https://gitlab.com/gitlab-org/cli"; fi; } ;;
    custom)  say "custom remote ($(cfg .remote.baseUrl '')): using git + token in \$$(cfg .remote.tokenEnv GIT_REMOTE_TOKEN); no host CLI auto-installed" ;;
    none)    : ;;
  esac
}
install_ollama() {
  have ollama && return 0
  say "installing ollama (local models)"
  case "$OS" in
    macos)   have brew && brew install ollama || warn "install ollama: https://ollama.com/download" ;;
    windows) { have winget && winget install --id Ollama.Ollama -e; } || { have scoop && scoop install ollama; } || warn "install ollama: https://ollama.com/download" ;;
    *)       curl -fsSL https://ollama.com/install.sh | sh || warn "install ollama: https://ollama.com/download" ;;
  esac
}
install_bun() { # runtime open-ralph-wiggum needs
  have bun && return 0
  say "installing bun (runtime for the Ralph loop)"
  if have brew; then brew install oven-sh/bun/bun
  elif [ "$OS" = windows ]; then powershell -NoProfile -c "irm bun.sh/install.ps1 | iex" || warn "install bun manually: https://bun.sh"
  else curl -fsSL https://bun.sh/install | bash || warn "install bun manually: https://bun.sh"; fi
  export PATH="$HOME/.bun/bin:$PATH"
}

echo "aiflow install-deps (os=$OS, all=$ALL)"
echo "  enabled: rtk=$RTK task-master=$TM router=$ROUTER graphify=$GFY cocoindex=$COCO ollama=$OLLAMA"
echo "  coding agent(s): claude=$AGENT_CLAUDE copilot=$AGENT_COPILOT codex=$AGENT_CODEX"

# ---- coding agent CLIs (per agents.* config) ----
[ "$AGENT_CLAUDE" = true ]  && ! have claude  && { say "Claude Code"; npmg @anthropic-ai/claude-code; }
[ "$AGENT_COPILOT" = true ] && ! have copilot && { say "GitHub Copilot CLI"; npmg @github/copilot; }
if [ "$AGENT_CODEX" = true ] && ! have codex; then
  say "OpenAI Codex CLI"
  npmg @openai/codex || { [ "$OS" = macos ] && have brew && brew install --cask codex; } \
    || warn "install codex manually: npm i -g @openai/codex (or brew install --cask codex on macOS)"
fi

install_dolt   # Beads needs the dolt binary (runs a dolt sql-server)
have bd     || { say "beads (bd)"; npmg @beads/bd || { have go && go install github.com/steveyegge/beads/cmd/bd@latest; } || warn "install beads manually: https://github.com/steveyegge/beads"; }
# Ralph loop (open-ralph-wiggum) - agent-agnostic, works with whichever CLI(s) are enabled above
have ralph  || { install_bun; say "ralph-wiggum (Ralph loop)"; npmg @th0rgal/ralph-wiggum; }
have jq     || { say "jq"; if have brew; then brew install jq; elif [ "$OS" = windows ]; then { have winget && winget install --id jqlang.jq -e; } || { have scoop && scoop install jq; } || warn "install jq: https://jqlang.github.io/jq/"; elif [ "$OS" = linux ]; then (sudo apt-get install -y jq || sudo dnf install -y jq) 2>/dev/null; else warn "install jq: https://jqlang.github.io/jq/"; fi; }
install_vcs_cli  # gh or glab to match the configured VCS host

# ---- optional (only if enabled) ----
[ "$TM" = true ]     && ! have task-master && { say "claude-task-master"; npmg task-master-ai; }
[ "$ROUTER" = true ] && ! have ccr         && { say "claude-code-router"; npmg @musistudio/claude-code-router; }
[ "$RTK" = true ]    && ! have rtk         && install_rtk
if [ "$GFY" = true ] && ! have graphify; then install_uv; say "graphify"; uv tool install graphifyy 2>/dev/null && graphify install 2>/dev/null || warn "install graphify manually: uv tool install graphifyy && graphify install"; fi
# cocoindex-code (semantic RAG code search; 'ccc' CLI + MCP; local embeddings, no API key)
if [ "$COCO" = true ] && ! have ccc; then
  install_uv; say "cocoindex-code (ccc)"
  uv tool install 'cocoindex-code[full]' 2>/dev/null \
    || { have pipx && pipx install 'cocoindex-code[full]'; } \
    || warn "install cocoindex-code manually: uv tool install 'cocoindex-code[full]'  (or pipx)"
fi
if { [ "$ALL" = 1 ] || [ "$OLLAMA" = true ]; }; then install_ollama; [ "$OLLAMA" = true ] && [ -f .aiflow/config.json ] && bash "$(dirname "${BASH_SOURCE[0]}")/ollama.sh" pull 2>/dev/null || true; fi

# ---- never auto-installed ----
# A container engine is optional: the GitHub MCP and the headless Ralph container (docker/run.sh)
# work with EITHER Podman or Docker. Install one yourself if you want them.
{ have podman || have docker; } || warn "No container engine (Podman or Docker) found — needed for the GitHub MCP and headless container runs. Install Podman (https://podman.io) or Docker Desktop (https://www.docker.com/products/docker-desktop/)."

# re-apply so newly installed tools get wired (rtk hook etc.)
[ -f .aiflow/config.json ] && bash "$(dirname "${BASH_SOURCE[0]}")/apply.sh" >/dev/null 2>&1 || true
echo
echo "Done. Verify with: aiflow doctor"
