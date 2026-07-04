---
description: Implement one ready Beads task end-to-end as a senior engineer — pre-analysis first, then code + tests + quality gates, then the AC review gate.
argument-hint: <bead-id> [ralph|no-ralph] — empty takes the top ready task; ralph flag optional
---

Implement bead **$ARGUMENTS** (if no id, run `/beads:ready` and take the top task).

1. Read the bead and its acceptance criteria. Set it in-progress. If AC are unclear, stop → BLOCKED.
2. **Pre-analysis (mandatory):** current architecture, how it changes under this requirement,
   effort, complexity, risks. Gather missing information (code search, context7) **before** coding.
3. **Ralph decision:** if the arguments say `ralph` or `no-ralph`, or the bead's description
   contains a Ralph directive, obey it. Otherwise decide **automatically** from the pre-analysis
   and state the decision + reason (long-horizon/many-file → Ralph loop; small crisp change →
   direct).
4. Functional questions → phrase them for a PO (options + consequences), let the user pick, and
   **record the decision** (`/beads:decision` or `bd update <id> --design`).
5. Create branch `task/bd-<id>-<slug>`.
6. Use the **implementer** agent: architecture-fit check (targeted refactoring if needed),
   SOLID/DRY/KISS/YAGNI, proven frameworks/patterns over self-built, no duplication, testable by
   design (DI, deterministic), CLAUDE.md §2 architecture + §3 Google style + §3a quality gates
   (static analysis, unit + BDD E2E tests, >80 % coverage of changed logic, all non-static methods
   tested, leveled logging, metric targets) + §3b `.http` files for REST changes + §3c database
   rules (new models ≥3NF with real FKs/constraints; existing schemas handled with care — no
   side-effect restructuring, improvement potential becomes beads, commissioned changes need
   consumer check + rollback plan).
7. Run tests + formatter + linter + static analysis. Fix until green.
8. If the pre-analysis flagged high risk/complexity: run the **tester** agent (negative/edge/
   boundary/exception/invalid-input tests + test-quality audit).
9. Run `/review-ac` (architect review + quality-gate checklist in one). Address every BLOCKER and
   SHOULD; out-of-scope improvement ideas become `[suggestion]` beads for the next loop.
10. Commit referencing the bead id (Conventional Commits). Close the bead with a verification note.
