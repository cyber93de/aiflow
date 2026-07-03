---
description: Find untested critical paths → files [test gap] Beads issues.
---

Use the **test-gap-advisor** agent over the whole project. Find untested or under-tested critical
paths (auth, payments, data mutations, error handling, public API, high-fan-in code), using the
graphify graph and any coverage data. File one Beads issue per gap titled
`[test gap] <area: what's untested>`, priority by risk, with `file:line`, why it matters, and the
cases that should be tested. Skip gaps already under an open `[test gap]` issue. End with a summary
table + totals. Do not write tests or code — report and file beads only.
