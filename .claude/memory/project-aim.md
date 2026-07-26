# Project aim
**Goal:** aiflow: one command turns any repo into a governed, AI-driven delivery pipeline, agent-agnostic across Claude Code/Copilot/Codex CLI (Beads + graph/RAG memory + agents + gitflow release automation + team sync).

**Target architecture:** POSIX bash CLI (bin/aiflow, aiflow.ps1) + lib/*.sh. init/change-settings run interactive Q&A -> write .aiflow/config.json -> apply.sh renders per-agent MCP config (.mcp.json/.codex/.vscode), git hooks, memory, router-config, team-prefs, bd-close-sync, release-workflows. Everything project-scoped; secrets only in .env.

(Keep this current. Agents read it every session. Detailed view: docs/architecture/.)
