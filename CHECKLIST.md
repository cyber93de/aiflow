# aiflow requirements checklist

Self-review of the requested features. ✅ = implemented & smoke-tested.

| # | Requirement | Status | Where |
|---|-------------|--------|-------|
| R1 | claude-task-master for task decomposition | ✅ | `.mcp.json` (task-master), `/decompose` command |
| R2 | `aiflow init` asks: caveman(+mode), rtk, router, aim, architecture, templates-search, OS, IDE | ✅ | `lib/init.sh` |
| R3 | `aiflow change-settings` re-adjusts config | ✅ | `lib/settings.sh`, alias `settings` |
| R4 | rtk set by aiflow (project-scoped), not manual init | ✅ | `lib/apply.sh` runs `rtk init` when enabled |
| R5 | cocoindex removed; graphify added & automated | ✅ | `aiflow index`, `.mcp.json` graphify, `lib/init.sh` build |
| R6 | project aim (goal + architecture) → memory | ✅ | `.claude/memory/project-aim.md` via apply |
| R7 | dev setup (OS, IDE, VCS) captured → memory | ✅ | `.claude/memory/dev-environment.md` |
| R8 | prompt to browse claude-code-templates | ✅ | init question → `npx claude-code-templates@latest` |
| R9 | enforce autoformat + lint + tests + conventional commits | ✅ | `.githooks/pre-commit`, `.githooks/commit-msg`, `core.hooksPath` |
| R10 | sensible MCPs (filesystem) + github + graphify + task-master | ✅ | generated `.mcp.json` |
| R11 | easy use + easy config change, all project-scoped, tokens never global | ✅ | `.aiflow/config.json` + `.env`; nothing global |
| R12 | `aiflow upgrade` updates deps even if aiflow unchanged | ✅ | `lib/upgrade.sh` |
| R13 | this checklist + self-review | ✅ | this file |
| R14 | persistent memory so user can just say "continue" | ✅ | global memory `aiflow-build-checklist.md` |
| R15 | vendor-neutral — no third-party hub references anywhere | ✅ | scrub verified (grep clean) |
| R16 | README beginner explanations + per-tool links & justification | ✅ | `README.md §1, §5` |
| R17 | README in EN + DE | ✅ | `README.md`, `README.de.md` (also shipped to projects) |
| R18 | router docs: how/when, higher models coding, lower CI/CD | ✅ | `README §9` + `.aiflow/router-config.example.json` |
| R19 | issue intake via Beads from GitHub/GitLab/Bitbucket | ✅ | `/intake-issue` (host-aware via config.vcs) |
| R20 | multi-language Google-style format/lint/test enforcement | ✅ | `CLAUDE.md §3`, `format.sh`, `pre-commit`, `ci.yml` |

## Verified by
- `bash -n` on all scripts (pass)
- `aiflow init . --yes` → config.json, generated .mcp.json (4 servers), memory files, hooks wired
- caveman hook outputs full-mode directive from config
- commit-msg hook rejects non-conventional, accepts conventional
- forbidden-reference scrub: clean
