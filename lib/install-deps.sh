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
# CodexSaver needs a paid provider API key - never auto-enabled by --all, config opt-in only
CODEXSAVER="$(cfg .codexsaver.enabled false)"
CODEXSAVER_PROVIDER="$(cfg .codexsaver.provider deepseek)"
CODEXSAVER_KEYENV="$(cfg .codexsaver.apiKeyEnv DEEPSEEK_API_KEY)"

npmg() { # install a global npm package, retry with sudo on permission error
  have npm || { warn "npm not found - install Node.js first (https://nodejs.org)"; return 1; }
  npm install -g "$1" 2>/dev/null || sudo npm install -g "$1" 2>/dev/null || { warn "failed: npm i -g $1"; return 1; }
}

# ---- Windows: PATH + native toolchain -------------------------------------------------
# winget/scoop write the new binary's directory into the *registry* PATH; the already-running
# shell never sees it, so a tool installed two lines up looks "missing" to the next check and
# to 'aiflow doctor' (aiflow-sx6). Rebuild the process PATH from Machine+User after each such
# install. Track what still isn't visible so we can tell the user at the end.
NEEDS_RESTART=""
refresh_path() {
  [ "$OS" = windows ] || return 0
  local winpath
  winpath="$(powershell.exe -NoProfile -NonInteractive -Command \
    '[Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH","User")' \
    2>/dev/null | tr -d '\r')" || return 0
  [ -z "$winpath" ] && return 0
  # Windows PATH -> POSIX PATH for the Git-Bash process we're running in. cygpath ships with
  # Git for Windows and handles the whole ';'-separated list, drive letters and spaces included.
  have cygpath || return 0
  local posixpath
  posixpath="$(cygpath -up "$winpath" 2>/dev/null)"
  [ -n "$posixpath" ] && export PATH="$PATH:$posixpath"
}
# Install via winget/scoop, then make the result usable in THIS session.
win_pkg() { # win_pkg <cmd> <winget-id> <scoop-name>
  if have winget; then winget install --id "$2" -e --source winget --accept-source-agreements --accept-package-agreements >/dev/null 2>&1
  elif have scoop; then scoop install "$3" >/dev/null 2>&1
  else return 1; fi
  refresh_path
  have "$1" || NEEDS_RESTART="$NEEDS_RESTART $1"
  return 0
}
# WSL is where native code gets compiled on Windows - never MinGW/MSYS2 (aiflow-sq3).
wsl_ready() { [ "$OS" = windows ] && have wsl.exe && wsl.exe -e true >/dev/null 2>&1; }
ensure_build_toolchain() { # only called when something actually needs a C/C++ compiler
  case "$OS" in
    windows)
      if wsl_ready; then
        if wsl.exe -e sh -c 'command -v g++ >/dev/null' >/dev/null 2>&1; then return 0; fi
        say "installing build-essential inside WSL (native builds do NOT use MinGW)"
        wsl.exe -e sh -c 'sudo apt-get update -qq && sudo apt-get install -y build-essential' \
          || warn "run inside WSL: sudo apt update && sudo apt install -y build-essential"
      else
        warn "no WSL - native builds need it. Admin PowerShell: wsl --install  then  wsl --install -d Ubuntu"
        warn "do NOT install MinGW/MSYS2 for this: https://cyber93de.github.io/aiflow/installation#windows-prerequisites-do-this-first"
        return 1
      fi ;;
    linux)  have cc || have gcc || { say "build tools"; (sudo apt-get install -y build-essential || sudo dnf groupinstall -y "Development Tools") 2>/dev/null || warn "install a C/C++ toolchain"; } ;;
    macos)  have cc || xcode-select --install 2>/dev/null || warn "install the Xcode command line tools: xcode-select --install" ;;
  esac
}
install_uv() {
  have uv && return 0
  say "installing uv (for graphify / cocoindex-code)"
  if [ "$OS" = windows ]; then powershell -NoProfile -c "irm https://astral.sh/uv/install.ps1 | iex" || warn "install uv manually: https://docs.astral.sh/uv/";
  else curl -LsSf https://astral.sh/uv/install.sh | sh || warn "install uv manually: https://docs.astral.sh/uv/"; fi
  # uv drops itself into one of these; a fresh install is otherwise invisible to this shell.
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  [ "$OS" = windows ] && { export PATH="$HOME/.local/bin:$PATH"; refresh_path; }
  have uv || { warn "uv still not on PATH after install - open a new shell, or add ~/.local/bin to PATH"; return 1; }
}
install_rtk() {
  # rtk-ai/rtk. Verify afterwards instead of assuming: the piped installer fails silently often
  # enough that users ended up installing it by hand from the repo (aiflow-3ds).
  say "installing rtk"
  if have brew; then brew install rtk >/dev/null 2>&1; fi
  have rtk || curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  refresh_path
  # the installer puts rtk in one of these before any shell rc is re-read
  export PATH="$HOME/.rtk/bin:$HOME/.local/bin:$PATH"
  if ! have rtk; then
    warn "rtk install did not produce an 'rtk' on PATH. Get it from the repo:"
    warn "    https://github.com/rtk-ai/rtk        (clone + follow its README/install.sh)"
    warn "    docs: https://www.rtk-ai.app/docs/getting-started/installation/"
    return 1
  fi
}
install_graphify() {
  # PyPI package name is 'graphifyy' (two y's) - upstream repo: Graphify-Labs/graphify.
  # Both the uv install and the follow-up 'graphify install' used to be silenced, so a failure
  # looked like success and the user had to find the repo themselves (aiflow-zw8).
  install_uv || return 1
  say "graphify (structural code graph)"
  if ! uv tool install graphifyy; then
    warn "uv tool install graphifyy failed - retrying from the upstream repo"
    uv tool install "git+https://github.com/Graphify-Labs/graphify" || {
      warn "install graphify manually: https://github.com/Graphify-Labs/graphify"
      warn "    uv tool install graphifyy   ||   uv tool install git+https://github.com/Graphify-Labs/graphify"
      return 1
    }
  fi
  export PATH="$HOME/.local/bin:$PATH"
  have graphify || { warn "graphify installed but not on PATH - add ~/.local/bin (uv tool dir) to PATH"; return 1; }
  graphify install || warn "'graphify install' failed - run it manually once"
}
install_dolt() { # Beads backend (bd runs a dolt sql-server)
  have dolt && return 0
  say "installing dolt (Beads database backend)"
  if have brew; then brew install dolt
  elif [ "$OS" = windows ]; then
    win_pkg dolt DoltHub.Dolt dolt || warn "install dolt manually: https://docs.dolthub.com/introduction/installation"
  else sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash' || warn "install dolt: https://docs.dolthub.com/introduction/installation"; fi
}
install_vcs_cli() {
  # remote host: new schema .remote.type, fallback to legacy string .vcs
  local rt; rt="$(cfg .remote.type '')"; [ -z "$rt" ] && rt="$(cfg .vcs github)"
  case "$rt" in
    github)  have gh   || { say "GitHub CLI"; if have brew; then brew install gh
                            elif [ "$OS" = windows ]; then win_pkg gh GitHub.cli gh || warn "install gh: https://cli.github.com"
                            else (sudo apt-get install -y gh) 2>/dev/null || warn "install gh: https://cli.github.com"; fi; } ;;
    gitlab)  have glab || { say "GitLab CLI"; if have brew; then brew install glab
                            elif [ "$OS" = windows ]; then win_pkg glab glab.glab glab || warn "install glab: https://gitlab.com/gitlab-org/cli"
                            else warn "install glab: https://gitlab.com/gitlab-org/cli"; fi; } ;;
    custom)  say "custom remote ($(cfg .remote.baseUrl '')): using git + token in \$$(cfg .remote.tokenEnv GIT_REMOTE_TOKEN); no host CLI auto-installed" ;;
    none)    : ;;
  esac
}
install_ollama() {
  have ollama && return 0
  say "installing ollama (local models)"
  case "$OS" in
    macos)   have brew && brew install ollama || warn "install ollama: https://ollama.com/download" ;;
    windows) win_pkg ollama Ollama.Ollama ollama || warn "install ollama: https://ollama.com/download" ;;
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
install_codexsaver() { # cost-aware MCP router for Codex CLI - no PyPI package, editable install
  # from source. Global by design (its own README): one clone shared across projects, like the
  # tool itself recommends. We never touch its own ~/.codex/config.toml write; our own
  # .codex/config.toml (in apply.sh) just points at the stable script path it installs.
  have codexsaver && return 0
  { have python3 || have python; } || { warn "CodexSaver needs Python - install it first: https://python.org"; return 1; }
  PY=python3; have python3 || PY=python
  say "installing CodexSaver (cost-aware Codex CLI router)"
  local dir="$HOME/.local/share/aiflow/codexsaver"
  if [ -d "$dir/.git" ]; then (cd "$dir" && git pull -q) || true
  else mkdir -p "$(dirname "$dir")"; git clone -q https://github.com/fendouai/CodexSaver "$dir" || { warn "clone failed: https://github.com/fendouai/CodexSaver"; return 1; }
  fi
  (cd "$dir" && "$PY" -m pip install -q -e .) || { warn "pip install -e . failed in $dir"; return 1; }
  npmg @earendil-works/pi-coding-agent
  if [ -n "${!CODEXSAVER_KEYENV:-}" ]; then
    codexsaver auth set --provider "$CODEXSAVER_PROVIDER" --api-key "${!CODEXSAVER_KEYENV}" 2>/dev/null \
      || warn "codexsaver auth set failed - run manually: codexsaver auth set --provider $CODEXSAVER_PROVIDER --api-key ..."
  else
    warn "CodexSaver installed but no key in \$$CODEXSAVER_KEYENV - run: codexsaver auth set --provider $CODEXSAVER_PROVIDER --api-key ..."
  fi
  codexsaver install 2>/dev/null || warn "run 'codexsaver install' manually to finish global setup"
}

