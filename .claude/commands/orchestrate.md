---
description: Entry point for non-trivial work — the orchestrator decides which specialist agent handles each step, dispatches one at a time, and routes the result onward until the review gate passes.
argument-hint: <goal, epic, or bead-id>
---

Use the **orchestrator** agent for **$ARGUMENTS**.

Own the route, not the work:

1. **Establish beads.** No beads yet → **planner** first (dependency-ordered, each with checkable
   AC and a recommended agent). Beads without AC → planner again; never let the implementer guess.
2. **Architecture first when it applies.** The change crosses module/layer boundaries, introduces a
   component or technology, or `AGENTS.md §2b` is still an unfilled `[EDIT ME]` with no ADR →
   **architect** before any implementation. Brownfield codebase nobody has mapped → **onboarder**
   once.
3. **Per ready bead:** claim it (`bd update <id> --claim`), dispatch the **implementer**, add a
   **tester** pass when the pre-analysis flags high risk/complexity or the change touches
   money/auth/data integrity, then always the **reviewer**. CHANGES REQUIRED goes back to the
   implementer with the findings verbatim; PASS closes the bead.
4. **One agent at a time**, and hand over **through the bead** — `bd update <id> --notes "route: …"`
   before each dispatch and after each result, so the next step survives a `/compact`.
5. **Escalate to the user** for anything that is the PO's call (§2c architecture deviations,
   contradictory AC, blocked work): plain language, options, consequences — and record the answer.
6. Discovered work → a new bead (`--deps discovered-from:<id>`), never silent scope growth.

The audit agents (security-advisor, quality-check, dependency-auditor, test-gap-advisor,
performance-advisor, docs-sync, accessibility-checker, requirements-check, modernization-advisor)
are **not** in this loop — they are triggered manually and only file beads, which then re-enter at
step 1.

Report back: the route taken, what each agent produced, open decisions, and the next step. Never
write code, tests, docs, or ADRs yourself.
