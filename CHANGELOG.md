# Changelog

All notable changes to **aiflow** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **The frontmatter guard now enforces the documented length limits** — `name` ≤ 64 characters,
  `description` ≤ 1024 — on agents, commands and skills alike, with the limits covered by its
  self-test (at the limit passes, one over fails). The `seo-optimization` skill's description was
  1323 characters; it has been tightened to fit while keeping every trigger word.
- **`aiflow doctor` now reports `core.hooksPath`.** It lives in `.git/config`, which is never
  cloned — so a fresh clone of any aiflow project silently runs no commit/push rules at all until
  someone sets it. `doctor` now says so and prints the one-line fix, in both twins.
- **The Python CI helpers are now statically checked.** Shell had `bash -n` + shellcheck and JSON
  had `jq empty`, but the guards that decide whether the build goes green had nothing: CI now runs
  `compileall` over `.github/scripts/` and `templates/.github/scripts/` (blocking) plus `ruff`
  (advisory, like shellcheck).
- **The router example ships current model ids.** `router-config.example.json` still listed
  `claude-opus-4-8`/`claude-sonnet-4-6` and `qwen2.5-coder:7b`; it now names Opus 5, Sonnet 5,
  Haiku 4.5 and `qwen3-coder`, in both the provider lists and the `Router` routes. Since the
  previous entry it reaches existing projects too.
- **Generated projects now check their own `.aiflow/*.sh` exec bits in CI.** `aiflow init`
  renders them 100755 and `bd-close-sync.sh` documents a direct call, but `core.filemode=false`
  on Windows drops the bit from the index without a word — and a colleague on Linux then cannot
  run the script. The assertion aiflow runs on itself now ships in the project `ci.yml` too, and
  the render test asserts both that the step is there and that `init` really wrote the files
  executable.
- **Non-ASCII paths no longer slip past the hooks.** Every place that reads a git path list now
  sets `core.quotePath=false` — the bead-id scan in `pre-commit` and the conflict check in
  `release.sh`/`release.ps1`, matching what the formatter and roster guard already did. Without
  it git renders `über.md` as `"Ã¼ber.md"`, and the leading quote makes every pattern
  match miss. Verified with an actual `über.md`: it is now formatted, checked, and rejected when
  broken.
- **`pre-commit` now judges the staged content, not your working tree.** A file you staged and
  then broke locally used to commit green, and a fix you staged could be blocked by the mess
  still in the worktree. Formatting now skips any file with unstaged changes (formatting plus
  `git add` would otherwise sweep those edits into the commit, and it says so), and the roster
  guard runs against a temp checkout of the index — cleaned up on every exit path, failures
  included, so an interrupted hook leaves nothing behind. No `git stash --keep-index`: making
  that safe around the formatter needs a `git reset --hard`, which can lose work if the hook
  dies. The stack lint/tests still run against the worktree by design — they need the installed
  toolchain a temp checkout does not have.
