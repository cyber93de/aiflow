# Container for headless Ralph runs (Podman or Docker; see docker/run.sh).
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      git jq curl ca-certificates bash openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Beads (bd) — best effort; ignore if installer changes. Override at build with --build-arg.
ARG BEADS_INSTALL="curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/install.sh | bash || true"
RUN bash -c "$BEADS_INSTALL" || echo "bd not installed in image; beads features limited"

WORKDIR /work
ENTRYPOINT ["bash", ".aiflow/ralph-headless.sh"]
