#!/usr/bin/env bash
# PostToolUse hook: auto-format the edited file in Google style if a formatter exists.
# Receives Claude Code tool JSON on stdin. Never blocks; exits 0 on anything.
set -uo pipefail

input="$(cat)"
# extract file_path from tool_input (jq if present, else grep)
if command -v jq >/dev/null 2>&1; then
  f="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
else
  f="$(printf '%s' "$input" | grep -o '"file_path"[^,}]*' | head -n1 | sed 's/.*: *"//; s/"$//')"
fi
[ -z "${f:-}" ] && exit 0
[ -f "$f" ] || exit 0

have() { command -v "$1" >/dev/null 2>&1; }

case "$f" in
  *.py)              have black && black -q "$f"; have isort && isort -q "$f" ;;
  *.js|*.jsx|*.ts|*.tsx|*.json|*.css|*.md|*.yaml|*.yml) have prettier && prettier --write --log-level error "$f" ;;
  *.go)              have gofmt && gofmt -w "$f"; have goimports && goimports -w "$f" ;;
  *.java)            have google-java-format && google-java-format -i "$f" ;;
  *.dart)            have dart && dart format "$f" >/dev/null 2>&1 ;;
  *.c|*.cc|*.cpp|*.h|*.hpp) have clang-format && clang-format -i --style=Google "$f" ;;
  *.sh)              have shfmt && shfmt -w -i 2 "$f" ;;
esac
exit 0
