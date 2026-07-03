---
description: Detect doc/code drift → files [docs] Beads issues.
---

Use the **docs-sync** agent over the whole project. Compare README, CLAUDE.md, arc42, ADRs, and API
docs against the actual code (graphify for real structure). Find broken setup/run/test commands,
features documented-but-removed or shipped-but-undocumented, and architecture docs that contradict
reality. File one Beads issue per gap titled `[docs] <doc: what's wrong>`, priority by impact, with
the doc location, the code reality, and the suggested update. Skip drift already under an open
`[docs]` issue. End with a summary table + totals. Do not rewrite docs or code — report and file
beads only.
