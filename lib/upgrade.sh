#!/usr/bin/env bash
# aiflow upgrade - update the bundled toolchain to latest (deps, not aiflow itself).
# Best-effort: each tool guarded; skips what isn't installed.
set -uo pipefail
have() { command -v "$1" >/dev/null 2>&1; }
step() { echo ">> $*"; }

if have npm; then
  step "npm globals (claude-code, task-master-ai, claude-code-router)"
  npm install -g @anthropic-ai/claude-code@latest @musistudio/claude-code-router@latest task-master-ai@latest 2>/dev/null || true
fi

if have uv; then
  step "graphify (uv)"; uv tool upgrade graphifyy 2>/dev/null || uv tool install graphifyy 2>/dev/null || true
fi

if have bd; then
  step "beads (bd)"; bd version >/dev/null 2>&1 || true
  bd self-update 2>/dev/null || bd update 2>/dev/null || echo "  (update bd via its installer if needed)"
fi

if have rtk; then step "rtk"; rtk upgrade 2>/dev/null || rtk update 2>/dev/null || echo "  (update rtk via its installer)"; fi

# claude-code-templates is always run via npx@latest -> nothing to pin.
step "rebuild graphify graph (if enabled)"
if [ -f .aiflow/config.json ] && have jq && [ "$(jq -r '.graphify.enabled' .aiflow/config.json)" = true ] && have graphify; then
  graphify build . >/dev/null 2>&1 || true
fi

step "re-applying project config"
[ -f .aiflow/config.json ] && bash "$(dirname "${BASH_SOURCE[0]}")/apply.sh" || true
echo "upgrade done. Run 'aiflow doctor' to verify versions."
