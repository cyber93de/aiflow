---
layout: default
title: Troubleshooting
parent: Support
nav_order: 2
description: "Troubleshoot aiflow: jq/Beads/Dolt errors, MCP servers not starting, Ollama models unused, Dolt sync conflicts, git-host token mismatches, and container runs."
---

# Troubleshooting
{: .no_toc }

1. TOC
{:toc}

---

## `jq is required`
Install jq — `aiflow install-deps` does. aiflow reads/writes `.aiflow/config.json` with it.

## `bd` / Dolt errors
`aiflow install-deps` installs both Beads and Dolt. Check the server with `bd dolt status`. If the
embedded server won't start, `bd dolt start` (or restart your shell) and retry.

## An MCP server won't start
Run `aiflow doctor`. Confirm the underlying tool is installed:
- **cocoindex-code** → `ccc` (`uv tool install 'cocoindex-code[full]'`)
- **graphify** → `graphify` (`uv tool install graphifyy && graphify install`)
- **git-host MCP** → Podman or Docker running (GitHub MCP) and the token env in `.env` matches
  `remote.tokenEnv`.

## Ollama models are never used
Enable `router` and run `aiflow shell --router`. Confirm `.aiflow/router-config.json` lists your
models and `ollama list` has them locally (`aiflow ollama pull`).

## Dolt sync conflict (team)
`bd dolt pull` to merge, resolve, then `bd dolt push`. **Never force-push.** See
[Team collaboration](team).

## Wrong git host / token
Re-run `aiflow change-settings`; ensure `.env` has the variable named in `remote.tokenEnv`;
`aiflow doctor` prints the resolved remote + host MCP.

## Container run fails
Ensure **Podman or Docker** is installed and its daemon/machine is running. Force one with
`AIFLOW_CONTAINER=podman|docker docker/run.sh "<task>"`.

## `pre-push` blocks a push
That's the branching model. Use a proper branch/PR. See [Workflows](workflows).

Still stuck? Open an [issue](https://github.com/Cyber93de/aiflow/issues) with repro steps, your OS,
and the relevant `aiflow doctor` output.