echo "aiflow install-deps (os=$OS, all=$ALL)"
echo "  enabled: rtk=$RTK task-master=$TM router=$ROUTER graphify=$GFY cocoindex=$COCO ollama=$OLLAMA"
echo "  coding agent(s): claude=$AGENT_CLAUDE copilot=$AGENT_COPILOT codex=$AGENT_CODEX codexsaver=$CODEXSAVER"

# ---- coding agent CLIs (per agents.* config) ----
[ "$AGENT_CLAUDE" = true ]  && ! have claude  && { say "Claude Code"; npmg @anthropic-ai/claude-code; }
[ "$AGENT_COPILOT" = true ] && ! have copilot && { say "GitHub Copilot CLI"; npmg @github/copilot; }
if [ "$AGENT_CODEX" = true ] && ! have codex; then
  say "OpenAI Codex CLI"
  npmg @openai/codex || { [ "$OS" = macos ] && have brew && brew install --cask codex; } \
    || warn "install codex manually: npm i -g @openai/codex (or brew install --cask codex on macOS)"
fi
[ "$AGENT_CODEX" = true ] && [ "$CODEXSAVER" = true ] && install_codexsaver

install_dolt   # Beads needs the dolt binary (runs a dolt sql-server)
have bd     || { say "beads (bd)"; npmg @beads/bd || { have go && go install github.com/steveyegge/beads/cmd/bd@latest; } || warn "install beads manually: https://github.com/steveyegge/beads"; }
# Ralph loop (open-ralph-wiggum) - agent-agnostic, works with whichever CLI(s) are enabled above
have ralph  || { install_bun; say "ralph-wiggum (Ralph loop)"; npmg @th0rgal/ralph-wiggum; }
have jq     || { say "jq"; if have brew; then brew install jq; elif [ "$OS" = windows ]; then win_pkg jq jqlang.jq jq || warn "install jq: https://jqlang.github.io/jq/"; elif [ "$OS" = linux ]; then (sudo apt-get install -y jq || sudo dnf install -y jq) 2>/dev/null; else warn "install jq: https://jqlang.github.io/jq/"; fi; }
install_vcs_cli  # gh or glab to match the configured VCS host

