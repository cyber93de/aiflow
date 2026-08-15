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

## My project is on `master`, and the branching rules never apply
aiflow governs the mainline **by name**: `main`. `branching.json`, the `pre-push` hook,
`aiflow release` and `aiflow hotfix` all reference `main`, so a repo sitting on `master` is simply
ungoverned. Since 0.6.x, `aiflow init` forces `main` at `git init` time, and `aiflow apply` renames
an existing `master` → `main` and prints the remote-migration commands:

```bash
git push -u origin main
# switch the default branch to 'main' in your host's settings, then:
git push origin --delete master
```

If **both** `master` and `main` exist, aiflow refuses to touch either — merge or delete `master`
yourself, then re-run `aiflow apply`. To suppress the rename entirely: `AIFLOW_NO_BRANCH_RENAME=1`.

## A project's hooks/scripts feel out of date, or a fix in a new aiflow release isn't showing up
Two separate steps: `aiflow update` brings the *installed CLI* (`AIFLOW_HOME`) up to the
latest release; `aiflow project-update` then refreshes *this project's* mechanical scripts
(`.aiflow/*`, `.claude/hooks/*`, `docker/run.*`) from those templates and re-applies
config. Updating the CLI alone doesn't touch existing projects — that's deliberate, so a
project never changes underneath you without asking. Compare the project's stamped
version (`meta.aiflowVersion` in `.aiflow/config.json`) against `aiflow version`
(the installed CLI) to check whether it's behind.

Still stuck? Open an [issue](https://github.com/Cyber93de/aiflow/issues) with repro steps, your OS,
and the relevant `aiflow doctor` output.
