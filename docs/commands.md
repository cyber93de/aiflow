---
layout: default
title: Command reference
parent: CLI & Configuration
nav_order: 1
description: "aiflow CLI command reference: init, install-deps, change-settings, shell, sync, close-sync, ollama, index, ralph, onboard, audits, release, doctor."
---

# Command reference
{: .no_toc }

1. TOC
{:toc}

---

## Setup & config

| Command | Does |
|---------|------|
| `aiflow init [path] [--force] [--no-git] [--no-beads] [--yes]` | Bootstrap a project (interactive Q&A → renders everything). |
| `aiflow install-deps [--all]` | Install missing tools enabled in config (`--all` = full set). |
| `aiflow change-settings` | Re-adjust config, then re-render `.mcp.json`, hooks, branching, memory. |
| `aiflow doctor` | Check prerequisites + print a per-project summary. |
| `aiflow upgrade` | Update the bundled toolchain. |
| `aiflow version` | Print the version. |

## Working

| Command | Does |
|---------|------|
| `aiflow shell [--router]` | Load `.env`, launch Claude Code (`--router` = cheap/local models). |
| `aiflow index` | Refresh code memory: graphify (graph) + cocoindex (RAG). |
| `aiflow ralph "<prompt|bead id>"` | Run the headless Ralph loop. |
| `aiflow onboard` | Learn an existing codebase into memory + CLAUDE.md + arc42. |
| `aiflow ollama [pull\|add <m>\|list]` | Manage local Ollama models. |

## Team sync

| Command | Does |
|---------|------|
| `aiflow sync [pull\|push\|both]` | Team sync: git + Beads(dolt) pull/push (default pull at start). |
| `aiflow close-sync <id>` | On issue close: prompt to push + Dolt-sync (pulls before pushing). |

## Audits (file Beads issues)

| Command | Does |
|---------|------|
| `aiflow security-check` | Security audit → `[security-advisor]` issues. |
| `aiflow quality-check` | Refactoring/quality audit → `[technical issue]`. |
| `aiflow requirements-check` | Advisory grade of issue quality (report only). |
| `aiflow dependency-check` | Vulns/outdated/unused/license → `[dependency]`. |
| `aiflow test-gap` | Untested critical paths → `[test gap]`. |
| `aiflow perf-check` | Performance hotspots → `[performance]`. |
| `aiflow docs-check` | Doc/code drift → `[docs]`. |

## Release

| Command | Does |
|---------|------|
| `aiflow release [--push]` | Cut a release per the branching model (version bump + tag). |
| `aiflow protect` | Apply server-side branch protection (GitHub). |
| `aiflow cost [...]` | Token/cost baseline via ccusage. |

All commands are project-scoped and read `.aiflow/config.json` + `.env` in the current project.
