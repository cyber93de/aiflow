---
description: Summarise Beads progress and what's next (standup-style).
argument-hint: <since, e.g. "yesterday" or a date; optional>
---

Give a concise standup for this project based on Beads and git.

- **Done** since $ARGUMENTS (default: last working day): closed beads + merged work (`bd list`,
  `git log`).
- **In progress:** beads currently in_progress and who/what they're waiting on.
- **Next / ready:** top of `/beads:ready`.
- **Blocked:** `/beads:blocked` with the blocker.
- **Attention:** open `[security-advisor]` / `[technical issue]` / `[dependency]` / `[test gap]` /
  `[performance]` / `[docs]` issues worth the PO's eyes.

Keep it short and scannable. Read-only — do not change anything.
