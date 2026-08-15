---
description: Design or update architecture for a change — produces an ADR and updates the arc42 docs.
argument-hint: <design question / change>
---

Architecture work for: **$ARGUMENTS**

Use the **architect** agent. Clarify constraints → present ≥2 options with trade-offs →
recommend with rationale → record an ADR under `docs/architecture/adr/` →
update the relevant arc42 section in `docs/architecture/`. If `AGENTS.md §2b` is still an unfilled
`[EDIT ME]` and no ADR defines the structure, establish the rules first ("Rule zero"): layering,
module boundaries, DAO/DTO convention, interface policy — into §2b **and** an ADR, confirmed by
the user.

Finish with the list of beads needed to implement. The architect **does not create them** — hand
the list to the **planner** (or the **orchestrator**), which turns it into dependency-ordered
beads with acceptance criteria. No feature code.
