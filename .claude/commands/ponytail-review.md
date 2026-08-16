---
description: Audit the current diff for over-engineering (unneeded new code/abstractions/deps) using the ponytail decision ladder.
---

Audit the current diff (uncommitted changes, or the branch's changes vs. its base if the working
tree is clean) for over-engineering, using the **ponytail** skill's decision ladder (see
`.claude/skills/ponytail/SKILL.md` §1–§2). Applies regardless of whether `ponytail.enabled` is
set in `.aiflow/config.json` — this command is an explicit, one-off request.

For each finding report `file:line — what's over-built — the simpler alternative`. Propose fixes
and apply only on confirmation for non-trivial ones; small unambiguous simplifications (a
redundant wrapper, an unused parameter) may be applied directly and reported. End with a one-line
summary: lines removed/simplified vs. lines reviewed.

Do not flag code required by AGENTS.md §3a mandatory quality gates (tests, error handling,
logging) — this reviews *unneeded* surface area, not required rigor.
