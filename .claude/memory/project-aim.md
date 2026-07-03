# Project aim
**Goal:** aiflow: one command turns any repo into a governed, AI-driven delivery pipeline (Claude Code + Beads + graph/RAG memory + agents + team sync).

**Target architecture:** POSIX bash CLI (bin/aiflow, aiflow.ps1) + lib/*.sh. init/change-settings run interactive Q&A -> write .aiflow/config.json -> apply.sh renders .mcp.json, git hooks, memory, router-config, team-prefs, bd-close-sync. Everything project-scoped; secrets only in .env.

(Keep this current. Agents read it every session. Detailed view: docs/architecture/.)
