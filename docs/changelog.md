---
layout: default
title: Changelog
parent: Support
nav_order: 4
description: "aiflow changelog and release history, starting with the 0.1.0 first public release."
---

# Changelog
{: .no_toc }

aiflow follows [Keep a Changelog](https://keepachangelog.com/) and
[Semantic Versioning](https://semver.org/). The authoritative, always-current changelog lives in the
repository: **[CHANGELOG.md](https://github.com/Cyber93de/aiflow/blob/main/CHANGELOG.md)**.

## 0.1.0 — first public release

Highlights:

- **Setup** — `aiflow init` interactive Q&A → `.aiflow/config.json` → renders the whole project;
  `change-settings`, `install-deps`, `doctor`; installer offers git/svn/Ollama.
- **Version control & remotes** — git / svn / none; token-based GitHub, GitHub Enterprise, GitLab,
  self-managed GitLab, Bitbucket, Forgejo, Gitea, or custom — with the matching host MCP wired.
- **Models** — Claude API key or OAuth; Ollama local models (qwen3-coder recommended); model routing.
- **Memory** — graphify structural graph + cocoindex-code semantic RAG + context7 docs + a retrieval
  routing policy; `aiflow index` refreshes both indexes.
- **Team** — shared Dolt issue graph, session-start auto-pull, atomic claiming, pull-before-push.
- **Agents & workflow** — delivery + audit + brownfield agents, slash skills, the Ralph loop.
- **Quality, git & releases** — Google style, Conventional Commits, enforcement hooks, branching
  models, `aiflow release`.
- **Token savings** — caveman + rtk on by default; graph/RAG retrieval; `aiflow cost`.
- **Containers & CI/CD** — Podman/Docker headless runs; `ci.yml`, `release.yml`, `pages.yml`.
- **Docs & project** — extensive README (EN/DE), this documentation site, MIT license, no funding
  prompts.

See the full list in [CHANGELOG.md](https://github.com/Cyber93de/aiflow/blob/main/CHANGELOG.md).
