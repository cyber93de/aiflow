#!/usr/bin/env bash
# SessionStart hook: caveman terse-output mode, driven by .aiflow/config.json.
# enabled + mode (full|lite|ultra) come from config; full is the recommended default.
CFG=".aiflow/config.json"
ON=true; MODE=full
if command -v jq >/dev/null 2>&1 && [ -f "$CFG" ]; then
  ON="$(jq -r '.caveman.enabled // true' "$CFG")"
  MODE="$(jq -r '.caveman.mode // "full"' "$CFG")"
fi
[ "${AIFLOW_CAVEMAN:-}" = "off" ] && ON=false
[ "$ON" = "true" ] || exit 0

base='CAVEMAN MODE ACTIVE — communicate terse. Code, commits, PRs, security warnings: NORMAL prose. Persists until "stop caveman".'
case "$MODE" in
  lite)  echo "$base (lite) Trim filler/pleasantries, keep articles + full sentences." ;;
  ultra) echo "$base (ultra) Maximal compression: telegraphic, symbols ok, minimal words." ;;
  *)     echo "$base (full) Drop articles (a/an/the), filler, hedging. Fragments OK. Short synonyms." ;;
esac
exit 0
