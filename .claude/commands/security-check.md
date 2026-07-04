---
description: Run the security-advisor over the whole project and file Beads issues per finding (prefixed [security-advisor], prioritised by severity).
---

Run a full-project security audit.

Use the **security-advisor** agent. Scan the entire repository (not just the diff) with the
Anthropic security-review methodology. For every finding, file a Beads issue titled
`[security-advisor] <description>`, with priority mapped from severity (Critical→P0, High→P1,
Medium→P2, Low→P3) and a description containing `file:line`, impact, and the fix. Skip findings
already filed under an open `[security-advisor]` issue. End with a summary table and per-severity
totals. Do not modify code — report and file beads only.
