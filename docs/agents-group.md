---
layout: default
title: Agents & Workflows
nav_order: 5
has_children: true
description: "aiflow's Claude Code agents (architect, planner, implementer, reviewer, tester, audit agents), the delivery workflow, branching models, Ralph loop, CI/CD, and multi-agent support for GitHub Copilot and OpenAI Codex CLI."
---

# Agents & Workflows

How work actually gets done:

- **[Agents](agents)** — the full roster: delivery agents (architect, planner, implementer,
  reviewer, tester), audit agents (security, quality, deps, tests, perf, docs), and the brownfield
  onboarder, plus slash-commands and auto-offered Skills (e.g. `seo-optimization`).
- **[Workflows & CI/CD](workflows)** — the delivery workflow, branching models (simple/gitflow),
  the autonomous **Ralph loop**, and the CI/CD + build/release pipelines.
- **[Multi-Agent Support](multi-agent)** — using aiflow with GitHub Copilot and OpenAI Codex CLI
  alongside (or instead of) Claude Code: the shared `AGENTS.md`, per-agent MCP config, and what
  stays Claude Code-only.