- **The git hooks now warn about bead ids that do not exist.** An invented id reads exactly like
  a real one, and CI cannot catch it — there is no `bd` in the runner and the issue DB is not a
  tracked file. `commit-msg` checks the message, `pre-commit` checks the lines being added, both
  through the shipped `.githooks/lib-bead-ids.sh`. It **warns and never blocks** (the id may just
  be a teammate's bead you have not pulled), skips silently without `bd`/`jq`, and reads the
  project's issue prefix from the database instead of hardcoding one.
- **The rendered-copy guard now covers the agent roster.** `.claude/agents`, `.claude/commands`
  and `.claude/skills` are compared against `templates/.claude/` too, so this repo's copies can no
  longer silently fall behind a template change. Skills are matched per directory (`<name>/
  SKILL.md`, not bare filename), and the `model: haiku` line that `apply` stamps into the five
  audit-only subagents is tolerated on exactly those five — the templates never carry it. Syncing
  the guard in also pulled three files this repo was missing: `ponytail-review.md` and the
  `ponytail` and `memory-setup` skills.
- **The twin guard now looks *inside* a pair.** It compared only the surface (both halves present,
  same subcommands, same help text), so a step added to `lib/apply.sh` and forgotten in
  `lib/apply.ps1` — the exact class that made a feature ship broken on Windows — stayed invisible.
  `check-twins.py` now also compares the `# ---- step ----` banners of the two halves and reports
  one that only one side has. The twins must therefore name a step identically (case, dashes and
  punctuation are normalised away); platform-specific detail goes on a plain comment line under the
  banner. `init.ps1`'s two differently-worded banners were aligned rather than exempted, so the
  exemption list ships empty.
- **`aiflow project-update` now reports scripts aiflow no longer ships.** It only ever copied, so a
  helper that was renamed or dropped upstream stayed in the project forever and went unmentioned.
  The end of the run now lists any `*.sh`/`*.ps1` in `.aiflow/` or `.claude/hooks/` that the
  templates no longer contain — and still deletes nothing, because that file may equally well be
  one you added. `.github/scripts/` is not scanned: it is a shared directory where your own CI
  scripts belong.
- **`aiflow project-update` also brings `.aiflow/router-config.example.json` forward.** The
  mechanical block copies only `*.sh`/`*.ps1`, so the router example — a reference file you copy
  to `~/.claude-code-router/config.json` — only ever reached freshly generated projects. It now
  follows the `*.bak` rule, so a sample you tweaked is preserved rather than overwritten.
- **`aiflow project-update` now refreshes `.githooks/*` too**, under the same `*.bak` rule as the
  agent definitions. They were excluded before, which meant a shipped hook improvement (the
  frontmatter guard in `pre-commit`, for one) only ever reached projects generated *after* it —
  never an existing one. A hook you customised is kept as `<file>.bak` and reported; hooks you
  added yourself are untouched; a deleted one is restored; the exec bit is re-applied, since git
  silently skips a hook that lost it. `.github/workflows/*` stays untouched, for its own reason.

### Added
- **Queue mode — a closed task no longer ends the session.** Beads is treated as an authoritative
  work queue: after closing a bead the agent refreshes the queue and starts the next task instead
  of asking what to do next. Three parts, so it does not depend on the model remembering:
  `AGENTS.md` §4b states the loop, the ranking (priority → unblocks-most → epic/workstream →
  continuation of the bead just closed) and the only four legitimate reasons to stop (nothing
  actionable, everything blocked, the user says stop, a decision/credential only they have);
  **`aiflow next`** (`.aiflow/next-task.sh|ps1`) applies that ranking mechanically and exits `3`
  on an empty queue, with `--after <closed-id>`, `--unassigned`, `--claim` and `--json`; and a
  Claude Code **`Stop` hook** (`.claude/hooks/queue-continue.sh|ps1`, wired by `apply`) hands the
  next ready task back when the agent tries to end its turn. The hook blocks **at most once** per
  stop (`stop_hook_active`), so naming a legitimate stop reason always ends the session. Opt out
  per project with `.aiflow/config.json → beads.queueMode = false` (asked by `aiflow
  change-settings`) or per session with `AIFLOW_QUEUE_MODE=off`. Queue mode changes nothing about
  the §4 gates or the §7 rule that merging to `main` and releasing always need explicit
  confirmation.
- **The agent-roster check now runs in `pre-commit`, not just in CI.** Staging any file under
  `.claude/agents|commands|skills` runs `.github/scripts/check-frontmatter.py` over the roster and
  **blocks the commit** on invalid frontmatter — the same failure that used to cost a push, a red
  build and a round trip. It needs `python3`/`python` with PyYAML: without them the hook prints a
  note and continues, so a missing toolchain never blocks a commit and CI stays the backstop.
  Reaches existing projects too, via the `.githooks/` refresh described under *Changed* — a hook
  you customised is kept as `<file>.bak` rather than silently replaced.
- **Nine new Skills**, so the delivery agents stop working generically on a stack they were never
  told about. Technology: **stack-embedded** (C/C++ firmware — HAL/driver separation, no allocation
  after init, ISR discipline, watchdog, host tests against a mocked HAL), **stack-mobile**
  (Flutter/Dart, Kotlin/Android, Swift/iOS — layering, one state-management choice, process death,
  offline/sync, Keystore/Keychain, store constraints), **stack-web-frontend** (Angular/React/Vue —
  feature slices, server vs client state, XSS and token handling, Core Web Vitals budgets, i18n,
  a11y), **stack-backend** (Spring/Quarkus/Jakarta, .NET, Rust, Node, Go, Python — hexagonal
  layering with ports, transaction boundaries, 12-factor config, timeouts/retries/breakers,
  observability, FOSS-first). Integration and data: **api-design** (REST versioning, status codes,
  pagination, idempotency, `problem+json`, OpenAPI, `.http` files; when SOAP is legitimate and how
  to migrate off it; GraphQL/gRPC trade-offs), **messaging-events** (broker choice, at-least-once
  with idempotent consumers, transactional outbox, ordering, schema evolution, DLQs, sagas),
  **data-storage** (relational default, when NoSQL is actually justified, embedded DBs, Redis with
  designed cache invalidation, Elasticsearch as a *derived* read layer), **cloud-native**
  (container images, K8s probes/limits/rollout/secrets, EC2, modular monolith before microservices).
  Cross-cutting: **security** — OWASP Top 10 as the review raster plus ASVS levels, IAM least
  privilege (roles over per-user grants, short-lived credentials, rotation), API authN/authZ,
  secrets, crypto, and supply-chain safety; the `security-advisor` now reads that same raster
  instead of restating its own.
- **`docs/skills.md`** — the skill catalogue plus the rule the split follows: an **agent** is a
  role (who acts, with what authority, in what order, what it hands to whom), a **skill** is
  knowledge several roles need. Both may exist for one topic. Rules that must fire on *every* task
  (§2 architecture, §3a/§3b/§3c gates) deliberately stay inline in `AGENTS.md` — a skill is offered
  by pattern match, and Copilot/Codex get no auto-offer at all, so those two get an explicit
  "open the matching SKILL.md yourself" instruction in `copilot-instructions.md`.
- **ponytail** — a YAGNI decision-ladder skill (`.claude/skills/ponytail/`, Claude Code) applied
  before writing new code/dependencies/abstractions, plus `/ponytail-review` to audit a diff for
  over-engineering. Off by default; toggle with `ponytail.enabled`/`.mode`
  (`full`/`lite`/`ultra`) via `aiflow init` or `aiflow change-settings`. Copilot gets a pointer in
  `copilot-instructions.md`; Codex reads it via `AGENTS.md` directly.
- **memory-setup skill** — `AGENTS.md` §8 (Memory) shrank from a full explainer to a short
  toggle + essentials; the full context-routing stack, team preferences, and Ollama routing detail
  moved to `.claude/skills/memory-setup/SKILL.md` (Claude Code auto-offers it). §3b/§3c (REST/
  Database, both MANDATORY) and §6 (Ralph loop, decided per-task by the implementer) stay inline —
  extracting rules that must apply reliably on every task into a Claude-Code-only, pattern-matched
  skill would risk them silently not firing, especially for Codex/Copilot which have no skill
  auto-offer mechanism at all.
- **CI now rejects `[ -x ]` gates in front of interpreted calls.**
  `.github/scripts/check-exec-gates.py` flags any `-x` test whose operand the same file also runs
  as `bash <path>` (or `sh`/`pwsh`/`python3`/`node`/…): the exec bit is invisible to an interpreter,
  and `core.filemode=false` on Windows drops it — which is exactly how `aiflow ralph` and
  `aiflow close-sync` came to fail on Linux for a reason their error message never named. `[ -x ]`
  before a *direct* call stays valid and is not reported. shellcheck has no rule for this class.

### Fixed
- **aiflow died on macOS's system bash.** `/bin/bash` there is 3.2, where an empty array under
  `set -u` aborts the script instead of expanding to nothing, and `mapfile` does not exist at all —
  so `aiflow project-update` on a project with nothing to report, and `aiflow ollama pull` with no
  models configured, both failed. Every reporting array now uses the portable `${ARR[*]+x}` guard,
  `ollama.sh` builds its list without `mapfile`, and a new `macos-latest` CI job runs the whole
  round-trip through `/bin/bash` — after asserting that it really is 3.2, so the job cannot quietly
  start proving nothing on a future runner image.
- **`aiflow ralph` and `aiflow close-sync` claimed the script was missing when it wasn't.** Both
  gated on `[ -x .aiflow/… ]` while the other three `.aiflow` commands gated on `[ -f ]` — and all
  five invoke the script via `bash <path>`, which never needed the executable bit. A project
  developed on Windows commits `.aiflow/*.sh` without it, so a colleague on Linux was told to
  "Run `aiflow init` first" for a file sitting right there. All five branches now use `[ -f ]`,
  matching what `bin/aiflow.ps1` has always done.
- **The `reviewer` subagent never appeared in Claude Code's agent roster**, so `/review-ac` had no
  agent to dispatch and the §4.6 review gate only worked through the inline fallback in the
  command. Cause: its frontmatter `description` was an unquoted YAML scalar containing `": "`
  (*"one agent, two hats: software architect …"*), which YAML reads as a nested mapping key — the
  block failed to parse and the agent was **silently dropped**. Nothing is logged for this. The
  same bug hit the `/review-ac` command and the `seo-optimization` skill, which degrade more
  quietly still: they fall back to their body text as the description, so the trigger wording an
  author wrote is simply not the wording that gets matched. All descriptions are now quoted.
- **New CI job guarding that whole failure class** — `.github/scripts/check-frontmatter.py`
  parses the frontmatter of every agent, command, and skill file (this repo *and* `templates/`,
  recursing into namespaced command subdirectories) and fails the build on an unparseable block
  or a missing `description` (plus `name` for agents and skills — commands derive theirs from the
  filename). It carries its own fixtures (`--selftest`, run in CI before
  the real check). Generated projects get the same script and a matching `ci.yml` step, so a
  broken agent definition surfaces as a red build instead of an agent that quietly stops
  existing. Needs `python3` + PyYAML in CI — pinned via `actions/setup-python` in both workflows.
- **`aiflow project-update` now also refreshes `.github/scripts/*`**, so an existing project picks
  up aiflow's CI helpers (like the frontmatter guard above) instead of only ever getting them at
  `init` time. `.github/workflows/*` is still never rewritten — `ci.yml` ships as a starting point
  you extend, and replacing it on every update would throw your jobs away. A helper that no
  workflow calls yet is listed at the end of the run with a pointer to the matching template step.
  The coupling is one-way on purpose: the script is always there, so adopting the step can never
  fail on a missing file. Implemented in both twins (`lib/project-update.sh` and the native
  `lib/project-update.ps1`).
- **`aiflow a11y-check` and `aiflow modernize-check` did nothing on Windows.** Both were missing
  from `bin/aiflow.ps1`'s dispatch *and* from its help text, so they fell through to the default
  branch and printed usage instead of running the audit. Fixed, and guarded from here on by a new
  `twins` CI job (`.github/scripts/check-twins.py`): it checks that every twinned script has both
  a `.sh` and a `.ps1` half (`lib/`, `.aiflow/`, `.claude/hooks/`, `templates/.aiflow/`,
  `templates/.claude/hooks/`, `templates/docker/`, `install.*`), that `bin/aiflow` and
  `bin/aiflow.ps1` dispatch the same subcommands, and that each entry point's **usage block**
  mentions every subcommand it dispatches. It found this bug on its first run. It does not compare
  the *contents* of an existing pair — that is the remaining gap, tracked separately. A second
  guard in the same job (`.github/scripts/check-rendered.py`) compares this repo's rendered
  `.aiflow/`, `.claude/hooks/` and `.github/scripts/` against their `templates/` originals byte for
  byte, so content drift in aiflow's own self-hosted copies — a missing file, a hand-added one, or
  an edited one — fails the build too. A third step asserts that `.aiflow/*.sh` are `100755` in the
  git index: `aiflow init` renders them executable and `bd-close-sync.sh` documents a direct call,
  so the mode is part of the rendered copy — but byte comparison cannot see it and
  `core.filemode=false` on Windows drops it silently.
- **Docs and `.gitignore` still described the pre-open-ralph-wiggum loop.** `aiflow ralph` has run
  on [open-ralph-wiggum](https://github.com/Th0rgal/open-ralph-wiggum) for a while, which keeps its
  iteration history in `.ralph/ralph-history.json` — but generated projects still ignored the
  long-gone `result.json` and `.aiflow/ralph.log` while **not** ignoring `.ralph/`, so a project
  could commit its Ralph history by accident. The troubleshooting entries in `README.md`/
  `README.de.md` and the feature blurb in `docs/features.md` pointed at those same dead files.
- **The caveman hook printed a garbled banner on Windows.** `.claude/hooks/caveman.ps1` carried an
  em-dash in a UTF-8 file with no BOM, which Windows PowerShell 5.1 reads as ANSI — the session
  banner came out as `CAVEMAN MODE ACTIVE ?" communicate…`. The template was already correct
  (plain ASCII); only aiflow's own rendered copy had drifted, which is exactly the class of bug the
  new rendered-copy guard now catches.
- **CI now runs the render test** it always claimed to: a `render` job inits a project, then puts it
  through a `project-update` round-trip (helper deleted + workflow step stripped → helper restored,
  `ci.yml` byte-identical, advisory printed, a project-owned CI script neither deleted nor advised
  on) and runs the frontmatter guard inside the generated project. A `render-windows` job does the
  same round-trip through `project-update.ps1`, so a feature added to a `.sh` twin only can no
  longer ship broken on Windows.

## [0.6.0] — 2026-07-31

### Added
- **Model routing for audit-only subagents** — `modelRouting.enabled` (on by default, toggle via
  `aiflow change-settings`) stamps `model: haiku` into the frontmatter of the five subagents that
  only do mechanical background checks (**docs-sync**, **test-gap-advisor**, **dependency-auditor**,
  **performance-advisor**, **onboarder**), so they run on Haiku 4.5 instead of the session's main
  model. Every other subagent keeps the session default — they need real reasoning. Turning the
  toggle off strips the line again.
- **ponytail** — a YAGNI decision-ladder skill (off by default, `ponytail.enabled`/`.mode`): before
  new code, dependencies or abstractions, it checks whether the thing needs to exist at all, is
  already in the codebase, is stdlib, a native platform feature, an installed dependency, or a
  one-liner — and only then writes the minimum viable new code. `/ponytail-review` audits a diff
  for over-engineering regardless of the toggle. Inspired by
  [dietrichgebert/ponytail](https://github.com/dietrichgebert/ponytail), reimplemented rather than
  vendored, the same way as caveman.
- **memory-setup skill** — `AGENTS.md`'s Memory section shrank to a short toggle plus essentials;
  the full context-routing stack, team preferences and Ollama routing detail moved into an
  auto-offered skill. The REST/database rules and the Ralph-loop decision stay inline in
  `AGENTS.md`: skills are Claude-Code-only and pattern-matched, so a rule that must fire on every
  task cannot live in one.

### Fixed
- `Set-ModelRoutingLine` passed a raw relative path to `[System.IO.File]`, which resolves against
  the process working directory rather than PowerShell's — so the model-routing stamp was written
  to (or read from) the wrong file on Windows.

## [0.5.1] — 2026-07-29

### Fixed
- `aiflow update` overlaid the new archive over the old install without cleaning `bin/`/`lib/`
  first — updating across the 0.5.0 OS-split (mixed `.sh`+`.ps1` layout → OS-scoped) left every
  old-layout file behind. Both `update.sh`/`update.ps1` now remove `bin/` and `lib/` before
  installing.
- `install-deps.ps1`'s config reader built its `jq` filter as one argument containing literal
  quote characters — PowerShell's native-exe argument passing mangles that (unlike bash, which
  execs argv as-is), silently dropping the quotes or, for an empty default, the whole argument,
  shifting everything after it. Real-world effect: the uv/bun auto-install path (restored in
  0.5.0) crashed with jq compile errors the moment it actually ran. Switched to `jq --arg` for a
  real default, `// empty` for an empty one.

## [0.5.0] — 2026-07-29

### Added
- **Native PowerShell parity for every core tool script** — all 10 `lib/*.sh` scripts
  (init, doctor, settings, install-deps, upgrade, ollama, update, project-update, apply,
  branching) now have behavior-equivalent `lib/*.ps1` twins, and `bin/aiflow.ps1` calls them
  directly. Windows needs **no Git Bash / WSL at all** anymore — the 0.4.1/0.4.2 launcher
  workarounds (slash normalization, explicit Git-Bash resolution) are gone entirely.
- **OS-scoped release archives** — `aiflow-*-windows.zip` ships only the PowerShell scripts
  (`bin/aiflow.ps1`, `lib/*.ps1`, `install.ps1`); `linux`/`macos` tar.gz only the bash ones.
  `templates/` still ships complete (both shells) to every OS, since a project may target
  either shell regardless of host.

### Fixed
- jq's `// true` default collapsed an explicitly-set `false` config value back to `true`
  (`agents.claude`, `release.tag.enabled`, `sync.pullOnStart`, `caveman.enabled`,
  `git.releaseTags`) — replaced with a null-check idiom in bash and PowerShell alike.
- `aiflow protect` compared the `.vcs` config *object* against `"github"` and therefore never
  reached the actual `gh` branch-protection calls (pre-existing in both shell twins).
- Windows PowerShell 5.1 misparsed two UTF-8-without-BOM scripts containing em-dashes
  (`0x94` reads as a closing quote in ANSI) — tool scripts are ASCII-only now.

## [0.4.2] — 2026-07-27

### Fixed
- `aiflow init` (and every other bash-backed subcommand) still failing on Windows after 0.4.1
  with `No such file or directory` — plain `bash` on PATH commonly resolves to WSL's stub
  (`C:\Windows\System32\bash.exe`), which can't parse Windows-style paths at all, regardless of
  slash direction. The launcher now resolves Git for Windows' own `bash.exe` explicitly (via
  `git.exe`'s location, or common install dirs) instead of trusting whatever `bash` is on PATH.

## [0.4.1] — 2026-07-27

### Fixed
- `aiflow init` (and every other bash-backed subcommand) failing on Windows with
  `No such file or directory` — the PowerShell launcher built `AIFLOW_HOME` with backslashes,
  which mangled when interpolated into forward-slash bash paths. `AIFLOW_HOME` is now
  normalized to forward slashes once, up front.

## [0.4.0] — 2026-07-26

### Added
- **CodexSaver integration** (`codexsaver.enabled`, off by default) — optional cost-aware MCP
  router for OpenAI Codex CLI ([fendouai/CodexSaver](https://github.com/fendouai/CodexSaver)):
  delegates cheap/bounded work (docs, tests, explanation, search) to a cheaper worker, keeping
  Codex for architecture/security/final review. `aiflow install-deps` clones + editable-pip-installs
  it (no published package) plus Pi Agent, and sets the provider key from `.env` if present;
  `apply.sh` owns `.codex/config.toml` and appends CodexSaver's entry itself (pointing at the
  stable script path its own installer creates), so re-running `aiflow apply` never clobbers or
  duplicates it. Needs a provider API key (DeepSeek by default) — untested end-to-end here (no
  key available in this environment); config rendering and install wiring are verified.
- **Ralph loop rebuilt on [open-ralph-wiggum](https://github.com/Th0rgal/open-ralph-wiggum)** —
  genuinely agent-agnostic now (Claude Code, OpenAI Codex CLI, GitHub Copilot CLI via `--agent`),
  replacing the old Claude-only hand-rolled `claude -p` loop. `aiflow ralph "<task>"` defaults to
  the first agent enabled in `agents.*`; `install-deps` installs Bun + the `ralph` CLI. Known
  limitation: completion-promise auto-stop isn't always reliable — `--max-iterations` remains the
  real safety bound regardless of agent.
- install-deps installs Claude Code / GitHub Copilot CLI / OpenAI Codex CLI per `agents.*`
  config (previously Claude Code was unconditional and the other two were never installed);
  `aiflow doctor` reports all three plus `ralph`/`bun`.
- `.github/copilot-instructions.md` now applies the highest-ROI techniques from the [GitHub
  Copilot token-optimization guide](https://github.com/olivomarco/github-copilot-token-optimization):
  output-control directive, "landmines only" context-file guidance, model/cache-stability advice,
  and an `applyTo:` scoping tip.

## [0.3.0] — 2026-07-26

### Added
- **`aiflow project-update` now also refreshes agent definitions**, not just mechanical scripts:
  `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.claude/agents/*`,
  `.claude/commands/*`, `.claude/skills/*`. Any file you customised (differs from the incoming
  template) is renamed to `<file>.bak` — never deleted — before the new version is written, and
  listed in a warning so you know to review/reapply your changes; unmodified files are refreshed
  silently. Still never touches `.beads/`, `.claude/memory/*`, or your `.aiflow/config.json`
  project settings (aim, architecture) — those always survive an upgrade untouched.
- **Applied the `seo-optimization` skill to aiflow's own docs site** (dogfooding): added
  `docs/robots.txt` (allow-all + sitemap pointer), `docs/404.html`, a favicon
  (`docs/assets/favicon.svg`), and `docs/_includes/head_custom.html` with JSON-LD structured data
  (`SoftwareApplication` + `WebSite`) — just-the-docs' documented head-injection point, since the
  theme/`jekyll-seo-tag` already handle per-page title/description/canonical/Open Graph from front
  matter. `docs/llms.txt` and `docs/llms-full.txt` (context7's self-contained reference) updated
  for multi-agent support, Skills, GitKraken, per-host release workflows, and the archive-install
  update path — previously stale at the pre-multi-agent feature set.
- **`aiflow update` now works on archive installs too**, not just git checkouts. If `AIFLOW_HOME`
  isn't a git repo (e.g. installed from a downloaded release zip/tar.gz), it checks the GitHub
  Releases API for a newer version, downloads the matching per-OS archive, verifies it against
  the published `SHA256SUMS.txt`, and installs it over `AIFLOW_HOME` — previously it just refused
  with "re-clone or re-download manually."
- **Skills** (`.claude/skills/<name>/SKILL.md`, Claude Code only) — a new mechanism distinct from
  slash-commands: Claude Code matches a skill's `description` against the current task and offers
  to run it automatically, instead of waiting for an explicit `/command`. Ships with
  **seo-optimization**: SEO for any web-facing project/framework (plain HTML, GitHub Pages, static
  sites, docs sites, Next.js, Astro, Hugo, Jekyll, VuePress, VitePress, React, Vue, Svelte,
  Angular, …) — meta tags, Open Graph/Twitter Cards, JSON-LD structured data, robots.txt/
  sitemap.xml, canonical URLs, heading hierarchy, alt text, Core Web Vitals, GitHub Pages
  specifics (base URL, 404, social preview, RSS); non-destructive, ends with an SEO report. Add
  more by dropping a new `<name>/SKILL.md` into `.claude/skills/`.
- **Agent-agnostic core.** `AGENTS.md` is now the single, shared source of truth (code style,
  quality gates, task workflow, git rules, Definition of Done) for **any** coding agent, not just
  Claude Code. `CLAUDE.md` is now a one-line `@AGENTS.md` import (Claude Code's native memory-import
  syntax) so Claude Code still loads the exact same content. Sections that only Claude Code can run
  automatically (subagents, hooks, slash-commands, the Ralph loop, caveman/rtk) are marked
  **(Claude Code only)** — every other agent follows the same rules manually instead.
- **`agents.{claude,copilot,codex}` config** (`aiflow init` / `change-settings`) — pick any
  combination of Claude Code (default on, full feature set), GitHub Copilot, and OpenAI Codex CLI.
  Each enabled agent gets its own rendered MCP config from the same server set: `.mcp.json`
  (Claude), `.codex/config.toml` (Codex, TOML `[mcp_servers.*]` tables), `.vscode/mcp.json` +
  `.github/copilot-instructions.md` (Copilot).
- **New docs page:** [Multi-Agent Support](https://cyber93de.github.io/aiflow/multi-agent) —
  what's shared vs. Claude Code-only, and how MCP config is rendered per agent.
- **SEO pass:** vendor-neutral tagline/description across README/README.de/docs site
  (`_config.yml`, `docs/index.md`), reflecting multi-agent + gitflow release automation for
  better discoverability in search engines.
- **`bugfix/*` branch type** for the `gitflow` model, alongside `feature/*` — both branch from
  and merge back to `develop` only, never `main`.
- **`main` is now actively restricted (gitflow).** Only `develop`, `hotfix/*`, or `chore/*` may
  ever land on `main`; the `pre-push` hook parses new merge commits on a `main` push and rejects
  any `feature/*`/`bugfix/*` source. Doc-only and CI/workflow-file-only changes count as
  `chore/*`, not `feature/*` — and never trigger a release.
- **`aiflow hotfix <name>`** — branches `hotfix/<name>` off `main` and bumps `VERSION` to
  `X.Y.(Z+1)-HOTFIX` (mirrors how `develop` carries `-SNAPSHOT`).
- **Hotfix releases.** `aiflow release` now auto-detects the release kind from `VERSION`'s
  suffix: `-SNAPSHOT` → minor release (develop → main, strips suffix); `-HOTFIX` → patch release
  (hotfix/* → main, strips suffix). Either way develop is bumped to the next
  `X.(Y+1).0-SNAPSHOT`, and a hotfix release also merges the hotfix branch into `develop` so the
  fix isn't lost there.
- **`main` may never carry a `-SNAPSHOT`/`-HOTFIX` version.** A new `pre-push` guard rejects any
  push to `main` whose `VERSION` still has one of those suffixes.
- **`aiflow release` now defaults to a dry run.** It prints what it would do (old → new version,
  develop bump, hotfix-into-develop merge) and exits; only `--yes` actually cuts the release.
  Releasing must always be a deliberate, human-approved action — agents are told (in the
  generated `CLAUDE.md` / `docs/branching.md`) to ask the user before adding `--yes`.
- **Predefined release-publish workflows** for GitHub, GitLab, Gitea, Forgejo, and Bitbucket.
  `aiflow init`/`apply` writes the one matching your chosen `remote.type` (never overwrites an
  existing one): `.github/workflows/release.yml`, `.gitlab-ci.yml`, `.gitea/workflows/release.yml`,
  `.forgejo/workflows/release.yml`, or `bitbucket-pipelines.yml`. Each publishes a release
  entry/note on the host when a version tag is pushed — it never bumps versions itself, that
  stays the local `aiflow release --yes` step. Sources in `release-workflows/` (outside
  `templates/`, so the wrong host never gets the wrong file).
- **GitKraken MCP** — a new independent `gitkraken.enabled` toggle (`aiflow init` /
  `change-settings`) wires the GitKraken MCP (via the `gk` CLI) alongside whichever remote host
  you use, since GitKraken is a client, not a host, and doesn't replace the host choice above.
  "Local, no MCP" remains available by setting `remote.type` to `none`.

### Fixed
- **`.github/workflows/release.yml` wasn't packaging `release-workflows/`** into the published
  per-OS archives (only `bin lib templates install.* README* LICENSE VERSION` were copied) — an
  archive install (not a git checkout) would never get the predefined per-host release-publish
  workflows. Fixed by including `release-workflows/` in the archive build step.
- **`aiflow update`'s GitHub API/download requests could fail on Windows** with a Schannel
  revocation-check error (common behind some corporate proxies/AV) even though the network path
  was fine. Fixed by adding `--ssl-revoke-best-effort` to those `curl` calls (no-op on
  non-Schannel/non-Windows curl builds).

## [0.2.0] — 2026-07-12

### Fixed
- **Removed the nightly `aiflow-agent` GitHub Actions workflow** from `templates/.github/workflows/`.
  It ran an unattended Ralph loop on a `0 3 * * *` cron in every scaffolded project and always
  failed there without a configured token — `aiflow init` no longer generates it. Existing
  projects: drop `.github/workflows/agent.yml` manually or run `aiflow project-update`.

### Added
- **Every invoked project script now ships as a cross-platform pair** (`.sh` for macOS/Linux,
  `.ps1` for Windows): `.aiflow/{version,release,protect,security-check,requirements-check,
  quality-check,ralph-headless,run-agent,bd-close-sync}.{sh,ps1}`,
  `.claude/hooks/{format,caveman,beads-sync}.{sh,ps1}`, `docker/run.{sh,ps1}`. `apply.sh` now
  reads `.aiflow/config.json`'s `dev.os` and writes the OS-correct interpreter into the
  Claude Code hook commands in `.claude/settings.json` — Windows gets `powershell -File
  ...ps1`, macOS/Linux get `bash ...sh`. No project needs Git-Bash on Windows to run its
  hooks/checks anymore (the aiflow CLI itself still requires Git-Bash on Windows).
- **`aiflow update`** — self-updates the aiflow install (`git pull --ff-only` in `AIFLOW_HOME`)
  to the latest release. Refuses on a dirty tree or a non-git install.
- **`aiflow project-update`** — refreshes only the mechanical, never-hand-edited scripts
  (`.aiflow/*.sh`+`.ps1`, `.claude/hooks/*.sh`+`.ps1`, `docker/run.*`) in the CURRENT project
  from the installed templates, re-applies config, and stamps the new version. Never touches
  `CLAUDE.md`, agents, docs, or your own config.
- **Version-aware upgrade prompt.** Every project now stamps the aiflow version it was
  generated with in `.aiflow/config.json` (`meta.aiflowVersion`). When you run any `aiflow`
  command in a project whose stamp is older than the installed CLI, you're asked (interactively
  only) whether to run `aiflow project-update` right now.
- **"Built with aiflow" README badge.** `apply.sh` idempotently inserts a
  `[Built with aiflow]` badge + link under the first `# ` heading of `README.md` /
  `README.de.md` if it isn't already there — without touching the rest of the file (unlike the
  template copy step, which never overwrites an existing README).
- **Per-OS install sections** (Windows · Linux · macOS) with full commands in the READMEs (EN/DE)
  and `docs/installation.md`, each with its own terminal GIF (new Windows/PowerShell demo).
- **Two more terminal GIFs:** the delivery **workflow** end to end (task → pre-analysis → PO
  question with recorded decision → versioned+secured API → tests + `.http` → review PASS → close)
  and **brownfield onboarding** (init detects existing code → onboarder learns it → proposes the
  project aim for confirmation → `aiflow modernize-check`); embedded in READMEs, workflows,
  getting-started, and example-project pages.
- **Documentation-site link** ([cyber93de.github.io/aiflow](https://cyber93de.github.io/aiflow/))
  now in the README header line (EN/DE).

## [0.1.1] — 2026-07-04

Quality-focused agent upgrade: the implementer now works like a senior engineer (strategy before
code), the reviewer reviews like an architect, and every implementation passes explicit quality
gates — static analysis, coverage, BDD tests, logging, and IDE-testable REST interfaces.

### Agents
- **implementer → senior engineer.** Mandatory **pre-analysis before any code**: current
  architecture, how it changes, effort, complexity, risks; missing information is gathered *before*
  implementation. Questions whether the requirement fits the existing architecture and performs
  **targeted refactoring** when it doesn't (or escalates to the architect). Prefers **established
  open-source frameworks and design patterns over self-implementations**, avoids duplicated code,
  designs for reuse and generic solutions, and always watches overall quality, performance, and
  security.
- **PO-level clarification + recorded decisions.** Functional questions are phrased so a product
  owner understands the hurdle (plain language, options with consequences); the user picks, and
  every decision is **recorded** (`/beads:decision` / `bd update --design`).
- **Design principles codified.** The implementer builds by SOLID, DRY, KISS, YAGNI, high
  cohesion/low coupling, no cyclic dependencies, small methods/classes, robust error/input/null
  handling, thread safety where relevant, and testability by design (DI, no hidden dependencies,
  deterministic, mockable).
- **reviewer → architect *and* quality gate in one agent.** Architect hat: architecture integrity
  (does the change break the architecture? was an adaptation necessary — and done sensibly +
  recorded as ADR?), design (SOLID, clean architecture, domain model, abstraction level),
  maintainability (technical debt, over-/under-engineering), risks (vulnerabilities, performance,
  concurrency, API breaking changes, backward compatibility). Quality-gate hat: an objective
  release checklist (findings addressed, tests green, no new smells/violations, metrics met,
  docs/changelog updated, requirement fully implemented) — verdict PASS (release) or CHANGES
  REQUIRED (back to the implementer). Out-of-scope improvement ideas are persisted as
  `[suggestion]` beads so the next loop picks them up.
- **tester → test/QA engineer.** Systematic coverage (happy path, negative, edge, boundary,
  exceptions, invalid inputs) plus a test-quality audit (meaningful assertions, deterministic,
  independent, understandable); enforces the coverage gates and the BDD pyramid. Runs **adaptively**
  — when the implementer's pre-analysis flags high risk/complexity, or on demand.
- **Objective metric targets** (new table in CLAUDE.md §3a): low cognitive/cyclomatic complexity,
  0 % new duplication, no new code smells, ≥ 80 % coverage of changed logic, 0 architecture
  violations, 0 linter/compiler warnings, 0 high/critical security findings, breaking changes only
  with recorded justification.

### Quality gates (new CLAUDE.md §3a — mandatory on every implementation)
- **Static code analysis, always:** use the project's tool (e.g. SonarQube) when available;
  otherwise the agent performs the analysis itself. Code smells are never shipped.
- **Coverage:** > 80 % line coverage on touched code; **every non-static method tested**.
- **Test pyramid:** unit + end-to-end tests always mandatory; integration/system tests where they
  add signal (skips must be justified). **BDD (Given/When/Then)** is mandatory for end-to-end,
  system, and acceptance tests.
- **Logging is quality:** no-logging is a defect; correct levels (`debug`/`info`/`warn`/`error`),
  standard logging frameworks, never secrets in logs.

### Database modelling rules (new CLAUDE.md §3c)
- **New data models** follow 20 explicit design rules (R1–R20): ≥ 3rd normal form (denormalisation
  only documented + measured), no redundant data, m:n via junction tables, real foreign keys (no
  soft references), no needless surrogate keys, `NOT NULL` by default, business rules as `CHECK`
  constraints, `UNIQUE` on natural keys, precise data types, no magic values, only necessary
  indexes, smallest sufficient types, large objects outside the DB, no overly wide tables, one
  naming convention, no cryptic abbreviations, lookup tables over status numbers, referential
  integrity everywhere, cascades only deliberately, soft delete/history where the domain needs it.
- **Brownfield caution (B1–B8): existing schemas are handled with care.** They may be shared by
  other applications and must support rollback to older app versions — so restructuring, re-keying,
  adding constraints, changing types, merging/splitting tables, or late normalisation never happen
  as a side effect of a feature task. Improvement potential is **documented as recommendation
  beads**; a commissioned schema change is treated as high-risk work (external-consumer check,
  backward-compatibility/rollback plan, versioned migration). The reviewer blocks uncommissioned
  structural changes smuggled into a diff.

### REST interfaces (new CLAUDE.md §3b)
- **Versioned and secured by default:** every REST API carries a version from day one
  (`/api/v1/…`; breaking changes → new version with a deprecation window) and real
  authentication — **Basic Auth is insufficient**: OAuth 2.x / OpenID Connect, short-lived JWT
  bearer tokens, or managed API keys with rotation; mTLS for service-to-service where warranted;
  authorisation checked per endpoint. The reviewer's gate checklist enforces both.
- Every new/changed REST endpoint ships a matching **`.http` file** (`http/<resource>.http`,
  IntelliJ HTTP Client / VS Code REST Client) covering happy path + auth + error case.
- Host, port, test user, and password come from **`.env`** (`APP_HOST`, `APP_PORT`,
  `TEST_USERNAME`, `TEST_PASSWORD` — seeded in `.env.example`); the agent may read `.env` to fill
  them. IntelliJ credentials go into the now-gitignored `http-client.private.env.json`.

### Ralph loop
- The implementer **decides automatically** from its pre-analysis (architecture impact, effort,
  complexity) whether the Ralph loop is worthwhile, and states the decision with its reason.
  Manual triggers win: `/implement <bead> ralph|no-ralph` in the session, or a directive written
  **into the issue itself** ("use the Ralph loop").

### CLI
- **`--no-token-saving`** for `aiflow init` and `aiflow change-settings` — switches **caveman and
  rtk off** in one flag for full, unfiltered output.

### Production readiness & architecture hygiene (CLAUDE.md §3a)
- **Production-ready awareness for all agents:** every implementation targets production; agents
  are very careful with low-maturity technology (experimental, pre-1.0, unmaintained), and the
  **reviewer and tester must flag it**.
- **Class size & KISS:** classes ballooning into hundreds of lines trigger **divide & conquer** —
  split responsibilities, encapsulate behind interfaces (introduced layer structures must be
  coherent with the rest of the codebase); accepted exception: utility libraries offering method
  overloads for flexible call sites.
- **State-of-the-art check:** legacy requests (SOAP instead of REST, XML-over-REST instead of
  JSON, 1980s-style MQ patterns instead of modern brokers/cloud-native eventing) are **questioned
  as PO-level decisions**, never silently built — EOL/unsupported technology is flagged as a
  maintainability *and* security risk.
- **Monolith avoidance:** modular boundaries and service-ready seams even when microservices
  aren't explicitly required.
- **Deliberate data/performance choices:** agents evaluate whether in-memory stores (**Redis**,
  **SQLite**) or a search/caching layer (**Elasticsearch**, which also decouples the database from
  the application) bring a measurable win — proposed to the PO, decision recorded.

### New on-demand checker agents (not part of the delivery loop)
- **accessibility-checker** (`aiflow a11y-check` / `/a11y-check`) — strict **WCAG 2.2 AA** audit
  of all UI surfaces (perceivable/operable/understandable/robust: alternatives, semantics,
  contrast, keyboard, focus, labels, ARIA); files `[accessibility]` beads and recommends an
  automated a11y tool for the E2E suite (axe-core with Playwright/Cypress, Pa11y, Lighthouse CI).
- **modernization-advisor** (`aiflow modernize-check` / `/modernize-check`) — walks the entire
  brownfield codebase and proposes modernisation **concepts as a report**
  (`.aiflow/modernization-report.md`) for the architect to review manually and optionally feed
  into Beads: EOL/unsupported stacks first (maintainability + security lead), monolith →
  **microservice** extraction candidates (strangler-fig), SOAP/XML/legacy MQ → **REST/JSON +
  cloud-native eventing**, **svn → git**, containerisation/CI/observability gaps, and concrete
  **unit/BDD/E2E test frameworks** when the project lacks them. Report only — no code changes,
  no beads.

### Docs (agents)
- READMEs and the docs site now describe **precisely what each agent does and watches for**
  (detailed per-agent sections in docs → Agents, shared ground rules called out).

### Onboarding & project aim
- **onboarder proposes the project aim** on brownfield projects — derived from the understanding it
  built, written to `project-aim.md`, and **confirmed by the user** (interactive: asks directly;
  headless: marked `PROPOSED — please confirm`). Never adopted silently.
- **Project-aim guidance** in the READMEs, docs, and the CLAUDE.md template: where to set it
  (`aiflow init` / `change-settings`, or manually in `.claude/memory/project-aim.md` +
  `CLAUDE.md §1`) and how to write it (2–4 sentences: what, for whom, target architecture,
  quality bar) — it tunes Claude to the project and is the cheapest quality lever.

### Docs
- **Positioning made explicit:** aiflow ships one very good, **universal base configuration** —
  deliberately **generic agents** meant to be customised per project — because a strong base config
  beats the blank-Claude start most AI projects begin with (~70–80 % less configuration effort).
- **Terminal GIFs** (install · init Q&A incl. Ollama model selection and git/svn · change-settings)
  embedded in the READMEs (EN/DE) and the docs site; reproducible sources in
  `docs/assets/terminal/` (`make-casts.mjs` + agg).
- **New docs pages:** **AI Basics** (plain-language primer for beginners: Claude Code, agents,
  memory, context windows, skills, hooks, MCP, tokens) and an **example-project walk-through**
  (every init question with its default, what gets generated, and a first feature built
  end-to-end).
- **Honest token framing** in READMEs and docs: token saving is a goal but only partially achieved
  per task because of the quality rules — the net win is that production-ready-first-pass work
  needs no re-prompting or rework, which saves tokens *and* time.
- **Positioning hook:** "Most people struggle to set up their AI project successfully — this tool
  is built to fix exactly that." Production-ready code as the stated project goal (reusable,
  reliable, secure, current standards, architecture-aware, with optional accessibility /
  modernisation / security reports).

## [0.1.0] — 2026-07-03

First public release. aiflow turns any repository into a governed, AI-driven software-delivery
pipeline with one command — Claude Code wired to durable task memory, a two-layer code memory
(structural graph + semantic RAG), specialist agents, team collaboration, token savings, and a real
release process. Everything is project-scoped; secrets never leave the project.

### Setup & configuration
- **`aiflow init`** — interactive Q&A that writes `.aiflow/config.json` and renders the whole project
  (`.mcp.json`, hooks, memory, branching, git hooks) from it.
- **`aiflow change-settings`** — re-run the Q&A and re-render everything idempotently.
- **`aiflow install-deps`** (`--all`) — install only the tools your config enables; user-space,
  cross-platform (winget/scoop, Homebrew, apt/dnf/pacman, official scripts).
- **`aiflow doctor`** — prerequisite check plus a per-project summary (remote + host MCP, VCS,
  Ollama models, memory graph/RAG/context7 + intensity).
- **Installer prompts** — `install.sh` / `install.ps1` offer to also install **git**, **Subversion
  (svn)**, and **Ollama**, so `init` later only asks which models to pull.
- **Version control choice** — pick **git**, **svn**, or **none** at setup; git hooks and branching
  governance are wired only for git.

### Version control hosts (token-based, no OAuth)
- **Remote types** — `github`, `github-enterprise`, `gitlab`, `gitlab-self`, `bitbucket`,
  `forgejo`, `gitea`, `custom` (any base URL), or `none`.
- **Host-specific MCP catalog** — the matching git-host MCP is wired automatically per remote type,
  with the base URL threaded into the server (`GITHUB_HOST` / `GITLAB_API_URL` / `GITEA_URL`).
- **Configurable token env** — `remote.tokenEnv` (e.g. `GITHUB_TOKEN`, `GITLAB_TOKEN`,
  `GIT_REMOTE_TOKEN`); everything is API-token based, never OAuth for git hosts.
- **Beads ↔ host sync** derived from the git remote for GitHub/GitLab.

### Models
- **Claude access** — choose `apikey` (`ANTHROPIC_API_KEY`) or `oauth` (`CLAUDE_CODE_OAUTH_TOKEN`).
- **Ollama** — optional local models (no key): select at init (newest **qwen3-coder** recommended),
  install/manage via **`aiflow ollama [pull|add|list]`**; models are wired into
  `.aiflow/router-config.json` so they're actually used.
- **Model routing** — claude-code-router sends easy/background steps to cheap/local models
  (`aiflow shell --router`); add cloud providers (DeepSeek, OpenRouter, Gemini, …).

### Memory & context
- **Two-layer code memory** — **graphify** (structural graph: imports/call-graph) + **cocoindex-code**
  (semantic RAG: AST-aware, local embeddings, no key, ~70% fewer tokens).
- **`aiflow index`** — one command refreshes **both** indexes (`graphify build` + `ccc index`).
- **context7 MCP** — live, version-correct external library docs (keyless, optional key).
- **Retrieval routing policy** — a generated `.claude/memory/memory-policy.md` tells the agent which
  source to hit (Beads → memory files → graph → RAG → context7 → read files).
- **Learning intensity** — `memory.intensity` (`aggressive` default / `normal` / `light` / `off`).
- **Persistent memory files** — `project-aim.md`, `dev-environment.md`, `memory-policy.md`, indexed
  in `.claude/MEMORY.md`.

### Team collaboration
- **Shared issue graph** — Beads issues in a Dolt database synced over `refs/dolt/data` on the git
  remote; no extra server.
- **Session-start auto-pull** — a `SessionStart` hook runs `bd dolt pull` (safe, never pushes;
  opt-out `sync.pullOnStart`).
- **Atomic claiming** — `bd ready --claim` / `bd update --claim` prevents two people grabbing one task.
- **`aiflow sync [pull|push|both]`** and **`aiflow close-sync`** — pull-before-push so teammates'
  issue changes are never clobbered.
- **Sync gate on close** — closing an issue prompts to push + Dolt-sync (`sync.askOnClose`).
- **Shared team preferences** — versioned `.aiflow/team-prefs.json` (code style, language,
  conventions) overriding `CLAUDE.md §3`.

### Agents & workflow
- **Delivery agents** — architect, planner, implementer, reviewer, tester.
- **Audit agents** — security-advisor, quality-check, dependency-auditor, test-gap-advisor,
  performance-advisor, docs-sync, requirements-check (file prioritised Beads issues).
- **Brownfield** — `aiflow onboard` learns an existing codebase into memory + CLAUDE.md + arc42.
- **Slash skills** — `/intake-issue`, `/decompose`, `/plan-epic`, `/implement`, `/review-ac`,
  `/arch`, the audit commands, `/onboard`, `/explain`, `/standup`.
- **Ralph loop** — autonomous iterate-until-done, interactive / headless (`aiflow ralph`) / in CI.

### Quality, git & releases
- **Google style** for all languages, **Conventional Commits**, `pre-commit`/`commit-msg`/`pre-push`
  git hooks (format + lint + tests + branch rules).
- **Branching models** — `simple` / `gitflow` / `none`, PR-only, auto-release, SemVer/CalVer,
  `chore/*`; enforced by hooks + `aiflow protect` + `aiflow release`.

### Token & cost optimisation
- **caveman** terse output (~75% fewer output tokens) and **rtk** CLI-output filtering (60–90% fewer)
  are **on by default**; graph/RAG retrieval; `aiflow cost` (ccusage) baseline.

### Containers & CI/CD
- **Headless container runs** — `docker/run.sh` works with **Podman or Docker** (auto-detected;
  `AIFLOW_CONTAINER` override). (Dagger was evaluated and dropped as redundant.)
- **Workflows** — `ci.yml` (validate scripts + JSON + PowerShell + dry-run build), `release.yml`
  (tag + per-OS archives on `VERSION` bump), `pages.yml` (deploy the docs site). Generated projects
  also get `ci.yml` + `agent.yml` (Ralph loop in CI).

### Custom MCP servers
- Add any MCP server to `.mcp.json`; entries aiflow doesn't manage are preserved on re-render.

### Docs & project
- **Extensive README** in English and German (24 sections).
- **GitHub Pages documentation site** under `docs/` (just-the-docs).
- **MIT License**; **no funding / donation prompts** — feedback, a ⭐, and bug reports are the ask.

[Unreleased]: https://github.com/Cyber93de/aiflow/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/Cyber93de/aiflow/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Cyber93de/aiflow/releases/tag/v0.1.0