# ---- optional (only if enabled) ----
[ "$TM" = true ]     && ! have task-master && { say "claude-task-master"; npmg task-master-ai; }
[ "$ROUTER" = true ] && ! have ccr         && { say "claude-code-router"; npmg @musistudio/claude-code-router; }
[ "$RTK" = true ]    && ! have rtk         && install_rtk
[ "$GFY" = true ]    && ! have graphify    && install_graphify
# cocoindex-code (semantic RAG code search; 'ccc' CLI + MCP; local embeddings, no API key).
# Builds native wheels -> needs a C/C++ toolchain, which on Windows means WSL, never MinGW.
if [ "$COCO" = true ] && ! have ccc; then
  install_uv && { ensure_build_toolchain || warn "cocoindex-code may fail to build without a C/C++ toolchain"; }
  say "cocoindex-code (ccc)"
  uv tool install 'cocoindex-code[full]' \
    || { have pipx && pipx install 'cocoindex-code[full]'; } \
    || warn "install cocoindex-code manually: uv tool install 'cocoindex-code[full]'  (or pipx)"
  export PATH="$HOME/.local/bin:$PATH"
  have ccc || warn "cocoindex-code installed but 'ccc' is not on PATH - add the uv tool dir (~/.local/bin)"
fi
if { [ "$ALL" = 1 ] || [ "$OLLAMA" = true ]; }; then install_ollama; [ "$OLLAMA" = true ] && [ -f .aiflow/config.json ] && bash "$(dirname "${BASH_SOURCE[0]}")/ollama.sh" pull 2>/dev/null || true; fi

# ---- never auto-installed ----
# A container engine is optional: the GitHub MCP and the headless Ralph container (docker/run.sh)
# work with EITHER Podman or Docker. Install one yourself if you want them.
{ have podman || have docker; } || warn "No container engine (Podman or Docker) found — needed for the GitHub MCP and headless container runs. Install Podman (https://podman.io) or Docker Desktop (https://www.docker.com/products/docker-desktop/)."

# re-apply so newly installed tools get wired (rtk hook etc.)
[ -f .aiflow/config.json ] && bash "$(dirname "${BASH_SOURCE[0]}")/apply.sh" >/dev/null 2>&1 || true
echo
# Anything winget/scoop installed that a PATH refresh still couldn't surface only becomes
# usable in a NEW shell - say so instead of letting the next command report it as missing.
if [ -n "$NEEDS_RESTART" ]; then
  echo "  ! installed but not yet on this shell's PATH:$NEEDS_RESTART"
  echo "    Open a NEW terminal (VS Code: fully restart it) before running 'aiflow doctor'."
  echo
fi
echo "Done. Verify with: aiflow doctor"
