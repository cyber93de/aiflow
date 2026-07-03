# aiflow design decisions (self)

Why things are the way they are. Change these only deliberately.

- **Token-based, never OAuth for git hosts.** Every remote (GitHub/GitLab/Bitbucket/Forgejo/Gitea/
  custom) authenticates via an API token named in `remote.tokenEnv`. OAuth is only offered for Claude
  itself (`claude.auth = apikey | oauth`).
- **Config-driven + idempotent.** `.aiflow/config.json` is the single source of truth; `apply.sh`
  re-renders deterministically. Never make the rendered files the primary edit path.
- **Project-scoped, no global state.** Secrets live only in `.env` (gitignored). Switching projects
  switches everything; nothing leaks between projects.
- **Two code memories, not one.** graphify = *structural* graph (exact "who calls what"); cocoindex-
  code = *semantic* RAG (fuzzy "where is X handled", local embeddings, ~70% fewer tokens). They are
  complementary — keep both. `aiflow index` refreshes both.
- **Context routing over file scanning.** The generated `memory-policy.md` routes questions
  Beads → memory files → graph → RAG → context7 → read files. Whole-file reads are the last resort.
- **Team sync via Dolt on the git remote.** Beads issues live in Dolt, synced over `refs/dolt/data` —
  no separate issue server. Correctness rules: session-start pull, **atomic `--claim`** (no double
  grab), **pull-before-push** (no clobber), never force-push.
- **Podman OR Docker, not Dagger.** Dagger was evaluated and removed as redundant: GitHub Actions
  covers CI/CD and `docker/run.sh` (engine auto-detected, `AIFLOW_CONTAINER` override) covers
  containers. Don't reintroduce a heavy pipeline runner.
- **Token-saving on by default.** caveman (terse output) + rtk (CLI-output filtering) default ON;
  intensive graph-memory learning default ON (`memory.intensity = aggressive`).
- **Windows + POSIX parity is mandatory.** Add a subcommand to both `bin/aiflow` and `bin/aiflow.ps1`
  and keep help text + README EN/DE + docs consistent.
- **No funding.** No Sponsors/Ko-fi/BuyMeACoffee/PayPal anywhere. The ask is feedback, a ⭐, and bug
  reports. Ideas and criticism explicitly welcomed.
- **Branding.** Owner account is **Cyber93de** (`github.com/Cyber93de/aiflow`); MIT © 2026 Cyber93de.
  No prior owner handle or employer/internal project name may appear anywhere — repo, docs, memory,
  or Beads issues.

## Build history (Beads epics, all closed 2026-07-03)
`aiflow-dwf` setup extensions · `aiflow-ej3` host-MCP + installer prompts · `aiflow-bfl` memory stack
(cocoindex) · `aiflow-qsd` team collaboration · `aiflow-45a` rebrand + READMEs + CI · `aiflow-aym`
docs site + remove funding + feedback section · `aiflow-soo` remove Dagger · `aiflow-f2s` 0.1.0
finalize (changelog + self-dogfood + this memory).

See [[architecture]] and [[codebase-map]].
