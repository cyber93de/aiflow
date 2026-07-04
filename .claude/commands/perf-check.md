---
description: Audit for performance problems → files [performance] Beads issues.
---

Use the **performance-advisor** agent over the whole project. Find N+1 queries, sync I/O on hot
paths, O(n²)+ work, missing pagination/indexes, and wasteful allocations, using the graphify graph
to locate hot paths. File one Beads issue per finding titled `[performance] <where: problem>`,
priority by impact, with `file:line`, the cost, and the fix. Skip findings already under an open
`[performance]` issue. End with a summary table + totals. Do not modify code — report and file
beads only; avoid premature-optimisation noise.
