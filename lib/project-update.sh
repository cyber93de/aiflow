#!/usr/bin/env bash
# aiflow project-update - refresh THIS project's aiflow-generated mechanical scripts
# (.aiflow/*.sh+ps1, .claude/hooks/*.sh+ps1, docker/run.sh+ps1) from the installed aiflow
# templates, then re-apply config. Never touches CLAUDE.md, agents, docs, or your own config.
set -uo pipefail

AIFLOW_HOME="${AIFLOW_HOME:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TPL="$AIFLOW_HOME/templates"
CFG=".aiflow/config.json"
[ -f "$CFG" ] || { echo "no $CFG - run 'aiflow init' first" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

echo ">> aiflow project-update: refreshing mechanical scripts from templates..."
mkdir -p .aiflow .claude/hooks docker
shopt -s nullglob
for f in "$TPL"/.aiflow/*.sh "$TPL"/.aiflow/*.ps1; do cp -f "$f" ".aiflow/$(basename "$f")"; done
for f in "$TPL"/.claude/hooks/*.sh "$TPL"/.claude/hooks/*.ps1; do cp -f "$f" ".claude/hooks/$(basename "$f")"; done
for f in "$TPL"/docker/run.sh "$TPL"/docker/run.ps1; do cp -f "$f" "docker/$(basename "$f")"; done
shopt -u nullglob
chmod +x .aiflow/*.sh .claude/hooks/*.sh docker/*.sh 2>/dev/null || true
echo "   scripts refreshed"

bash "$AIFLOW_HOME/lib/apply.sh"

NEW_VER="$(cat "$AIFLOW_HOME/VERSION" 2>/dev/null || echo 0.0.0)"
TMP="$(mktemp)"
jq --arg v "$NEW_VER" '.meta.aiflowVersion = $v' "$CFG" > "$TMP" && mv "$TMP" "$CFG"
echo ">> project-update done. Stamped .aiflow/config.json meta.aiflowVersion=$NEW_VER"
