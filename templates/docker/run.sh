#!/usr/bin/env bash
# Run the headless Ralph loop in a local container — works with Podman OR Docker.
# Usage: docker/run.sh "<prompt or bead id>"
#   Override the engine with AIFLOW_CONTAINER=podman|docker
set -euo pipefail
[ -f .env ] && { set -a; source .env; set +a; }

PROMPT="${*:?usage: docker/run.sh \"<prompt>\"}"
IMG="aiflow-ralph:local"

# pick a container engine: explicit override, else podman, else docker
ENGINE="${AIFLOW_CONTAINER:-}"
if [ -z "$ENGINE" ]; then
  if command -v podman >/dev/null 2>&1; then ENGINE=podman
  elif command -v docker >/dev/null 2>&1; then ENGINE=docker
  else echo "Need Podman or Docker. Install one, or set AIFLOW_CONTAINER." >&2; exit 1; fi
fi
command -v "$ENGINE" >/dev/null 2>&1 || { echo "$ENGINE not found on PATH" >&2; exit 1; }

echo ">> using container engine: $ENGINE"
"$ENGINE" build -t "$IMG" -f docker/Dockerfile .
"$ENGINE" run --rm -it \
  -v "$PWD:/work:z" \
  -e ANTHROPIC_API_KEY -e CLAUDE_CODE_OAUTH_TOKEN -e GITHUB_TOKEN \
  -e RALPH_MAX_ITERATIONS -e RALPH_TIMEOUT_SECONDS -e RALPH_PERMISSION_MODE \
  "$IMG" "$PROMPT"
