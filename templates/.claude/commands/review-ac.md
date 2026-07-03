---
description: Quality gate — review the current diff against the task's acceptance criteria, correctness, tests, and Google style.
argument-hint: <bead-id, optional>
---

Run the review gate for bead **$ARGUMENTS** (or the in-progress task).

Use the **reviewer** agent on `git diff`. Check, in order: acceptance criteria met →
correctness/edge cases/security → tests actually cover the AC → Google style + architecture.
Output findings as `file:line — problem — fix`, tagged BLOCKER/SHOULD/NIT, then a verdict
PASS or CHANGES REQUIRED. Do not merge or close the bead if any BLOCKER remains.
