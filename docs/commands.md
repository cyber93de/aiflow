---
layout: default
title: Command reference
parent: CLI & Configuration
nav_order: 1
description: "aiflow CLI command reference: init, install-deps, change-settings, shell, sync, close-sync, ollama, index, ralph, onboard, audits, release, doctor, update, project-update."
---

# Command reference
{: .no_toc }

1. TOC
{:toc}

---

## Setup & config

| Command | Does |
|---------|------|
| `aiflow init [path] [--force] [--no-git] [--no-beads] [--yes] [--no-token-saving]` | Bootstrap a project (interactive Q&A → renders everything). `--no-token-saving` = caveman + rtk off (full, unfiltered output). |
| `aiflow install-deps [--all]` | Install missing tools enabled in config (`--all` = full set). |
| `aiflow change-settings [--no-token-saving]` | Re-adjust config, then re-render `.mcp.json`, hooks, branching, memory. `--no-token-saving` switches caveman + rtk off. |
| `aiflow doctor` | Check prerequisites + print a per-project summary. |
| `aiflow upgrade` | Update the bundled toolchain. |
| `aiflow update` | Self-update the aiflow install itself (`git pull` in `AIFLOW_HOME`) to the latest release. |
| `aiflow project-update` | Refresh THIS project's mechanical scripts (`.aiflow/*`, `.claude/hooks/*`, `docker/run.*`) from the installed templates and re-apply config. Never touches `CLAUDE.md`, agents, docs, or your own config. You're prompted for this automatically when a project's stamped version falls behind the installed CLI. |
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
| `aiflow a11y-check` | Strict WCAG 2.2 AA accessibility audit → `[accessibility]`. |
| `aiflow modernize-check` | Brownfield modernisation concepts → report for the architect (`.aiflow/modernization-report.md`). |

## Release

| Command | Does |
|---------|------|
| `aiflow release [--push]` | Cut a release per the branching model (version bump + tag). |
| `aiflow protect` | Apply server-side branch protection (GitHub). |
| `aiflow cost [...]` | Token/cost baseline via ccusage. |

All commands are project-scoped and read `.aiflow/config.json` + `.env` in the current project.
