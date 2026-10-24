---
layout: default
title: Multi-Agent Support
parent: Agents & Workflows
nav_order: 3
description: "Shared aiflow project rules, portable skills, per-agent MCP configuration, token controls, and current differences between Claude Code, Codex, and GitHub Copilot."
---

# Multi-agent support
{: .no_toc }

1. TOC
{:toc}

---

aiflow keeps project policy and reusable knowledge portable, then writes native configuration for
the agents selected in `.aiflow/config.json`. This gives each agent the same engineering rules and
skills, while tool-specific features remain explicit instead of pretending every integration is
identical.

## Shared foundation

`AGENTS.md` is the canonical project instruction file. It contains architecture and quality rules,
task flow, branching policy, token-saving practices, and the definition of done. Claude Code loads
it through the generated `CLAUDE.md` pointer; Codex reads it natively; GitHub Copilot is pointed to
it by `.github/copilot-instructions.md`.

Reusable checklists live in `.agents/skills/<name>/SKILL.md`. aiflow mirrors these to
`.claude/skills/` for Claude Code. Codex, Copilot, and Claude Code support skills, but the exact
matching and invocation behavior depends on each agent and version. The files remain plain Markdown
with YAML frontmatter so an agent can also read them directly.

## Native integration coverage

| Agent | Generated project files | Native workflow automation |
|---|---|---|
| Claude Code | `.mcp.json`, `.claude/agents/`, `.claude/commands/`, `.claude/skills/`, hooks | Specialist subagents, commands, hooks and model routing |
| Codex CLI | `.codex/config.toml`, shared `AGENTS.md` and `.agents/skills/` | Shared instructions and skills; use Codex's own subagent support where available |
| GitHub Copilot in VS Code | `.vscode/mcp.json`, `.github/copilot-instructions.md`, shared skills | Shared instructions and skills; Copilot's native agents and hooks are not yet rendered by aiflow |

Enable the agents you use with `aiflow init` or `aiflow change-settings`. aiflow renders one logical
MCP selection into each enabled agent's native format. For Codex, use `aiflow codex` when credentials
are in the project `.env`; it loads the environment before launching Codex. VS Code MCP tokens use
secure input prompts rather than storing secret values in the generated JSON.

## Skills, roles, loops, and hooks

Skills hold reusable domain knowledge and task checklists. Agent profiles hold role, authority, and
handoff instructions. The full specialist role roster and its automated dispatch currently belong
to Claude Code under `.claude/agents/`; `AGENTS.md` carries the common workflow for every agent.
Codex can delegate through its native subagents, while Copilot has its own custom-agent surface,
but aiflow does not yet generate equivalent role profiles for those tools. Do not assume Claude
commands, hooks, or model-routing metadata are portable.

The headless `aiflow ralph` loop is agent-agnostic through its configured `--agent` runner. Claude
Code also has interactive command/hook flows. Other agents follow the shared task and quality gates
through their native session workflow; Claude's hooks are not silently represented as cross-agent
automation.

## Token savings

All agents inherit the same baseline: keep `AGENTS.md` concise, load only the relevant skill, inspect
targeted files, use focused MCPs only when enabled, and avoid repeating repository context. The
generated instruction files encourage bounded output and stable tools/models per session.

Claude Code can additionally use RTK output filtering and its model routing for specialist agents;
Caveman is an optional Claude-specific terse-output tool. CodexSaver is optional for Codex and off by
default. Copilot gets the shared concise instructions and skill discovery; Claude-only filters and
CodexSaver are not activated for it. Large-project retrieval add-ons such as Graphify and
CocoIndex are opt-in to limit context and tool overhead on smaller repositories.

## MCP choices

The default keeps the MCP set small: the selected git-host integration and Context7 (when configured)
are available; filesystem, Graphify, CocoIndex, Task Master, and GitKraken are opt-in. See
[MCP servers](mcp-servers) for uses, requirements, and settings. Prefer a skill for stable knowledge
or a checklist; add an MCP when an agent needs a live external system or a genuinely useful tool.

## Branches and release flow

The shared gitflow rules and CI apply no matter which agent edits the code. Feature work merges into
`develop`; release preparation promotes `develop` to `main`. Normal work follows that workflow and
does not create a separate “aiflow release” task. See [Workflows & CI/CD](workflows).
