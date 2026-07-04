---
description: Whole-project quality & refactoring audit → files Beads issues prefixed [technical issue] for the PO to triage.
---

Run a code-quality and refactoring audit over the whole project.

Use the **quality-check** agent. Find dead/orphaned code, now-simplifiable code (e.g. after a
dependency or case was removed), duplication, excess complexity, and inconsistencies — using the
graphify graph for real usage. For each finding, file a Beads issue titled
`[technical issue] <description>`, with a sensible default priority (the PO will re-prioritise) and
a description containing `file:line`, impact, suggested refactor, and rough effort. Skip findings
already filed under an open `[technical issue]` issue. End with a summary table and totals.

Do not refactor or modify code or other issues — report and file `[technical issue]` beads only.
