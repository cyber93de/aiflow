---
description: Implement one ready Beads task end-to-end (code + tests, Google style), then run the AC review gate.
argument-hint: <bead-id, or empty to take the top ready task>
---

Implement bead **$ARGUMENTS** (if empty, run `/beads:ready` and take the top task).

1. Read the bead and its acceptance criteria. Set it in-progress. If AC are unclear, stop → BLOCKED.
2. Create branch `task/bd-<id>-<slug>`.
3. Use the **implementer** agent: smallest change satisfying AC, CLAUDE.md §2 architecture + §3 Google style, with tests.
4. Run tests + formatter + linter. Fix until green.
5. Run `/review-ac`. Address every BLOCKER and SHOULD.
6. Commit referencing the bead id (Conventional Commits). Close the bead with a verification note.
