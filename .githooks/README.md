# `.githooks/` — this repo's own git hooks

These are **aiflow's hooks for the aiflow repo**, not a copy of `templates/.githooks/`. They exist
because aiflow was not applying its own rules to itself: `core.hooksPath` pointed at `.beads/hooks`,
which carries only the beads integration, so the Conventional-Commits check and the branching guard
this project ships never ran here (aiflow-n3p).

Each hook runs the beads shim first (beads needs its hooks), then aiflow's own check:

| Hook | What it runs |
|------|--------------|
| `commit-msg` | beads shim → `templates/.githooks/commit-msg` (Conventional Commits) |
| `pre-push` | beads shim → `templates/.githooks/pre-push` (branching model from `.aiflow/branching.json`) |
| `pre-commit` | beads shim → `bash -n` on the **staged** shell blobs + the four guards in `.github/scripts/` + the shipped bead-id warning |

`commit-msg` and `pre-push` **delegate to the shipped template hooks on purpose**: the file a
generated project gets is the file that runs here, so a break in it surfaces on the next commit
instead of in someone else's project. `pre-commit` deliberately does *not* delegate — the template
version formats staged files in place (prettier/shfmt/black), which is right for a generated project
and wrong for the repo that ships those files: a stray reformat of `templates/**` would propagate
into every future project.

## Enable them (once per clone)

`core.hooksPath` lives in `.git/config` and is **never cloned**, so this is a per-clone step:

```bash
git config core.hooksPath .githooks
```

`aiflow doctor` reports it when it is missing. Bypasses, for emergencies only:
`AIFLOW_SKIP_VERIFY=1` (pre-commit), `AIFLOW_SKIP_COMMIT_LINT=1` (commit-msg),
`AIFLOW_ALLOW_DIRECT_PUSH=1` (pre-push).
