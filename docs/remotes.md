---
layout: default
title: Remote hosts
parent: CLI & Configuration
nav_order: 3
description: "Connect aiflow to GitHub, GitHub Enterprise, GitLab, self-managed GitLab, Bitbucket, Forgejo, Gitea, or a custom git host — token-based, with the matching MCP wired."
---

# Configuring the remote host
{: .no_toc }

1. TOC
{:toc}

---

aiflow is **token-based only — no OAuth for git hosts**. Pick the type at `aiflow init` /
`aiflow change-settings`; the matching CLI and MCP are wired automatically.

## Supported hosts

| Remote type | Base URL | Token env (`.env`) | Host MCP wired |
|-------------|----------|--------------------|----------------|
| `github` | github.com | `GITHUB_TOKEN` | github-mcp-server |
| `github-enterprise` | your GHE URL | `GITHUB_TOKEN` | github-mcp-server (`GITHUB_HOST` set) |
| `gitlab` / `gitlab-self` | gitlab.com / your URL | `GITLAB_TOKEN` | server-gitlab (`GITLAB_API_URL` set) |
| `bitbucket` | your URL | `BITBUCKET_TOKEN` | atlassian-bitbucket |
| `forgejo` / `gitea` | your URL | `GIT_REMOTE_TOKEN` | gitea-mcp-server (`GITEA_URL` set) |
| `custom` | any URL | your env var | pick from the list (or `none`) |

## GitHub

Create a Personal Access Token with **repo + issues + pull_requests** scope → put it in `.env` as
`GITHUB_TOKEN`. Beads issue sync (`bd github`) and the GitHub MCP use the same token.

## GitLab (cloud or self-managed)

Create a personal access token with **`api`** scope → `.env` as `GITLAB_TOKEN`. For self-managed,
choose `gitlab-self` and give your base URL at init; aiflow wires `GITLAB_API_URL` into the MCP.

## Self-hosted / other (Forgejo, Gitea, GitHub Enterprise, Bitbucket, custom)

Pick the matching type (or `custom`) and provide the base URL. aiflow stores
`remote.{type,baseUrl,api,tokenEnv,mcp}` and:

- wires the correct **host MCP** with the base URL passed through (`GITHUB_HOST` / `GITLAB_API_URL` /
  `GITEA_URL`);
- reads the token from the env var named in `remote.tokenEnv` (default `GIT_REMOTE_TOKEN` for custom);
- keeps everything else (Beads sync, Dolt sync) pointed at the same git remote.

## Changing later

`aiflow change-settings` re-runs the Q&A and re-renders `.mcp.json`, hooks, and the Beads sync config
from the new values. `aiflow doctor` prints the resolved remote + host MCP.

## Team issue sync

Beads issues sync over `refs/dolt/data` on the same git remote — one shared issue graph, no extra
server. See [Team collaboration](team).
