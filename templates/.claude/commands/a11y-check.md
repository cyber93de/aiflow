---
description: Run the accessibility-checker over all UI surfaces — strict WCAG 2.2 AA audit; files Beads issues prefixed [accessibility] and recommends an automated a11y tool for the E2E suite. Not part of the delivery loop.
---

Run a full accessibility audit.

Use the **accessibility-checker** agent. Audit every user-facing surface strictly against
**WCAG 2.2 AA** (perceivable, operable, understandable, robust). For every finding, file a Beads
issue titled `[accessibility] <description>` with the WCAG success criterion, `file:line`, affected
user group, and a concrete fix (blocks a user group → P1, major barrier → P2, friction → P3). Skip
findings already filed under an open `[accessibility]` issue. If the E2E suite has no automated
accessibility testing, recommend a concrete tool for the stack (axe-core with Playwright/Cypress,
Pa11y, or Lighthouse CI) as its own bead. End with a summary table. Do not modify code.
