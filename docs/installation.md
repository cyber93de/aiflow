---
layout: default
title: Installation
parent: Getting Started
nav_order: 1
description: "Install aiflow on Linux, macOS, or Windows for Claude Code. The installer offers git, Subversion (svn), and Ollama; then aiflow install-deps fetches the toolchain."
---

# Installation
{: .no_toc }

1. TOC
{:toc}

---

## Prerequisites

[Node.js](https://nodejs.org) (LTS). Everything else — Claude Code, Beads, Dolt, jq, graphify,
cocoindex-code, Ollama — aiflow can install for you.

## Clone

```bash
git clone https://github.com/Cyber93de/aiflow.git
cd aiflow
```

## Linux / macOS / Git-Bash

```bash
bash install.sh          # symlinks 'aiflow' onto your PATH
```

## Windows (PowerShell)

```powershell
./install.ps1            # adds bin to PATH + creates the aiflow shim
```

The installer **asks once** whether to also install **git**, **Subversion (svn)**, and **Ollama**
(via winget/scoop on Windows, Homebrew on macOS, the system package manager or official scripts on
Linux). That way a later `aiflow init` only has to ask *which* Ollama models to pull.

## Install the toolchain

```bash
aiflow doctor               # what's present / missing (+ per-project summary)
aiflow install-deps --all   # install the full toolchain (or run 'aiflow init', which offers it)
```

`install-deps` installs only what your project config enables; `--all` installs everything. It is
user-space and never installs a container engine — install **Podman or Docker** yourself if you want
the GitHub MCP or headless container runs.

## Packaged builds

Prebuilt archives (Linux/macOS/Windows) are attached to each
[GitHub release](https://github.com/Cyber93de/aiflow/releases).

## Next

- [Quick Start](getting-started) — build your first project.
- [Command reference](commands) · [Configuration](configuration)
