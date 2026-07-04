---
description: Audit dependencies (vulnerabilities, outdated, unused, licenses) → files [dependency] Beads issues.
---

Use the **dependency-auditor** agent over the whole project. Check known vulnerabilities, outdated
versions, unused packages, and license conflicts with the available tools (`npm audit`, `pip-audit`,
`govulncheck`, etc.). File one Beads issue per finding titled `[dependency] <package: problem>`,
priority by risk, with advisory id, current vs target version, impact, and fix. Skip findings
already under an open `[dependency]` issue. End with a summary table + totals. Do not modify
manifests, lockfiles, or code — report and file beads only.
