#!/usr/bin/env bash
# aiflow ollama - manage local Ollama models from .aiflow/config.json.
# Subcommands:
#   pull            pull every model listed in config (.ollama.models)
#   add <model>     add a model to config and pull it
#   list            list installed models
#   models          print the configured models
# Local models need no API key. They are wired into claude-code-router by apply.sh
# so easy/background tasks actually route to them (aiflow shell --router).
set -uo pipefail

CFG=".aiflow/config.json"
have() { command -v "$1" >/dev/null 2>&1; }
j() { have jq && [ -f "$CFG" ] && jq -r "$1 // empty" "$CFG" 2>/dev/null; }

URL="$(j '.ollama.url')"; [ -z "$URL" ] && URL="http://localhost:11434"

ensure_ollama() {
  if ! have ollama; then
    echo ">> installing ollama"
    case "$(uname -s 2>/dev/null)" in
      Darwin) have brew && brew install ollama || echo "  install ollama: https://ollama.com/download" ;;
      MINGW*|MSYS*|CYGWIN*)
        have winget && winget install --id Ollama.Ollama -e \
          || { have scoop && scoop install ollama; } \
          || echo "  install ollama: https://ollama.com/download" ;;
      *) curl -fsSL https://ollama.com/install.sh | sh || echo "  install ollama: https://ollama.com/download" ;;
    esac
  fi
  have ollama || { echo "  ! ollama not available; skipping"; return 1; }
  # start the daemon if it isn't answering
  curl -fsS "$URL/api/tags" >/dev/null 2>&1 || { (ollama serve >/dev/null 2>&1 &) ; sleep 2; }
}

models_from_cfg() { j '.ollama.models[]'; }

cmd="${1:-pull}"; shift || true
case "$cmd" in
  models) models_from_cfg ;;
  list)   ensure_ollama && ollama list ;;
  add)
    [ -n "${1:-}" ] || { echo "usage: aiflow ollama add <model>" >&2; exit 2; }
    have jq || { echo "jq required" >&2; exit 1; }
    tmp="$(mktemp)"; jq --arg m "$1" '.ollama.enabled=true | .ollama.models=((.ollama.models // []) + [$m] | unique)' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
    echo "  added $1 to $CFG"
    ensure_ollama && ollama pull "$1"
    bash "$(dirname "${BASH_SOURCE[0]}")/apply.sh" >/dev/null 2>&1 || true
    ;;
  pull)
    mapfile -t MODELS < <(models_from_cfg)
    [ "${#MODELS[@]}" -eq 0 ] && { echo "  no ollama models in $CFG (add with: aiflow ollama add <model>)"; exit 0; }
    ensure_ollama || exit 0
    for m in "${MODELS[@]}"; do
      [ -z "$m" ] && continue
      echo ">> ollama pull $m"
      ollama pull "$m" || echo "  ! failed to pull $m"
    done
    ;;
  *) echo "usage: aiflow ollama [pull|add <model>|list|models]" >&2; exit 2 ;;
esac
