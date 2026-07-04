---
description: Advisory audit of Beads issue quality/completeness vs the architecture. Reports only — no changes to issues or code.
argument-hint: <bead-id, optional; default = all open issues>
---

Audit requirements quality for **$ARGUMENTS** (if empty, all open Beads issues).

Use the **requirements-check** agent. For each issue, grade description completeness and quality,
check it against `CLAUDE.md §2` + `docs/architecture/`, and surface undescribed cases (edge cases,
error paths, non-functional needs the architecture implies). Output per-issue grades + concrete
gaps + clarifying questions, then a backlog readiness summary.

Read-only: do not modify issues, priorities, comments, or code, and do not create beads. This is
advisory and has no effect on what gets implemented.
