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
  and keep help text + README EN/DE + docs consistent. Several `lib/*.ps1` are **full native
  implementations, not shims** (`project-update.ps1` among them) — changing the `.sh` alone ships a
  feature that silently does not exist on Windows. Enforced since 2026-08-15 by
  `.github/scripts/check-twins.py` (CI job "twins"): pairing, `aiflow` subcommand dispatch parity
  between `bin/aiflow` and `bin/aiflow.ps1`, and help-text coverage of every dispatched command.
  It found `a11y-check` and `modernize-check` missing from the PowerShell entry point on its first
  run — they had been printing the help text on Windows instead of running. **What it does not
  cover:** divergence *inside* an existing pair (a step added to `lib/apply.sh` with no counterpart
  in `lib/apply.ps1` stays invisible). No allowlist for deliberate single-platform scripts was
  needed; `TWIN_EXEMPT` exists but is deliberately empty.
- **This repo's `.aiflow/` is refreshed from `templates/.aiflow/`, never hand-edited** (2026-08-15).
  It had drifted far behind: six missing `.ps1` halves, both `protect` twins absent, and a
  `ralph-headless.sh` still on the pre-open-ralph-wiggum design — so `aiflow protect` was broken on
  both platforms here and every audit command was broken on Windows. Refresh it by copying
  `templates/.aiflow/*.sh` + `*.ps1`, then `git update-index --chmod=+x .aiflow/*.sh` (`core.filemode`
  is false here, so a local `chmod` never reaches the index and the exec-bit CI step below goes red
  on the pushed tree) and re-stamp `.meta.aiflowVersion` in `.aiflow/config.json` from `VERSION` —
  that is `project-update`'s full mechanical block, and skipping the stamp makes interactive `aiflow`
  commands offer the `project-update` that the next sentence forbids. Do **not** run
  `aiflow project-update` in this repo — it would also overwrite this repo's own `AGENTS.md`,
  `CLAUDE.md` and agent definitions with the template versions. Enforced since 2026-08-15 by
  `.github/scripts/check-rendered.py` (same CI job as the twin guard): it compares every
  `.aiflow/*.sh|ps1` byte for byte against `templates/.aiflow/`, so a missing file, a hand-added
  one, or **content** drift all go red. Line-ending-only differences are ignored;
  `config.json`/`branching.json` are project state and never compared. It covers `.claude/hooks/`
  and `.github/scripts/` on the same rule (the two guards themselves are exempted — they are about
  aiflow's own structure and never ship to a project). The executable bit — the other half of the
  refresh recipe — is a separate CI step in the same job, because content comparison cannot see it:
  `.aiflow/*.sh` must be **100755 in the index**. Originally this was load-bearing: `bin/aiflow`
  *gated* `close-sync` and `ralph` on `[ -x ".aiflow/…" ]`, so a 100644 bit made those two commands
  claim the script was absent ("Run 'aiflow init' first") on a fresh Linux clone. **Since
  aiflow-wrn those gates are `[ -f ]`, like the other three** — every branch invokes via
  `bash <path>`, which works at 100644, so do **not** re-derive the `[ -x ]`-gate justification.
  Two live reasons remain: `.aiflow/bd-close-sync.sh:6` documents its usage as a direct
  `.aiflow/bd-close-sync.sh <issue-id>` call (the only *user-facing* one — `run-agent.sh` and
  `version.sh` document bare-name calls too; unifying all three is aiflow-ozo),
  which genuinely needs the bit; and `lib/init.sh:37` + `lib/apply.sh:414` `chmod +x` on copy, so
  every rendered project gets 100755 — the assertion is what keeps this repo's self-hosted
  `.aiflow/` matching that **in mode**, which `check-rendered.py` cannot see because it compares
  bytes. `bin/aiflow`, `lib/*.sh`, `install.sh` and everything under `templates/` stay 100644 on
  purpose — the installer and `init`/`project-update` chmod them on copy.
  **Not** covered: `.beads/hooks/*` are executed in
  place by git (`core.hooksPath`) and are 100644 — see aiflow-vly. Verified by `chmod -x`-ing a
  file in a scratch clone; re-run that check if the CI step changes.
- **No `[ -x ]` gate in front of an interpreted call** (2026-08-16). `[ -x "$f" ] || die; bash "$f"`
  gates on a bit `bash` never reads, and `core.filemode=false` on Windows drops it — so a project
  developed there checks the script in as 100644 and the command dies on Linux with an error that
  names the wrong cause (aiflow-wrn: `close-sync` and `ralph`). Use `[ -f ]`; keep `[ -x ]` only
  before a **direct** call (`"$f" --flag`), where the bit is exactly what is needed. Enforced by
  `.github/scripts/check-exec-gates.py` (CI job "shell"): within one file, an `-x` predicate whose
  operand is also passed to `bash`/`sh`/`pwsh`/`python3`/`node`/… is an error. shellcheck has no
  rule for this and the class survived aiflow-e0o and its review unnoticed. **Not** covered:
  a gate and its call in *different* files — resolving paths through variables across files would
  trade the guard's zero false positives for guesswork. `EXEC_GATE_EXEMPT` exists and is empty.
  Repo-only like the twin/rendered guards: the shell a generated project runs is aiflow's own and
  is already checked here, so shipping it would buy a Python CI step per project and nothing else.
- **`.github/scripts/` is aiflow-owned, `.github/workflows/` is project-owned** (2026-08-15).
  `project-update` overwrites the shipped CI helpers mechanically but never rewrites a workflow —
  `ci.yml` ships as a starting point projects extend, so replacing it would eat their jobs. A helper
  no workflow references is *advised* at the end of the run instead. One-way on purpose: the script
  is always present, so adopting the step can never fail on a missing file. Caveat: `.github/scripts/`
  is a conventional shared directory, not an aiflow namespace — a project file whose name collides
  with a shipped helper is overwritten without a `.bak`.
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
